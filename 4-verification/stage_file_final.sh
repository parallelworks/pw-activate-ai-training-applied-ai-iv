#!/usr/bin/env bash
#
# stage_file_final.sh — copy a bucket file into the home directory of one or
# more ACTIVATE clusters.
#
# Usage: stage_file_final.sh BUCKET_URI [--all | CLUSTER_URI ...]
#   BUCKET_URI   URI of the file in an ACTIVATE bucket
#   --all        Copy to every active cluster (pw clusters list --status=active).
#                Cannot be combined with explicit CLUSTER_URIs.
#   CLUSTER_URI  One or more cluster URIs
#
# Failure behavior:
#   * Missing/invalid arguments, or --all combined with explicit clusters →
#     usage or one clear error, exit 1, nothing contacted.
#   * Failed cluster listing (e.g. unauthenticated pw CLI) → one clear error,
#     exit 1 — never a silent success.
#   * A failed, unreachable, or hung cluster prints "<cluster>: FAILED" and
#     the loop CONTINUES; exit 1 with the exact count if anything failed.
#   * The copy lands under a temporary name and is renamed into place on
#     success, so an interrupted transfer never leaves a partial file under
#     the final name (a stale "<name>.tmp" may remain).
#
# Credentials are never handled here — authentication is the pw CLI's job on
# BOTH sides: this machine and the cluster-side pw that performs the copy.
#
# Provenance: gpt-oss-120b draft from strong_prompt.md → round-4 revision
# (critique_prompts.md: 5 findings confirmed of 20 raised) → hand-finished
# after the failure-path runs (manual_tests.md). Hand-finish fixes:
#   * NO `set -e`: per-cluster failures are expected and handled explicitly;
#     under set -e the ((FAIL_COUNT++)) arithmetic killed the script on its
#     first FAILED (measured: T6 and T8). Counter is now plain
#     FAIL_COUNT=$((FAIL_COUNT + 1)).
#   * --all no longer silently replaces explicitly passed clusters
#     (measured: T6): combining them is now an error.
#   * Full conservative charset validation for URIs — the revision only
#     checked the first character.
#   * timeout on every remote call — the rename and cleanup had none, so a
#     hung cluster could still block the loop.
#   * Temp name is <name>.tmp, not the hidden .tmp_<name>: a script that
#     rejects dotfile basenames should not write hidden files itself.
set -u

NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
URI_RE='^[A-Za-z0-9][A-Za-z0-9._:/@-]*$'

usage() {
  cat <<EOF
Usage: $(basename "$0") BUCKET_URI [--all | CLUSTER_URI ...]
  BUCKET_URI   URI of the file in an ACTIVATE bucket
  --all        Copy to every active cluster (cannot be combined with CLUSTER_URIs)
  CLUSTER_URI  One or more cluster URIs

Exit status: 0 all copies succeeded; 1 anything failed or arguments invalid.
EOF
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

BUCKET_URI=$1
shift

if [[ ! "$BUCKET_URI" =~ $URI_RE ]]; then
  echo "Error: bucket URI '$BUCKET_URI' contains unsupported characters." >&2
  exit 1
fi

BASENAME=$(basename "$BUCKET_URI")
if [[ ! "$BASENAME" =~ $NAME_RE ]]; then
  echo "Error: bucket object name '$BASENAME' must start with a letter or digit and use only letters, digits, '.', '_', '-'." >&2
  exit 1
fi

ALL_FLAG=false
CLUSTERS=()
while (( $# )); do
  case "$1" in
    --all)
      ALL_FLAG=true
      ;;
    *)
      if [[ ! "$1" =~ $URI_RE ]]; then
        echo "Error: invalid CLUSTER_URI: '$1'" >&2
        exit 1
      fi
      CLUSTERS+=( "$1" )
      ;;
  esac
  shift
done

# --all and explicit clusters are mutually exclusive — no silent precedence.
if $ALL_FLAG && [[ ${#CLUSTERS[@]} -gt 0 ]]; then
  echo "Error: --all cannot be combined with explicit CLUSTER_URIs." >&2
  exit 1
fi

# No clusters and no --all → usage, nothing contacted.
if [[ ${#CLUSTERS[@]} -eq 0 && $ALL_FLAG = false ]]; then
  usage
fi

if $ALL_FLAG; then
  # Command substitution preserves pw's exit status, so a failed or
  # unauthenticated listing is caught here — never a silent empty list.
  if ! CLUSTER_LIST=$(pw clusters list --status=active); then
    echo "Error: unable to list active clusters (pw may be unauthenticated)." >&2
    exit 1
  fi
  mapfile -t CLUSTERS < <(awk 'NR>1 {print $1}' <<< "$CLUSTER_LIST")
  if [[ ${#CLUSTERS[@]} -eq 0 ]]; then
    echo "Error: no active clusters found." >&2
    exit 1
  fi
  for CLUSTER in "${CLUSTERS[@]}"; do
    if [[ ! "$CLUSTER" =~ $URI_RE ]]; then
      echo "Error: invalid cluster URI in listing: '$CLUSTER'" >&2
      exit 1
    fi
  done
fi

FAIL_COUNT=0
TEMP_NAME="${BASENAME}.tmp"

for CLUSTER in "${CLUSTERS[@]}"; do
  # timeout bounds hung clusters; </dev/null prevents terminal-suspend hangs;
  # \$HOME is escaped so it expands on the CLUSTER, not on this machine.
  if timeout 60 pw ssh "$CLUSTER" pw buckets cp "$BUCKET_URI" "\$HOME/${TEMP_NAME}" </dev/null; then
    if timeout 60 pw ssh "$CLUSTER" mv "\$HOME/${TEMP_NAME}" "\$HOME/${BASENAME}" </dev/null; then
      echo "$CLUSTER: OK"
    else
      echo "$CLUSTER: FAILED (rename)" >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    echo "$CLUSTER: FAILED (copy)" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    # Best-effort cleanup of a partial temp file; never affects the count.
    timeout 60 pw ssh "$CLUSTER" rm -f "\$HOME/${TEMP_NAME}" </dev/null || true
  fi
done

if (( FAIL_COUNT > 0 )); then
  echo "Total failures: $FAIL_COUNT of ${#CLUSTERS[@]}"
  exit 1
fi
echo "All ${#CLUSTERS[@]} copies succeeded."
exit 0

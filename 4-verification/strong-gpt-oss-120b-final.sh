#!/usr/bin/env bash
#
# strong-gpt-oss-120b-final.sh
#
# Copy a file from a pw bucket into the home directory of one or more clusters.
#
# Usage: strong-gpt-oss-120b-final.sh <bucket-uri> [cluster-uri ...]
#   With no cluster URIs, every active cluster is targeted
#   (as returned by: pw clusters list --status=active).
#
# Behavior on failure:
#   * Every cluster is attempted; a failed or hung copy prints "<cluster>: FAILED"
#     and the loop continues to the next cluster.
#   * The file is copied to a temporary name and renamed into place on success, so
#     an interrupted transfer never leaves a partial file under the final name.
#     (A stale "<name>.tmp" may remain on a cluster after a killed transfer.)
#   * Exit 0 only if every copy succeeded; exit 1 otherwise, with the exact
#     failure count in the printed summary.
#
# Credentials are never handled here — authentication is the pw CLI's job, on
# BOTH sides: the machine running this script and the cluster-side pw that
# performs the copy (a cluster whose own pw has no context configured prints
# its error and counts as FAILED — measured 2026-08-19). Auth problems surface
# as the listing error below or as per-cluster FAILED lines and exit 1 —
# never as a false success.
#
# Provenance: gpt-oss-120b draft from strong_prompt.md -> round-4 model revision
# (critique_prompts.md, five confirmed findings) -> hand-finished after the
# 2026-08-19 failure-path run: failure counting no longer aborts the script,
# arguments are validated, usage expands the script name.
#
# Deliberately NO `set -e`: per-cluster failures are expected and handled
# explicitly; under set -e the counter arithmetic aborted the whole script on
# the first FAILED (measured 2026-08-19).
set -u

usage() {
  cat <<EOF
Usage: $(basename "$0") <bucket-uri> [cluster-uri ...]
Copies a bucket file into the home directory of each target cluster.
If no cluster URIs are supplied, targets every active cluster
(as returned by: pw clusters list --status=active).

Exit status:
  0 - all copies succeeded
  1 - one or more copies failed, or the arguments/cluster listing were invalid
EOF
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

BUCKET_URI=$1
shift

# Conservative charset checks. Requiring a leading letter or digit blocks
# dotfile names (would overwrite hidden files in the remote home) and flag
# lookalikes (-x); the allowed set leaves nothing for the remote shell to
# expand in the command string built below.
NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
URI_RE='^[A-Za-z0-9][A-Za-z0-9._:/@-]*$'

BASENAME=$(basename "$BUCKET_URI")
if [[ ! "$BASENAME" =~ $NAME_RE ]]; then
  echo "ERROR: bucket object name '$BASENAME' must start with a letter or digit and use only letters, digits, '.', '_', '-'." >&2
  exit 1
fi
if [[ ! "$BUCKET_URI" =~ $URI_RE ]]; then
  echo "ERROR: bucket URI '$BUCKET_URI' contains unsupported characters." >&2
  exit 1
fi

# Determine target clusters: explicit arguments, or every active cluster.
if [[ $# -eq 0 ]]; then
  mapfile -t CLUSTERS < <(pw clusters list --status=active | awk 'NR>1 {print $1}')
  if [[ ${#CLUSTERS[@]} -eq 0 ]]; then
    echo "ERROR: no active clusters found — 'pw clusters list' returned nothing (check 'pw auth')." >&2
    exit 1
  fi
else
  CLUSTERS=("$@")
fi

# Reject empty or malformed cluster URIs before anything is contacted.
for CLUSTER in "${CLUSTERS[@]}"; do
  if [[ ! "$CLUSTER" =~ $URI_RE ]]; then
    echo "ERROR: invalid cluster URI '$CLUSTER'." >&2
    exit 1
  fi
done

TMPNAME="${BASENAME}.tmp"
FAILURES=0

for CLUSTER in "${CLUSTERS[@]}"; do
  # timeout bounds hung clusters; </dev/null prevents terminal-suspend hangs.
  # The charset checks above make the single-quoted remote string safe to build.
  if timeout 60 pw ssh "$CLUSTER" \
       "pw buckets cp '$BUCKET_URI' '$TMPNAME' && mv '$TMPNAME' '$BASENAME'" </dev/null; then
    echo "$CLUSTER: OK"
  else
    echo "$CLUSTER: FAILED"
    FAILURES=$((FAILURES + 1))
  fi
done

if (( FAILURES > 0 )); then
  echo "FAILED clusters: $FAILURES of ${#CLUSTERS[@]}"
  exit 1
fi
echo "All ${#CLUSTERS[@]} copies succeeded."
exit 0

# Test plan (failure paths first)
# 1. No arguments                       -> usage + exit 1.
# 2. Dotfile object (pw://.../.bashrc)  -> ERROR + exit 1, nothing contacted.
# 3. Empty or malformed cluster arg     -> ERROR + exit 1, nothing contacted.
# 4. Unauthenticated CLI (bucket URI only)
#                                       -> listing ERROR + exit 1, or per-cluster
#                                          FAILED + exit 1 if the listing still
#                                          answers — never a false success.
# 5. Broken cluster before a healthy one
#                                       -> FAILED, loop continues, healthy gets OK,
#                                          "FAILED clusters: 1 of 2", exit 1.
# 6. Happy path (one sandbox cluster)   -> OK, success summary, exit 0; file lands
#                                          in the REMOTE home; no .tmp left behind.
# 7. Timeout-killed transfer            -> FAILED + exit 1; no partial file under
#                                          the final name (a stale .tmp may remain).

#!/usr/bin/env bash
# stage_file_revised.sh – copy a bucket file to one or more ACTIVATE clusters
#
# Purpose: Transfer a file from an ACTIVATE bucket to the home directory of
# one or more ACTIVATE clusters.
#
# Usage: stage_file_revised.sh BUCKET_URI [--all] [CLUSTER_URI ...]
#   BUCKET_URI   URI of the file in an ACTIVATE bucket (must start with a letter or digit)
#   --all        Copy to every active cluster (requires pw authentication)
#   CLUSTER_URI  One or more cluster URIs (must start with a letter or digit)
#
# Failure behavior:
#   * Missing or invalid arguments → prints usage and exits 1.
#   * Failure to list clusters (e.g., unauthenticated pw CLI) → prints error and exits 1.
#   * Invalid bucket basename, bucket URI, or cluster URI → prints error and exits 1.
#   * Unreachable cluster or timeout during copy → counts as a failure; script exits 1 if any failures.
#   * Partial remote copy (timeout) is cleaned up by copying to a temporary name and renaming only on success.

set -euo pipefail

# ---------- helpers ----------
usage() {
  cat <<EOF
Usage: $(basename "$0") BUCKET_URI [--all] [CLUSTER_URI ...]
  BUCKET_URI   URI of the file in an ACTIVATE bucket (must start with a letter or digit)
  --all        Copy to every active cluster (requires pw authentication)
  CLUSTER_URI  One or more cluster URIs (must start with a letter or digit)
EOF
  exit 1
}

is_valid_uri() {
  [[ $1 =~ ^[A-Za-z0-9] ]]
}

is_valid_basename() {
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

# ---------- arguments ----------
if [[ $# -lt 1 ]]; then
  usage
fi

BUCKET_URI=$1
shift

# Validate bucket URI
if ! is_valid_uri "$BUCKET_URI"; then
  echo "Error: BUCKET_URI must start with a letter or digit: $BUCKET_URI" >&2
  exit 1
fi

BASENAME=$(basename "$BUCKET_URI")
if ! is_valid_basename "$BASENAME"; then
  echo "Error: Invalid basename derived from BUCKET_URI: $BASENAME" >&2
  exit 1
fi

ALL_FLAG=false
CLUSTERS=()

while (( "$#" )); do
  case "$1" in
    --all)
      ALL_FLAG=true
      ;;
    *)
      # Validate each cluster URI as we collect them
      if ! is_valid_uri "$1"; then
        echo "Error: Invalid CLUSTER_URI: $1" >&2
        exit 1
      fi
      CLUSTERS+=( "$1" )
      ;;
  esac
  shift
done

# If no clusters supplied and --all not set → usage, no contact
if [[ ${#CLUSTERS[@]} -eq 0 && $ALL_FLAG = false ]]; then
  usage
fi

# If --all, obtain the list of active clusters
if $ALL_FLAG; then
  # Capture list; fail explicitly if pw command errors
  if ! pw clusters list --status=active | awk 'NR>1 {print $1}' > /tmp/_pw_clusters_list.txt; then
    echo "Error: unable to list active clusters (pw may be unauthenticated)." >&2
    exit 1
  fi
  mapfile -t CLUSTERS < /tmp/_pw_clusters_list.txt
  if [[ ${#CLUSTERS[@]} -eq 0 ]]; then
    echo "Error: no active clusters found." >&2
    exit 1
  fi
fi

# ---------- copy loop ----------
FAIL_COUNT=0
TEMP_NAME=".tmp_${BASENAME}"

for CLUSTER in "${CLUSTERS[@]}"; do
  # Transfer to a temporary filename; remote $HOME is kept literal
  if timeout 60 pw ssh "$CLUSTER" pw buckets cp "$BUCKET_URI" "\$HOME/${TEMP_NAME}" </dev/null; then
    # Rename only on successful copy
    if pw ssh "$CLUSTER" mv "\$HOME/${TEMP_NAME}" "\$HOME/${BASENAME}" </dev/null; then
      echo "$CLUSTER: OK"
    else
      echo "$CLUSTER: FAILED (rename)" >&2
      ((FAIL_COUNT++))
    fi
  else
    echo "$CLUSTER: FAILED (copy)" >&2
    ((FAIL_COUNT++))
    # Attempt cleanup of partial file if it exists
    pw ssh "$CLUSTER" rm -f "\$HOME/${TEMP_NAME}" </dev/null || true
  fi
done

# ---------- exit status ----------
if (( FAIL_COUNT > 0 )); then
  echo "Total failures: $FAIL_COUNT" >&2
  exit 1
fi

exit 0

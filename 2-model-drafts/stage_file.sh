#!/usr/bin/env bash
# stage_file.sh – copy a bucket file to one or more ACTIVATE clusters

set -euo pipefail

# ---------- helpers ----------
usage() {
  cat <<EOF
Usage: $(basename "$0") BUCKET_URI [--all] [CLUSTER_URI ...]
  BUCKET_URI   URI of the file in an ACTIVATE bucket
  --all        Copy to every active cluster (requires pw auth)
  CLUSTER_URI  One or more cluster URIs (overrides --all)
EOF
  exit 1
}

# ---------- arguments ----------
if [[ $# -lt 1 ]]; then
  usage
fi

BUCKET_URI=$1
shift

ALL_FLAG=false
CLUSTERS=()

while (( "$#" )); do
  case "$1" in
    --all)
      ALL_FLAG=true
      ;;
    *)
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
  # Fail fast if pw is not authenticated (clusters list will error)
  mapfile -t CLUSTERS < <(pw clusters list --status=active \
    | awk 'NR>1 {print $1}' )
fi

# ---------- copy loop ----------
FAIL_COUNT=0
BASENAME=$(basename "$BUCKET_URI")

for CLUSTER in "${CLUSTERS[@]}"; do
  # Use a timeout so a hung cluster does not block the loop
  if timeout 60 pw ssh "$CLUSTER" pw buckets cp "$BUCKET_URI" "$HOME/$BASENAME" </dev/null; then
    echo "$CLUSTER: OK"
  else
    echo "$CLUSTER: FAILED"
    ((FAIL_COUNT++))
  fi
done

# ---------- exit status ----------
if (( FAIL_COUNT > 0 )); then
  echo "Total failures: $FAIL_COUNT" >&2
  exit 1
fi

exit 0

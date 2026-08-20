#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: $(basename "$0") <bucket-uri> [cluster-uri ...]
  Copies a bucket file to the home directory of each target cluster.
  If no cluster URIs are supplied, the script copies to every active cluster
  (as returned by: pw clusters list --status=active).

Exit status:
  0  – all copies succeeded
  >0 – one or more copies failed
EOF
  exit 1
}

# Ensure at least one argument (the bucket URI)
if [[ $# -lt 1 ]]; then
  usage
fi

BUCKET_URI=$1
shift

# Determine target clusters
if [[ $# -eq 0 ]]; then
  # List active clusters, extracting the first column after the header
  mapfile -t CLUSTERS < <(pw clusters list --status=active | awk 'NR>1 {print $1}')
  if [[ ${#CLUSTERS[@]} -eq 0 ]]; then
    echo "ERROR: Unable to list active clusters – pw CLI may be unauthenticated." >&2
    exit 2
  fi
else
  CLUSTERS=("$@")
fi

BASENAME=$(basename "$BUCKET_URI")
FAILURES=0

for CLUSTER in "${CLUSTERS[@]}"; do
  # Protect against hung clusters
  if timeout 60 pw ssh "$CLUSTER" pw buckets cp "$BUCKET_URI" "$HOME/$BASENAME" </dev/null; then
    echo "$CLUSTER: OK"
  else
    echo "$CLUSTER: FAILED"
    ((FAILURES++))
  fi
done

if (( FAILURES > 0 )); then
  echo "FAILED clusters: $FAILURES"
  exit $FAILURES
else
  echo "All copies succeeded."
  exit 0
fi

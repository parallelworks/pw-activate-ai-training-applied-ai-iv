#!/usr/bin/env bash
set -euo pipefail

# Get list of active clusters (JSON output assumed)
clusters=$(pw clusters list --output json | jq -r '.[] | select(.status == "active") | .name')

if [[ -z "$clusters" ]]; then
  echo "No active clusters found."
  exit 0
fi

# Copy the file to each active cluster in parallel
for cluster in $clusters; do
  echo "Copying hello.txt to cluster $cluster..."
  pw ssh pw://avidalto/"$cluster" pw buckets cp pw://avidalto/alvarotest/hello.txt . &
done
wait

echo "File copy completed on all active clusters."

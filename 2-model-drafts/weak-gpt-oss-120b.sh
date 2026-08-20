#!/usr/bin/env bash
set -euo pipefail

BUCKET_FILE="pw://avidalto/alvarotest/hello.txt"

# Get a list of active clusters (second column == active)
active_clusters=$(pw clusters list | awk '$2=="active"{print $1}')

# Copy in parallel to each active cluster
for cluster in $active_clusters; do
  pw ssh "$cluster" pw buckets cp "$BUCKET_FILE" . &
 done

wait

echo "Copy completed on all active clusters."

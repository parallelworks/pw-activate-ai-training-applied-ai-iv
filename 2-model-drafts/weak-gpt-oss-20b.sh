#!/usr/bin/env bash
# Copy a shared bucket file to the home directory of every active cluster.
# Fire and forget parallelism, fast.

set -euo pipefail

SRC="pw://avidalto/alvarotest/hello.txt"

# Get cluster URIs: first column after header
clusters=$(pw clusters list | tail -n +2 | awk '{print $1}')

# Parallel copy – up to 10 jobs at once
max_jobs=10
j=0
for cluster in ${clusters}; do
    ((j==max_jobs)) && wait
    pw ssh "$cluster" pw buckets cp "$SRC" . &
    ((j++))
done
wait

exit 0

#!/usr/bin/env bash
set -uo pipefail

usage() { printf 'Usage: %s BUCKET_URI [CLUSTER_URI…]\n' "$0" >&2; exit 1; }

# ----- argument handling ----------------------------------------------------
[[ $# -lt 1 ]] && usage
bucket="${1}"  # bucket URI
shift
# optional list of clusters supplied by user
clusters=()
while [ $# -gt 0 ]; do
    clusters+=("$1")
    shift
done

# If no explicit clusters, list every active one
if [ ${#clusters[@]} -eq 0 ]; then
    cluster_list=$(pw clusters list --status=active 2>&1 || true)
    if [ $? -ne 0 ]; then
        printf 'Error: pw authentication required (cluster list failed)\n' >&2
        exit 1
    fi
    # Extract the first column after the header line
    clusters=( $(echo "$cluster_list" | awk 'NR>1{print $1}') )
fi

# ---- copy loop ------------------------------------------------------------
fail=0
file_name=$(basename "$bucket")

for cluster in "${clusters[@]}"; do
    if timeout 60 pw ssh "$cluster" pw buckets cp "$bucket" "~/$(printf '%s' "$file_name")" </dev/null; then
        printf '%s: OK\n' "$cluster"
    else
        printf '%s: FAILED\n' "$cluster"
        fail=$((fail + 1))
    fi
done

if [ $fail -ne 0 ]; then
    printf 'Failures: %d\n' "$fail" >&2
    exit 1
fi

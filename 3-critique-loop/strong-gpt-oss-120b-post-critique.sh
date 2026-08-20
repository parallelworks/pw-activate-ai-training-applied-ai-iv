#!/usr/bin/env bash
#
# strong-gpt-oss-120b-post-critique.sh
#
# Purpose: Copy a file from a pw bucket to the home directory of one or more
# remote clusters.
#
# Usage: $(basename "$0") <bucket-uri> [cluster-uri ...]
#   - If no cluster URIs are supplied, copies to every active cluster as
#     reported by `pw clusters list --status=active`.
#   - The bucket object name must not start with a dot; such names are rejected
#     to avoid unintentionally overwriting dotfiles in the remote home.
#
# Behavior on failure:
#   * Each failed copy is reported; the script exits with status 1 if any copy
#     failed, otherwise 0.
#   * Copies are performed via a temporary filename; on success the temporary
#     file is atomically renamed to the final basename, preventing partially
#     written files if a transfer is interrupted.
#
# Exit codes:
#   0 – all copies succeeded
#   1 – one or more copies failed or other error (e.g., unauthenticated CLI)
#
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: $(basename "$0") <bucket-uri> [cluster-uri ...]
Copies a bucket file to the home directory of each target cluster.
If no cluster URIs are supplied, the script copies to every active cluster
(as returned by: pw clusters list --status=active).

Exit status:
  0 – all copies succeeded
  1 – one or more copies failed (including unauthenticated pw CLI)
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
  mapfile -t CLUSTERS < <(pw clusters list --status=active | awk 'NR>1 {print $1}')
  if [[ ${#CLUSTERS[@]} -eq 0 ]]; then
    echo "ERROR: Unable to list active clusters – pw CLI may be unauthenticated." >&2
    exit 1
  fi
else
  CLUSTERS=("$@")
fi

BASENAME=$(basename "$BUCKET_URI")

# Reject dotfiles to avoid overwriting hidden files in the remote home
if [[ "$BASENAME" == .* ]]; then
  echo "ERROR: Bucket object name '$BASENAME' starts with a dot and is rejected to protect remote dotfiles." >&2
  exit 1
fi

FAILURES=0

for CLUSTER in "${CLUSTERS[@]}"; do
  # Perform copy to temporary name and rename on success, protected by timeout
  if timeout 60 pw ssh "$CLUSTER" "pw buckets cp \"$BUCKET_URI\" \"${BASENAME}.tmp\" && mv \"${BASENAME}.tmp\" \"${BASENAME}\"" </dev/null; then
    echo "$CLUSTER: OK"
  else
    echo "$CLUSTER: FAILED"
    ((FAILURES++))
  fi
done

if (( FAILURES > 0 )); then
  echo "FAILED clusters: $FAILURES"
  exit 1
else
  echo "All copies succeeded."
  exit 0
fi

# Test Plan
# ---------
# 1. No arguments – script should display usage and exit 1.
# 2. Unauthenticated pw CLI – when `pw clusters list` fails, script should emit
#    an error message and exit 1.
# 3. Unreachable cluster – simulate by providing a bogus cluster URI; the
#    timeout should cause a FAILED entry and the script should exit 1.
# 4. Failed copy – force `pw buckets cp` to fail (e.g., non‑existent bucket
#    object); script should report FAILED and exit 1.
# 5. Successful copy – with a reachable cluster and a valid bucket object,
#    ensure the temporary file is renamed and the script exits 0.

# Test Script (bash)
# ------------------
##!/usr/bin/env bash
#set -euo pipefail
#
## Helper to capture exit status and output
#run_script() {
#  local args=("$@")
#  ./strong-gpt-oss-120b-post-critique.sh "${args[@]}" >out.txt 2>&1 || true
#  echo "Exit:$?" >>out.txt
#}
#
## 1. No arguments
#run_script
#grep -q "Usage:" out.txt && echo "PASS: no arguments" || echo "FAIL: no arguments"
#
## 2. Unauthenticated CLI (mock pw command)
#mkdir -p mock_bin && echo -e "#!/usr/bin/env bash\nexit 1" >mock_bin/pw
#chmod +x mock_bin/pw
#PATH=$(pwd)/mock_bin:$PATH run_script fake-bucket-uri fake-cluster
#grep -q "ERROR: Unable to list active clusters" out.txt && echo "PASS: unauthenticated" || echo "FAIL: unauthenticated"
#
## Cleanup
#rm -rf mock_bin out.txt

# Stage-2 capture — Round 2 · Platform owner

- Model: **gpt-oss-120b** · captured 2026-08-19
- Prompt: `critique_prompts.md` Round 2, fresh chat, `strong-gpt-oss-120b.sh` pasted under `SCRIPT UNDER REVIEW:`
- The Round-2 slide shows findings 1, 3, 5, 10, and 13 lightly trimmed. Confirm-against-the-code verdicts are in the slide's speaker note.

---

High – pw ssh "$CLUSTER" pw buckets cp "$BUCKET_URI" "$HOME/$BASENAME" – overwrites any existing file with the same name in every target cluster's home directory, causing irreversible data loss for all users of those clusters.

High – pw ssh "$CLUSTER" pw buckets cp "$BUCKET_URI" "$HOME/$BASENAME" – copies the bucket file to every cluster without checking available disk space, which can exhaust storage on the clusters and on shared backend storage, leading to node failures and platform‑wide outages.

High – pw ssh "$CLUSTER" pw buckets cp … – runs the full pw CLI remotely via SSH; a malicious or malformed $BUCKET_URI (or additional arguments hidden in the URI) could be interpreted as extra pw sub‑commands, allowing an attacker to execute arbitrary platform actions on each cluster (e.g., deleting resources, creating privileged accounts).

High – pw ssh "$CLUSTER" – cluster identifiers are taken verbatim from the command line or from pw clusters list; if a cluster name contains shell‑special characters or spaces, it can break the SSH invocation and enable command injection or unintended command execution on the controller node.

High – timeout 60 pw ssh "$CLUSTER" pw buckets cp "$BUCKET_URI" "$HOME/$BASENAME" – if the timeout kills the SSH process, a partially transferred file remains on the remote host, corrupting data and potentially breaking downstream jobs that expect a complete file.

Medium – mapfile -t CLUSTERS < <(pw clusters list --status=active | awk 'NR>1 {print $1}') – if the platform returns an extremely large list of active clusters, populating the Bash array can exhaust memory on the submission node, causing the script (and possibly other jobs on that node) to crash.

Medium – if [[ ${#CLUSTERS[@]} -eq 0 ]]; then … – when credentials are expired or the pw CLI is unauthenticated, the script aborts with a generic error, making it easy for automation to silently fail and repeatedly hammer the authentication service.

Medium – for CLUSTER in "${CLUSTERS[@]}"; do … – copying clusters sequentially generates a burst of API/SSH traffic; on a busy day this can saturate network links or exceed rate limits imposed by the platform, degrading service for all users sharing the clusters.

Medium – echo "$CLUSTER: FAILED" / FAILURES handling – the script only reports a count of failed clusters and does not log detailed error messages or preserve partial logs, hindering operators from diagnosing recurring failures, which can lead to repeated futile runs that waste compute and storage resources.

Medium – "$HOME/$BASENAME" – the script relies on the remote $HOME environment variable; if $HOME is undefined (or set to /), the copy target becomes /$BASENAME, potentially overwriting critical system files on the remote node.

Low – BASENAME=$(basename "$BUCKET_URI") – basename does not sanitize path components; crafted URIs such as ../../etc/passwd could produce a filename that, when combined with $HOME, attempts to write outside the intended directory.

Low – exit $FAILURES – if more than 255 clusters fail, the exit code wraps modulo 256, misleading calling automation about the true number of failures.

Low – set -euo pipefail together with timeout … – a timeout that causes a non‑zero exit status will trigger the set -e behavior, causing the entire script to abort immediately and skip the failure‑counting logic, potentially leaving other clusters untouched while reporting no summary.

Low – No explicit validation of the bucket URI format – the script trusts any string passed as $1; an attacker could supply a URI that points to a malicious storage endpoint, causing the platform to fetch unauthenticated data or inadvertently trigger external network traffic.

Low – Lack of concurrency control – the script runs one copy at a time; if a cluster becomes unresponsive, the overall job runtime can balloon, tying up scheduler resources and preventing other users' jobs from starting.

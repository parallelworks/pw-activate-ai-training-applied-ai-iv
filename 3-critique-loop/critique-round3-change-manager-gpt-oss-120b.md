# Stage-2 capture — Round 3 · Change manager

- Model: **gpt-oss-120b** · captured 2026-08-19
- Prompt: `critique_prompts.md` Round 3, fresh chat, `strong-gpt-oss-120b.sh` pasted under `SCRIPT UNDER REVIEW:`
- The Round-3 slide shows the three Highs plus the rollback and dry-run Mediums, lightly trimmed. Confirm-against-the-code verdicts are in the slide's speaker note.
- **Note:** the third High is an exact, correct diagnosis of the planted `$HOME` bug — caught by the least technical persona after round 1 half-saw it and round 2 explained it backwards.

---

High – Critical blockers

Missing automated test suite (unit, integration, end‑to‑end) to verify correct copying and failure handling.

No formal documentation (purpose, parameters, required environment, version, author, change history) for production hand‑over.

Functional bug: $HOME is expanded locally, so the remote pw buckets cp writes to the invoking machine's path instead of the target cluster's home directory.

Medium – Significant operational gaps

Insufficient input validation/sanitization of BUCKET_URI and cluster identifiers, risking malformed inputs or command injection.

No retry or exponential back‑off for transient failures; a single timeout marks the cluster as failed without recovery attempts.

Absence of rollback or cleanup logic; partial successes leave files on some clusters with no automated way to undo.

No signal handling (SIGINT/SIGTERM), leaving potentially hung SSH sessions on abrupt termination.

Lack of structured observability (centralized logging, metrics, audit records); only ad‑hoc stdout messages are emitted.

No dry‑run or preview mode to confirm target clusters and paths before performing copies.

No pre‑execution checks for required external dependencies (pw, timeout, awk) or authentication state.

Security oversight: bucket URIs may be echoed in logs or error messages, risking credential leakage.

Low – Minor usability/robustness issues

Exit code returns the total number of failed copies, which can exceed the 0‑255 range and be ambiguous for callers.

Hard‑coded 60‑second timeout with no configurability for environments that need longer/shorter limits.

No persistent log file or rotation; script output is lost after completion.

Sequential processing of clusters can be inefficient for large sets; no concurrency option.

Timeout exit status (124) is not distinguished from other errors, reducing diagnostic clarity.

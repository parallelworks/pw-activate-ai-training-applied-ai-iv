<!-- Facilitator: this is the improved prompt shown AFTER the critique loop — the
"acceptance criteria before generation" version of weak_prompt.md. It is
deliberately NOT over-specified: the criteria are behavior-level things a
participant could write before seeing any failures, plus one proven command
pasted from a real terminal session ("steal from your best examples").
Expect the generated script to be far better than the weak draft and still
carry a real bug — the 20b capture (strong-gpt-oss-20b.sh) has a dead
authentication check (`|| true` forcing `$?` to 0); the 120b capture
(strong-gpt-oss-120b.sh) has `((FAILURES++))` under `set -e` and a locally
expanded `$HOME`. That is the live demo of the verify step, not a failure of
the exercise. The full evolution story (which failure taught which
rule) is in FACILITATOR_NOTES.md — tell it in the debrief.
Strip this comment if you don't want it pasted. -->

Write a bash script `stage_file.sh` that copies a file from an ACTIVATE bucket to connected clusters using the ACTIVATE CLI (`pw`).

## Context

- List active clusters (first column after the header is the cluster URI):
  `pw clusters list --status=active`
- This command works from my terminal — it copies a bucket file into a cluster's home directory:
  `timeout 60 pw ssh "$cluster" pw buckets cp "$FILE" "$DEST" </dev/null`
- The `pw` CLI is already authenticated; if it is not, listing clusters fails — that must surface as one clear error, not a confusing cascade

## Acceptance criteria — the script must:

1. Print a usage message and exit non-zero when called without arguments; the bucket URI is the first argument, optional cluster URIs follow — **by default, target every active cluster**
2. Copy the file into the remote home directory under its own name (the basename of the bucket URI)
3. A failed, unreachable, or hung cluster must not stop the loop — every remaining cluster still gets the file
4. Print `OK` or `FAILED` for every cluster, end with an **accurate** failure count, and exit non-zero if anything failed
5. Never handle, export, or print credentials
6. Keep it short and simple — a single sequential loop, no background jobs

## Verification

After writing the script:

1. Review it against each numbered criterion and state, one line per criterion, where it is satisfied.
2. Produce a short test plan covering the failure paths: no arguments, an unauthenticated `pw` CLI, an unreachable cluster, and a failed copy.

When testing, pass a single sandbox cluster as an explicit argument — never the full fleet.

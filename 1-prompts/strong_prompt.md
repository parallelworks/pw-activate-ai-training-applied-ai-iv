<!-- Facilitator: the "acceptance criteria before generation" version of
weak_prompt.md. It is deliberately NOT over-specified: the criteria are
behavior-level things a participant could write before seeing any failures,
plus one proven command pasted from a real terminal session ("steal from your
best examples"). Expect the generated draft to be far better than the weak
draft and still carry a real bug — that is the live demo of the verify step, not a failure of
the exercise.
Strip this comment if you don't want it pasted. -->

Write a bash script `stage_file.sh` that copies a file from an ACTIVATE bucket to connected clusters using the ACTIVATE CLI (`pw`).

## Context

- List active clusters (first column after the header is the cluster URI):
  `pw clusters list --status=active`
- This command works from my terminal — it copies a bucket file into a cluster's home directory:
  `timeout 60 pw ssh "$cluster" pw buckets cp "$FILE" "$DEST" </dev/null`
- The `pw` CLI is already authenticated; if it is not, listing clusters fails — that must surface as one clear error, not a confusing cascade

## Acceptance criteria — the script must:

1. Print a usage message and exit non-zero when called without arguments; the bucket URI is the first argument, cluster URIs follow
2. **Never target the fleet by default.** With a bucket URI but no cluster arguments, print the usage message and exit non-zero **without contacting anything**; copying to every active cluster must require an explicit `--all` flag (targets the clusters listed by `pw clusters list --status=active`)
3. Copy the file into the remote home directory under its own name (the basename of the bucket URI)
4. A failed, unreachable, or hung cluster must not stop the loop — every remaining cluster still gets the file
5. Print `OK` or `FAILED` for every cluster, end with an **accurate** failure count, and exit non-zero if anything failed
6. Never handle, export, or print credentials
7. Keep it short and simple — a single sequential loop, no background jobs

## Verification

After writing the script:

1. Review it against each numbered criterion and state, one line per criterion, where it is satisfied.
2. Produce a short test plan covering the failure paths: no arguments, a bucket URI with no clusters and no `--all`, an unauthenticated `pw` CLI, an unreachable cluster, and a failed copy.

When testing, pass a single sandbox cluster as an explicit argument — never `--all`.

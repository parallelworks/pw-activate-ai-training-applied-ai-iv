<!-- Facilitator: ready-to-paste prompts for the critique capture, written for
pw code (the agent reads and writes files in the workspace).
HOW TO RUN:
- Save the draft under review as stage_file.sh in the working directory.
- One persona per FRESH pw code session — independence is the point. A shared
  session makes later personas anchor on earlier findings; a combined single
  prompt makes the model deduplicate across personas. Three fresh sessions
  give you three independent reviewers.
- For each round: paste the prompt, let the agent read stage_file.sh and write
  its critique-*.md file, and keep that file unedited. The shared format keeps
  the three critiques comparable line by line. When filing captures in the
  repo, add the round and model to the name, e.g. critique-security.md →
  critique-round1-security-gpt-oss-120b.md.
- Confirm every finding against the code, fill round 4's CONFIRMED FINDINGS,
  then run round 4 in a fresh session and keep stage_file_revised.sh and
  revision-notes.md.
- While capturing, note any finding that cites code that isn't there — that's
  the "confirm in the code first" discussion beat — and note what every
  persona misses: whatever verification later catches that review missed is
  the stage-4 punchline. -->

# Critique-loop prompts

All rounds assume the script under review is saved as `stage_file.sh` in the
working directory of the session.

## Round 1 — Security engineer (fresh pw code session)

```
Act as a senior security engineer reviewing the bash script stage_file.sh (in
this directory) before it can drive our production clusters through the
ACTIVATE CLI (pw). It copies a file from a storage bucket to the home
directory of a set of clusters.

This is a static review: do not execute stage_file.sh or any pw command.

Read stage_file.sh and write every finding to a new file critique-security.md
in exactly this format, nothing else:

# Security engineer — stage_file.sh

- [High] line <n>: <finding, one sentence>
- [Medium] line <n>: <finding, one sentence>
- [Low] line <n>: <finding, one sentence>

One bullet per finding, most severe first. Use real line numbers from
stage_file.sh ("lines <n>-<m>" for a range; "missing" when the finding is
about something the script lacks). Findings only — do not fix anything, do
not rewrite the script, do not summarize what it does.
```

## Round 2 — Platform owner (fresh pw code session)

```
Act as the owner of the HPC platform and the clusters that the bash script
stage_file.sh (in this directory) talks to. It copies a file from a storage
bucket to the home directory of a set of clusters via the ACTIVATE CLI (pw).
Other teams share these clusters.

What could this script do to my clusters, to other users' clusters, to shared
storage, or to the platform API if it misbehaves, is misused, or runs on a bad
day (hung nodes, expired credentials, a cluster that fails mid-run)?

This is a static review: do not execute stage_file.sh or any pw command.

Read stage_file.sh and write every finding to a new file
critique-platform-owner.md in exactly this format, nothing else:

# Platform owner — stage_file.sh

- [High] line <n>: <finding, one sentence>
- [Medium] line <n>: <finding, one sentence>
- [Low] line <n>: <finding, one sentence>

One bullet per finding, most severe first. Use real line numbers from
stage_file.sh ("lines <n>-<m>" for a range; "missing" when the finding is
about something the script lacks). Findings only — do not fix anything, do
not rewrite the script.
```

## Round 3 — Change manager (fresh pw code session)

```
Act as a change manager deciding whether the bash script stage_file.sh (in
this directory) can be approved for production use. It copies a file from a
storage bucket to the home directory of a set of clusters via the ACTIVATE
CLI (pw).

What is missing for production approval — documentation, tests, operational
safeguards, rollback, observability, evidence it handles failure?

This is a static review: do not execute stage_file.sh or any pw command.

Read stage_file.sh and write every finding to a new file
critique-change-manager.md in exactly this format, nothing else:

# Change manager — stage_file.sh

- [High] line <n>: <finding, one sentence>
- [Medium] line <n>: <finding, one sentence>
- [Low] line <n>: <finding, one sentence>

One bullet per finding, most severe first. Use real line numbers from
stage_file.sh ("lines <n>-<m>" for a range; "missing" when the finding is
about something the script lacks). Findings only — do not fix anything, do
not rewrite the script.
```

## Round 4 — Revise (fresh pw code session, after you have confirmed the findings)

<!-- Filled with the findings confirmed against stage_file.sh from
the three captured rounds (5 confirmed out of 20 raised, after merging
duplicates). Two bugs are deliberately ABSENT because no persona found them —
the revise can only fix what review found; they are stage 4's catch:
1) ((FAIL_COUNT++)) under set -e (line 62): the script dies counting its
   first failure.
2) --all silently overrides explicitly passed clusters (line 46), contradicting
   the usage text on line 12 — "stage_file.sh <bucket> --all <sandbox>" targets
   the FLEET. Never test with --all while authenticated. -->

```
Read stage_file.sh in this directory. Below are the confirmed findings from
three independent reviews of it. Write a revised script to
stage_file_revised.sh so that every confirmed finding is addressed; leave
stage_file.sh unchanged. Then write revision-notes.md with two sections:

1. Changes — one line per change, keyed to the finding it resolves, so I can
   verify every fix exists in the code.
2. Test plan — a short test plan covering the failure paths: no arguments, a
   bucket URI with no clusters and no --all, an unauthenticated pw CLI, an
   unreachable cluster, and a failed copy.

This is a revision, not a test run: do not execute stage_file.sh,
stage_file_revised.sh, or any pw command.

CONFIRMED FINDINGS:
1. Line 58: the destination "$HOME/$BASENAME" expands $HOME on the LOCAL
   machine before the command is sent, so the copy targets the invoking
   machine's home path instead of the cluster's home. Fix: copy to the bare
   basename, relative to the remote home.
2. Lines 46-50: if pw clusters list fails (for example an unauthenticated pw
   CLI), the failure inside the process substitution does not stop the
   script: CLUSTERS ends up empty, the copy loop never runs, and the script
   exits 0 — a silent false success. Fix: after building CLUSTERS, print one
   clear error and exit 1 if the list is empty.
3. Line 58: a transfer killed by the 60-second timeout can leave a partial
   file at the destination. Fix: copy to a temporary name and rename it into
   place only on success.
4. Lines 22, 34, 54, 58: the bucket URI, its basename, and the cluster URIs
   are placed into a remote command without any validation; a bucket object
   named like a dotfile (e.g. .bashrc) silently overwrites hidden files in
   the remote home, and a name starting with "-" is read as an option by
   basename. Fix: before contacting anything, require the basename and every
   URI to start with a letter or digit and use a conservative character set;
   reject everything else, empty strings included.
5. Lines 1-15: the header is a single line; purpose, usage, and behavior on
   failure are not documented, and no test plan ships with the script. Fix:
   add a short header (purpose, usage, behavior on failure); the test plan
   goes in revision-notes.md as requested above.
```

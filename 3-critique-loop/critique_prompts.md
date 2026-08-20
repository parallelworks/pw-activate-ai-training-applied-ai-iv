<!-- Facilitator: ready-to-paste prompts for the Stage-2 critique capture.
HOW TO RUN:
- One persona per FRESH chat (or fresh pw code session) — independence is the point.
  A shared chat makes later personas anchor on earlier findings; a combined single
  prompt makes the model deduplicate across personas. Three fresh chats give you
  three independent reviewers, which is what the Stage-2 slide table needs.
- For each round: paste the prompt, then paste the full script under the
  "SCRIPT UNDER REVIEW" line, send, and save the output.
- Then run the revise prompt (round 4) in whichever chat you prefer, and save that too.
- While capturing, watch for: does ANY persona flag `((FAILURES++))` under `set -e`,
  or `$HOME` expanding locally? Whatever they miss is the Stage-3 punchline.
  Also note any finding that cites code that isn't there — that's the
  "confirm in the code first" discussion beat. -->

# Critique-loop prompts

## Round 1 — Security engineer (fresh chat)

```
Act as a senior security engineer reviewing the bash script below before it can
drive our production clusters through the ACTIVATE CLI (pw). It copies a file
from a storage bucket to the home directory of a set of clusters.

List every finding with a severity (High / Medium / Low) and the exact line or
snippet it refers to, most severe first. One line per finding. Findings only —
do not fix anything, do not rewrite the script, do not summarize what it does.

SCRIPT UNDER REVIEW:
```

## Round 2 — Platform owner (fresh chat)

```
Act as the owner of the HPC platform and the clusters the bash script below
talks to. It copies a file from a storage bucket to the home directory of a set
of clusters via the ACTIVATE CLI (pw). Other teams share these clusters.

What could this script do to my clusters, to other users' clusters, to shared
storage, or to the platform API if it misbehaves, is misused, or runs on a bad
day (hung nodes, expired credentials, a cluster that fails mid-run)? List every
finding with a severity (High / Medium / Low) and the exact line or snippet it
refers to, most severe first. One line per finding. Findings only — do not fix
anything, do not rewrite the script.

SCRIPT UNDER REVIEW:
```

## Round 3 — Change manager (fresh chat)

```
Act as a change manager deciding whether the bash script below can be approved
for production use. It copies a file from a storage bucket to the home
directory of a set of clusters via the ACTIVATE CLI (pw).

What is missing for production approval — documentation, tests, operational
safeguards, rollback, observability, evidence it handles failure? List every
finding with a severity (High / Medium / Low), most severe first. One line per
finding. Findings only — do not fix anything, do not rewrite the script.

SCRIPT UNDER REVIEW:
```

## Round 4 — Revise (any chat, after you have confirmed the findings)

<!-- Filled 2026-08-19 with the findings confirmed against the code from the three
captured rounds (5 confirmed out of 39 raised). ((FAILURES++)) under set -e is
deliberately ABSENT — no persona found it, and the revise can only fix what review
found; that bug is stage 3's catch. Paste the script below the SCRIPT: line. -->

```
Below are the confirmed findings from three independent reviews of the script,
followed by the script itself. Rewrite the script so every confirmed finding is
addressed. After the rewritten script, explain each change in one line, keyed
to the finding it resolves, so I can verify every fix exists in the code.
Then produce a short test plan covering the failure paths: no arguments, an
unauthenticated pw CLI, an unreachable cluster, and a failed copy.

CONFIRMED FINDINGS:
1. The destination "$HOME/$BASENAME" expands $HOME on the LOCAL machine before
   the command is sent, so the copy targets the invoking machine's home path
   instead of the cluster's home. Fix: copy to the bare basename, relative to
   the remote home.
2. exit $FAILURES truncates above 255 (exactly 256 failures would exit 0).
   Fix: exit 1 if anything failed; keep the exact count in the printed summary.
3. A transfer killed by timeout may leave a partial file at the destination.
   Fix: copy to a temporary name and move into place on success, or verify the
   copy after it completes.
4. A bucket object named like a dotfile (e.g. .bashrc) silently overwrites that
   file in the remote home directory. Fix: reject basenames that start with "."
   (or enforce a conservative filename character set).
5. No header documentation and no test plan ship with the script. Fix: add a
   short header (purpose, usage, behavior on failure) and produce the test plan
   requested below.

SCRIPT:
```

# Manual failure-path tests — `stage_file_revised.sh`

## How this works, in plain words

- **Real unauthenticated `pw`, no mock needed.** The CLI keeps its saved
  credential in `~/.config/pw/credentials`, and `PW_CREDENTIALS_DIR` relocates
  that file (see `pw auth`). Pointing it at an empty folder gives a CLI with
  no credentials at all. Prefixing a test with
  `PW_CREDENTIALS_DIR=$PWD/no-creds` runs that one command unauthenticated —
  and doubles as a tripwire: a test that should contact nothing shows a real
  auth error if it tries. (If you use `PW_API_KEY`, unset it first — it takes
  precedence over the credentials file.)
- **One mock, for the one thing that must never run for real.** `mock-fleet/pw`
  is a fake `pw` that reports two fake active clusters and echoes every other
  call. Prefixing its folder to `PATH` lets us watch what `--all` *would*
  target, with zero platform contact.

## Where to run

- **Group A (T1–T6):** any machine with bash ≥ 4.
- **Group B (T7–T10):** any machine with bash ≥ 4, the `timeout` command, and
  an authenticated `pw` (workspaces are pre-authenticated; running locally,
  `pw auth` once).
- **⚠️ Never pass `--all` to the draft or the revision outside the mocked
  test T6.** The revision replaces explicitly listed clusters with the full
  fleet whenever `--all` is present (line 86). Only the verified
  `stage_file_final.sh` may use `--all` for real — see "Using `--all` for
  real" at the end.

## Setup — paste once, in the directory containing the script

```bash
SCRIPT=stage_file_revised.sh
BUCKET=pw://avidalto/alvarotest/hello.txt
SANDBOX=pw://avidalto/awssmall     # ephemeral cloud cluster: safe to break

mkdir -p no-creds mock-fleet       # no-creds stays empty on purpose

cat > mock-fleet/pw <<'EOF'
#!/usr/bin/env bash
if [[ "${1-} ${2-}" == "clusters list" ]]; then
  printf 'URI STATUS\npw://mock/cluster1 active\npw://mock/cluster2 active\n'
else
  echo "MOCK pw $*"
fi
exit 0
EOF
chmod +x mock-fleet/pw
```

## Group A — no platform contact

The expected result is inside each banner, so the terminal output documents
itself.

```bash
echo "=== T1 no arguments (expect: usage, exit=1) ==="
PW_CREDENTIALS_DIR=$PWD/no-creds bash "$SCRIPT"; echo "exit=$?"

echo "=== T2 bucket only (expect: usage, exit=1 — fleet is NOT the default) ==="
PW_CREDENTIALS_DIR=$PWD/no-creds bash "$SCRIPT" "$BUCKET"; echo "exit=$?"

echo "=== T3 dotfile object (expect: basename error, exit=1, no auth error) ==="
PW_CREDENTIALS_DIR=$PWD/no-creds bash "$SCRIPT" pw://avidalto/alvarotest/.bashrc "$SANDBOX"; echo "exit=$?"

echo "=== T4 empty cluster arg (expect: invalid CLUSTER_URI error, exit=1) ==="
PW_CREDENTIALS_DIR=$PWD/no-creds bash "$SCRIPT" "$BUCKET" ""; echo "exit=$?"

echo "=== T5 unauthenticated --all (expect: clear listing error, exit=1 — never a silent exit 0) ==="
PW_CREDENTIALS_DIR=$PWD/no-creds bash "$SCRIPT" "$BUCKET" --all; echo "exit=$?"

echo "=== T6 --all + explicit cluster (WATCH: which cluster is attempted?) ==="
PATH="$PWD/mock-fleet:$PATH" bash "$SCRIPT" "$BUCKET" --all "$SANDBOX"; echo "exit=$?"
```

T6 verdict guide — safe behavior attempts **only** `$SANDBOX`. Seeing
`pw://mock/cluster1` means `--all` clobbered your explicit cluster (with real
credentials: the fleet). Stopping after one `FAILED` with no
`Total failures:` line means the `((FAIL_COUNT++))`-under-`set -e` counter
bug fired.

## Group B — real, scoped to the sandbox only

The sandbox `pw://avidalto/awssmall` is an ephemeral cloud cluster: its own
`pw` starts **unauthenticated** (cloud clusters are not pre-authenticated)
until you authenticate it yourself. Group B uses that on purpose — T5 tested
the local CLI; T7 tests the cluster side for real.

Pre-flight — Group B is meaningless without `timeout` (the copy fails locally
and the platform is never reached):

```bash
command -v timeout || echo "STOP: 'timeout' not found — switch to a terminal that has it (e.g. an ACTIVATE workspace)"
```

T7 setup — put the sandbox's `pw` into the unauthenticated state (reversible:
the credential is just moved aside; skip if it was never authenticated):

```bash
pw ssh "$SANDBOX" 'mv ~/.config/pw/credentials ~/.config/pw/credentials.bak && echo deauthed'
```

```bash
echo "=== T7 remote pw unauthenticated (expect: remote 'no context configured', FAILED, 'Total failures: 1', exit=1 — never a false success) ==="
bash "$SCRIPT" "$BUCKET" "$SANDBOX"; echo "exit=$?"
```

**Between T7 and T8** — re-authenticate the sandbox's `pw`. Repeat until you
see `restored` (a transient failure here leaves the sandbox de-authed and T8/T9
fail for the wrong reason):

```bash
pw ssh "$SANDBOX" 'mv ~/.config/pw/credentials.bak ~/.config/pw/credentials && echo restored'
```

(First-time setup instead: `pw ssh "$SANDBOX"`, run `pw auth` on the cluster,
paste your credential, exit. Non-interactive alternative: `PW_API_KEY`.)

```bash
echo "=== T8 broken cluster FIRST (expect: FAILED, then sandbox OK, then 'Total failures: 1', exit=1) ==="
bash "$SCRIPT" "$BUCKET" pw://avidalto/no-such-cluster "$SANDBOX"; echo "exit=$?"

echo "=== T9 happy path (expect: OK, exit=0) ==="
bash "$SCRIPT" "$BUCKET" "$SANDBOX"; echo "exit=$?"

echo "=== T10 file landed? (expect: hello.txt present, no temp files) ==="
pw ssh "$SANDBOX" 'ls -l hello.txt hello.txt.tmp .tmp_hello.txt'
```

Verdict guide for T7 and T8 — if the script dies right after a `FAILED` line
with no `Total failures:` line (in T8: without ever reaching the sandbox),
that is the `((FAIL_COUNT++))`-under-`set -e` counter bug: the
loop-must-continue criterion fails. T10 also proves the rename-on-success
design: a killed transfer may leave a stale temp file, never a partial
`hello.txt`.

## Results — `stage_file_revised.sh` (the round-4 revision)

| Test | Status |
|---|---|
| T1 | ✓ pass |
| T2 | ✓ pass |
| T3 | ✓ pass |
| T4 | ✓ pass |
| T5 | ✓ pass — real `no context configured` error surfaced as one clear message, exit 1 |
| T6 | ✓ ran — both bugs confirmed: `--all` dropped the explicit cluster; the script died counting its first failure |
| T7 | ✗ fail (expected for the revision) — the honest-failure half passed: remote `no context configured`, `FAILED (copy)`, exit 1. But the `Total failures: 1` summary never printed — the counter bug killed the script first |
| T8 | ✗ fail (expected for the revision) — **counter bug confirmed**: the bogus cluster failed with a real platform error, then the script died — no sandbox attempt, no `Total failures:` line, exit 1. "A failed cluster must not stop the loop" fails |
| T9 | ✓ pass — `OK`, exit 0; the transfer log shows the destination in the CLUSTER's home (`/home/avidalto/…`), confirming the remote-`$HOME` fix end-to-end |
| T10 | ✓ pass — `hello.txt` in the remote home; temp file absent — rename-on-success confirmed |

## The finish line

`stage_file_final.sh` — the round-4 revision plus the manual fixes the
failure-path runs demanded — **passes all tests (T1–T10)**.

So we can finally run it with `--all`. It now does exactly what it says:
fleet scope only on explicit request, never combined with explicit clusters,
loud failure when unauthenticated, and a per-cluster report you can trust.
What's left is intent, not risk — check the target list, then go:

```bash
pw clusters list --status=active     # this exact list is what --all targets
bash stage_file_final.sh pw://avidalto/alvarotest/hello.txt --all
```

The file lands in every active cluster's home under its own name, overwriting
any same-named file — run it when that is what you mean.

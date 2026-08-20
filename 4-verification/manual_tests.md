# Manual failure-path tests — `strong-gpt-oss-120b-final.sh`

Run in a **workspace terminal** (Linux, bash ≥ 4 — not macOS bash 3.2, which
lacks `mapfile` and `timeout`). Substitute your own bucket and sandbox cluster.
**Never omit the cluster argument while authenticated** — with no cluster
arguments the script targets every active cluster your account can see.

```bash
SCRIPT=strong-gpt-oss-120b-final.sh
BUCKET=pw://avidalto/alvarotest/hello.txt
SANDBOX=pw://avidalto/awssmall

echo "=== T1 no arguments ==="
bash "$SCRIPT"; echo "exit=$?"

echo "=== T2 dotfile object ==="
bash "$SCRIPT" pw://avidalto/alvarotest/.bashrc "$SANDBOX"; echo "exit=$?"

echo "=== T3 empty cluster argument ==="
bash "$SCRIPT" "$BUCKET" ""; echo "exit=$?"

echo "=== T4 unauthenticated, scoped to the sandbox ==="
PW_CONTEXT=doesnotexist bash "$SCRIPT" "$BUCKET" "$SANDBOX"; echo "exit=$?"

echo "=== T5 happy path ==="
bash "$SCRIPT" "$BUCKET" "$SANDBOX"; echo "exit=$?"

echo "=== T6 where did the file land ==="
pw ssh "$SANDBOX" 'ls -l hello.txt hello.txt.tmp'

echo "=== T7 broken cluster before the healthy one ==="
bash "$SCRIPT" "$BUCKET" pw://avidalto/no-such-cluster "$SANDBOX"; echo "exit=$?"
```

## Expected results (status from the 2026-08-19 run)

| Test | Expected | Status |
|------|----------|--------|
| T1 | Usage with the real script name, exit 1 | ✓ measured |
| T2 | `ERROR: bucket object name '.bashrc' …`, exit 1, nothing contacted | ✓ measured |
| T3 | `ERROR: invalid cluster URI ''.`, exit 1, nothing contacted | ✓ measured |
| T4 | Failure reported honestly: per-cluster `FAILED`, exact count, exit 1 — never a false success | ✓ measured — see caveat below |
| T5 | `… OK`, `All 1 copies succeeded.`, exit 0 | pending — blocked by cluster-side pw (below) |
| T6 | `hello.txt` in the **remote** home; `hello.txt.tmp` absent | pending (follows T5) |
| T7 | `FAILED` → loop **continues** → `OK` → `FAILED clusters: 1 of 2` → exit 1 | ✓ loop + count measured (`2 of 2`); the `OK` half follows T5 |

## Caveats learned from real runs

- **`PW_CONTEXT=doesnotexist` is inert in a workspace** (measured: T4 and T5
  behaved identically). It does not de-authenticate the local CLI, so T4 is not
  a true unauthentication test there; a genuine one needs a machine with no pw
  config at all.
- **The `[ERROR] no context configured` lines can come from the CLUSTER side**:
  the copy command runs on the target cluster via `pw ssh`, so a cluster whose
  own `pw` has no context prints that error and counts as `FAILED` — even
  though your local CLI is fine. Diagnose with:

      pw ssh "$SANDBOX" 'which pw; pw buckets cp pw://<user>/<bucket>/<file> hello.txt; echo "remote_exit=$?"'

  If the context error appears there, fix the cluster (or pick one whose remote
  `pw` is configured); the script is behaving correctly.
- The one row that cannot be staged: a **timeout-killed transfer** (test-plan
  row 7 in the script header). It rests on the code read: the copy lands under
  a temporary name and is renamed only on success, so a killed transfer can
  leave a stale `.tmp` but never a partial file under the final name.

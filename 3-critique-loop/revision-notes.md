# Revision notes — stage_file_revised.sh

## 1. Changes

- **Finding 1 (remote $HOME expansion)** – The copy destination is now written as `"\$HOME/${TEMP_NAME}"` (escaped `$HOME`), so the variable is expanded on the **cluster**, not on the invoking machine; the file lands in the remote home directory (lines 105‑107).
- **Finding 2 (silent false success on cluster listing)** – The `--all` branch now captures the `pw clusters list` output explicitly, exits 1 with a clear error if the pipeline fails (e.g., unauthenticated `pw`), and exits 1 with a second clear error if the resulting cluster list is empty (lines 86‑97).
- **Finding 3 (partial file on timeout)** – The transfer now goes to a temporary name `.tmp_${BASENAME}` and is renamed (`mv`) into its final name **only after the copy succeeds**; on a failed or timed‑out copy the temporary file is removed with `rm -f` so no partial file survives at the final destination (lines 101, 105‑118).
- **Finding 4 (unvalidated URIs / basename)** – Two validators were added and are run **before any remote contact**: `is_valid_uri` requires the bucket URI and every cluster URI to start with a letter or digit (rejecting empty strings and leading `-`), and `is_valid_basename` restricts the derived basename to `[A-Za-z0-9][A-Za-z0-9._-]*`, which rejects dotfile names such as `.bashrc` (lines 32‑38, 49‑58, 70‑73).
- **Finding 5 (missing documentation)** – The header now documents the script's purpose, full usage, and behavior on every failure path (bad arguments, failed listing, invalid names, unreachable cluster / timeout, partial copy cleanup); the test plan is provided below in this file, as requested (lines 2‑17).

## 2. Test plan

Static test plan only — none of these were executed as part of this revision.

| # | Scenario | How to test | Expected result |
|---|----------|-------------|-----------------|
| 1 | No arguments | Run `./stage_file_revised.sh` with no arguments | Usage text is printed and the script exits 1; no `pw` command is run |
| 2 | Bucket URI, no clusters, no `--all` | Run `./stage_file_revised.sh bucket://proj/data.txt` | Usage text is printed and the script exits 1; no cluster is contacted |
| 3 | Unauthenticated `pw` CLI | Log out of `pw` (or use an expired token) and run with `--all` | "unable to list active clusters" (or "no active clusters found") is printed to stderr and the script exits 1 instead of exiting 0 with an empty loop |
| 4 | Unreachable cluster | Pass a cluster URI that does not respond | The 60‑second timeout kills the copy, the cluster is reported as `FAILED (copy)`, the temporary file is cleaned up, remaining clusters still run, and the script exits 1 |
| 5 | Failed copy | Use a bucket URI that exists syntactically but cannot be read (e.g., no permission) | `pw buckets cp` fails, the cluster is reported as `FAILED (copy)`, no file appears under the final name on the cluster, and the script exits 1 with `Total failures: N` |

Additional negative checks for the new validation: a bucket object named `.bashrc` and any URI starting with `-` must both be rejected before any remote command is issued (exit 1 with the corresponding validation error).

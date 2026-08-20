# Security engineer — stage_file.sh

- [High] line 58: Executes `pw ssh` with unvalidated `$CLUSTER` and `$BUCKET_URI`, allowing an attacker to supply malicious identifiers that could cause command injection or unintended remote connections.
- [Medium] line 22: Assigns `BUCKET_URI` directly from user input without validation, enabling use of arbitrary URIs that may point to unwanted or malicious resources.
- [Medium] line 34: Adds cluster URIs to `CLUSTERS` array without sanitization, potentially allowing injection of crafted values.
- [Low] line 54: Uses `basename "$BUCKET_URI"` without `--`, so a URI beginning with `-` could be interpreted as an option.
- [Low] line 58: Expands `$HOME` locally, leaking the local user's home directory path to the remote command.
- [Low] missing: No verification that the bucket file exists or that the copy succeeded beyond exit status, missing integrity checks such as checksum validation.

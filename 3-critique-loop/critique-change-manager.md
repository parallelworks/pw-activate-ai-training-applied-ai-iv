# Change manager — stage_file.sh

- [High] lines 56-64: missing rollback or cleanup of partially copied files on failure, leading to inconsistent cluster state.
- [Medium] lines 48-49: missing error handling if `pw clusters list` fails, which could result in an empty CLUSTERS list without notice.
- [Medium] line 58: missing verification of copy integrity (e.g., checksum) after `pw buckets cp`, so silent corruption may go undetected.
- [Medium] line 22: missing validation of the BUCKET_URI argument format, allowing invalid URIs to be passed.
- [Low] lines 7-14: usage documentation lacks details on required `pw` authentication and environment prerequisites.
- [Low] line 57: timeout value is hard‑coded (60 s) with no configurability or explanation.
- [Low] missing: no automated tests are provided for this script.

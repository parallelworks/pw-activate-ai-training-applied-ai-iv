<!-- Facilitator: this is the lazy prompt used with `pw code` BEFORE the session to
generate the weak draft. It gives just enough syntax to succeed, no quality
requirements, and the nudges "every cluster that is active" and "make it fast" —
those invite the copy-to-everything blast radius and fire-and-forget parallelism.
⚠️ Review whatever the model generates BEFORE letting pw code execute it: the
obvious implementation writes to (and may delete files on) every active cluster
your account can see, including shared ones. Strip this comment if you don't want
it pasted. -->

Write a bash script that copies our shared input file from the bucket to all our clusters.

Some commands you can use:

```
pw clusters list
pw ssh pw://avidalto/barfoot pw buckets cp pw://avidalto/alvarotest/hello.txt .
```

The file is `pw://avidalto/alvarotest/hello.txt`. Copy it to the home directory of every cluster that is active. Make it fast. Then run it to make sure it works.

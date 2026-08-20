<!-- Facilitator: the lazy ask used with `pw code` to generate the weak draft —
just enough syntax to succeed, no quality requirements. "Every cluster that is
active" and "make it fast" invite the fleet-wide blast radius and the
fire-and-forget parallelism. Strip the comments before pasting. -->

Write a bash script stage_file_weak.sh that copies our shared input file from the bucket to all our clusters.

Some commands you can use:

```
pw clusters list
pw ssh pw://avidalto/barfoot pw buckets cp pw://avidalto/alvarotest/hello.txt .
```

The file is `pw://avidalto/alvarotest/hello.txt`. Copy it to the home directory of every cluster that is active. Make it fast.

<!-- ⚠️ The next sentence makes the agent offer to RUN the script it just wrote —
against every active cluster your account can see. ALWAYS REFUSE the run;
declining it is part of the exercise. Never use --permission-mode bypass-permissions. -->
Then run it to make sure it works.

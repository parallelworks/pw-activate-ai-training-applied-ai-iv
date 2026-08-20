# Applied AI IV — Exercise Material

**From AI Output to Reviewable Work** · Parallel Works ACTIVATE

This folder is the take-home from the demo: every prompt, every unedited model
output, every critique, and the final script — the complete paper trail of the
workflow **criteria → draft → persona critique → confirm → revise → verify**.
Nothing here is staged; every capture is real.

## Folder map

| Folder | Contents |
|--------|----------|
| `1-prompts/` | The weak ask and the strong ask (acceptance criteria) — same task, radically different drafts |
| `2-model-drafts/` | What the model actually returned for each prompt, unedited: `stage_file_weak.sh`, `stage_file.sh` |
| `3-critique-loop/` | Ready-to-paste persona critique prompts (rounds 1–4), the three critiques (`critique-*.md`), and the revision (`stage_file_revised.sh` + `revision-notes.md`) |
| `4-verification/` | The manual failure-path test suite (T1–T10, with its mocks) and the final, hand-finished script |

## The lineage at a glance (gpt-oss-120b)

| Script | Fate |
|--------|------|
| `2-model-drafts/stage_file_weak.sh` | runs; claims success no matter what failed — and asked to run itself |
| `2-model-drafts/stage_file.sh` | looks done; two fatal bugs no review found |
| `3-critique-loop/stage_file_revised.sh` | five confirmed fixes in; still died counting its first failure |
| `4-verification/stage_file_final.sh` | hand-finished; passes all tests (T1–T10) |

## Safety

**Never run the weak or draft scripts against the fleet.** They target every
active cluster your account can see. Test hardened versions only against a
single sandbox cluster passed explicitly:

    bash 4-verification/stage_file_final.sh pw://<user>/<bucket>/<file> pw://<user>/<sandbox-cluster>

**The weak prompt ends with "Then run it to make sure it works."** Pasted into
`pw code`, that sentence makes the agent offer to execute what it just wrote —
against the fleet. Always refuse the run request: it is part of the exercise.
Never start these sessions with `--permission-mode bypass-permissions`.

## Adapt the workflow to your own tasks

1. Write acceptance criteria *before* you generate (steal from `1-prompts/strong_prompt.md`).
2. Critique with personas, one per fresh chat (`3-critique-loop/critique_prompts.md`).
3. Confirm every finding against the code — findings are leads, not verdicts.
4. Revise with the confirmed list only; then verify by running the **failure paths**, not the happy path (`4-verification/manual_tests.md`).
5. Hand-finish the small fixes yourself. Stop when the tests pass and a review finds nothing real.

To reproduce the demo environment: ACTIVATE marketplace → **vLLM + RAG**
workflow (a `*-gpt-oss-120b` preset, vLLM Only mode) → generate the files with
`pw code` against the registered endpoint.
The presentation deck (`slides.md`) lives one level up.

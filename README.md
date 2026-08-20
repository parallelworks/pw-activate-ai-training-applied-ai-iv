# Applied AI IV — Exercise Material

**From AI Output to Reviewable Work** · Parallel Works ACTIVATE

This folder is the take-home from the demo: every prompt, every unedited model
output, every critique, and the final script — the complete paper trail of the
workflow **criteria → draft → persona critique → confirm → revise → verify**.
Nothing here is staged; every capture is real.

## Folder map

| Folder | Contents |
|--------|----------|
| `1-prompts/` | The weak ask and the strong ask (acceptance criteria) — same task, same models, radically different drafts |
| `2-model-drafts/` | What gpt-oss-20b and gpt-oss-120b actually returned for each prompt, unedited |
| `3-critique-loop/` | Ready-to-paste persona critique prompts (rounds 1–4), the three verbatim critiques of the 120b strong draft, and the model's round-4 revision |
| `4-verification/` | The manual failure-path test suite (T1–T7) and the final, hand-finished script |
| `facilitator/` | Answer keys, timing, and setup notes — facilitator material, shared after the session |

## The gpt-oss-120b lineage at a glance

| Script | Fate |
|--------|------|
| `2-model-drafts/weak-gpt-oss-120b.sh` | runs; claims success no matter what failed |
| `2-model-drafts/strong-gpt-oss-120b.sh` | looks done; two hidden bugs |
| `3-critique-loop/strong-gpt-oss-120b-post-critique.sh` | five confirmed fixes in; still died counting its first failure |
| `4-verification/strong-gpt-oss-120b-final.sh` | hand-finished; every failure path verified |

## Safety

**Never run the weak or draft scripts against the fleet.** With no cluster
argument they target every active cluster your account can see. Test hardened
versions only against a single sandbox cluster passed explicitly:

    bash 4-verification/strong-gpt-oss-120b-final.sh pw://<user>/<bucket>/<file> pw://<user>/<sandbox-cluster>

## Adapt the workflow to your own tasks

1. Write acceptance criteria *before* you generate (steal from `1-prompts/strong_prompt.md`).
2. Critique with personas, one per fresh chat (`3-critique-loop/critique_prompts.md`).
3. Confirm every finding against the code — findings are leads, not verdicts.
4. Revise with the confirmed list only; then verify by running the **failure paths**, not the happy path (`4-verification/manual_tests.md`).
5. Hand-finish the small fixes yourself. Stop when the tests pass and a review finds nothing real.

To reproduce the demo environment: ACTIVATE marketplace → **vLLM + RAG**
workflow (vLLM Only mode) → chat via the Open WebUI link in the job output.
The presentation deck (`slides.md`) lives one level up.

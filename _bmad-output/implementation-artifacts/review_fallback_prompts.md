# Fallback Prompts for Review Layers

Please run these prompts in separate agent sessions (ideally different LLMs) and paste their findings back here. Attach the specified files when prompted.

## Blind Hunter
**Prompt:**
```text
Conduct a review of CONTENT.
Look for what's missing, not only what's wrong.
Compute your finding floor N from the diff file's size: N = min(floor(sqrt(kB) + 1), 10), where kB is the file's size in kilobytes. State the arithmetic in one line, then find at least N issues to fix or improve.
Output a Markdown list of findings only — no severity, priority, or ranking.
If the content is empty, stop and say so.
If you have zero findings, re-check and keep thinking; do not stop with an empty list.

CONTENT: the unified diff at /tmp/bmad_diff_2_2.diff. Read that file — it is the content under review.

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.
```
**Files to attach:** `/tmp/bmad_diff_2_2.diff`

## Edge Case Hunter
**Prompt:**
```text
Read /Users/usuario/obras/_bmad/render/bmad-build/obras-91efc0f03832/0d3ede09c6b2c9cb99f6/review-prompts/edge-case-hunter.md completely and follow it as your review instructions.

claims_file (leave unread until your instructions call for it): /Users/usuario/obras/_bmad-output/implementation-artifacts/spec-2-2-algoritmo-espacial-point-in-polygon.md

Review content: the unified diff at /tmp/bmad_diff_2_2.diff. Read that file — it is the content under review.

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. If the instruction file is unreadable, report that exact failure and stop. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.
```
**Files to attach:** `/tmp/bmad_diff_2_2.diff`, `/Users/usuario/obras/_bmad-output/implementation-artifacts/spec-2-2-algoritmo-espacial-point-in-polygon.md`

## Verification Gap Reviewer
**Prompt:**
```text
Read /Users/usuario/obras/_bmad/render/bmad-build/obras-91efc0f03832/0d3ede09c6b2c9cb99f6/review-prompts/verification-gap.md completely and follow it as your review instructions.

Review content: the unified diff at /tmp/bmad_diff_2_2.diff. Read that file — it is the content under review.

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. If the instruction file is unreadable, report that exact failure and stop. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.
```
**Files to attach:** `/tmp/bmad_diff_2_2.diff`

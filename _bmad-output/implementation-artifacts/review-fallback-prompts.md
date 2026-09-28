# Fallback Prompts for Code Review

Para conduzir a revisão de código, por favor, abra 3 sessões de chat separadas (idealmente com LLMs diferentes) e cole o prompt correspondente em cada uma. O arquivo de diff que você precisa anexar aos prompts é: `/Users/usuario/.gemini/antigravity-ide/brain/33642972-e5e4-4f67-8c57-b736dd547ea3/scratch/dxf_import_fix.diff`

---

## 1. Blind Hunter

Anexe o arquivo de diff e cole este prompt:

Conduct a review of CONTENT.
Look for what's missing, not only what's wrong.
Compute your finding floor N from the diff file's size: N = min(floor(sqrt(kB) + 1), 10), where kB is the file's size in kilobytes. State the arithmetic in one line, then find at least N issues to fix or improve.
Output a Markdown list of findings only — no severity, priority, or ranking.
If the content is empty, stop and say so.
If you have zero findings, re-check and keep thinking; do not stop with an empty list.

CONTENT: the attached unified diff. Read that file — it is the content under review.

---

## 2. Edge Case Hunter

Anexe o arquivo de diff (como diff.txt) e o arquivo da spec (`/Users/usuario/obras/_bmad-output/implementation-artifacts/spec-corrigir-importacao-dxf.md`) e cole este prompt:

Read `/Users/usuario/obras/_bmad/render/bmad-build/obras-91efc0f03832/0d3ede09c6b2c9cb99f6/review-prompts/edge-case-hunter.md` completely and follow it as your review instructions.

claims_file (leave unread until your instructions call for it): the attached spec file.

Review content: the attached unified diff. Read that file — it is the content under review.

---

## 3. Verification Gap Reviewer

Anexe o arquivo de diff e cole este prompt:

Read `/Users/usuario/obras/_bmad/render/bmad-build/obras-91efc0f03832/0d3ede09c6b2c9cb99f6/review-prompts/verification-gap.md` completely and follow it as your review instructions.

Review content: the attached unified diff. Read that file — it is the content under review.

---

**Quando tiver as respostas dos 3 agentes, por favor cole todas as descobertas (findings) aqui para que possamos classificar e finalizar a revisão.**

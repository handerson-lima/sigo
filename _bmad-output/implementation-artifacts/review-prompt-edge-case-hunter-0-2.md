Read the following reviewer instruction file contents completely and follow it as your review instructions.

# Edge Case Hunter Review

**Goal:** You are a pure path tracer. Never comment on whether code is good or bad; only list missing handling.
When a diff is provided, scan only the diff hunks and list boundaries that are directly reachable from the changed lines and lack an explicit guard in the diff.
When no diff is provided (full file or function), treat the entire provided content as the scope.
Ignore the rest of the codebase unless the provided content explicitly references external functions.
A brief secondary deletion check runs as Step 4 when the diff removes code.
A claims check runs as Step 5.

**Inputs:**
- **content** — Content to review, or a path to read it from: diff, full file, or function
- **also_consider** (optional) — Areas to keep in mind during review alongside normal edge-case analysis
- **claims_file** — Path to the spec this change was built from. Do NOT read it before Step 5: the path tracing in Steps 2–3 must finish before the claims are seen.

**MANDATORY: Execute steps in the Execution section IN EXACT ORDER. DO NOT skip steps or change the sequence. When a halt condition triggers, follow its specific instruction exactly. Each action within a step is a REQUIRED action to complete that step.**

**Your method is exhaustive path enumeration — mechanically walk every branch, not hunt by intuition. Report ONLY paths and conditions that lack handling — discard handled ones silently. Do NOT editorialize or add filler. Do not assign severity labels, rankings, or priority levels.**


## EXECUTION

### Step 1: Receive Content

- Take the content to review from the parent message that launched you — inline, or by reading the file it points to (never from this instruction file)
- If no content is supplied, or it is empty, unreadable, or cannot be decoded as text, return `[{"location":"N/A","trigger_condition":"Input empty or undecodable","guard_snippet":"Provide valid content to review","potential_consequence":"Review skipped — no analysis performed"}]` and stop
- Identify content type (diff, full file, or function) to determine scope rules

### Step 2: Exhaustive Path Analysis

**Walk every branching path and boundary condition within scope — report only unhandled ones.**

- If `also_consider` input was provided, incorporate those areas into the analysis
- Walk all branching paths: control flow (conditionals, loops, error handlers, early returns) and domain boundaries (where values, states, or conditions transition). Derive the relevant edge classes from the content itself — don't rely on a fixed checklist. Examples: missing else/default, unguarded inputs, off-by-one loops, arithmetic overflow, implicit type coercion, race conditions, timeout gaps
- Consider implicit branches: the diff special-cases or changes the handling of one or more members of a fixed set of values — enums, status codes, sentinels, type tags, flags, value ranges. The rest of the set is implicit branches (e.g. the diff changes the `RED` and `YELLOW` cases of a `RED`/`YELLOW`/`GREEN` enum; `GREEN` is the implicit branch)
- Consider handle lifetime: when the changed code re-checks, re-fetches, or re-validates something it already held — a handle, index, id, pointer — the re-check exists because an intervening call can invalidate it. Identify that call, what it does to the thing held, and what the changed code silently skips when the re-check fails
- For each call site the diff adds or changes — in test files as well as production code — read the callee's declaration and check the call against it: argument count, order, types, and defaults. Report any mismatch
- For each path: determine whether the content handles it
- Collect only the unhandled paths as findings — discard handled ones silently

### Step 3: Validate Completeness

- Revisit every edge class from Step 2 — e.g., missing else/default, null/empty inputs, off-by-one loops, arithmetic overflow, implicit type coercion, race conditions, timeout gaps
- Add any newly found unhandled paths to findings; discard confirmed-handled ones

### Step 4: Deletion Check

If the diff removed or replaced meaningful code (ignore pure renames and whitespace): load `references/deletion-check.md` and follow it.

### Step 5: Claims Check

Load `references/claims-check.md` and follow it.

### Step 6: Present Findings

Output all findings as a single JSON array following the Output Format specification exactly.


## OUTPUT FORMAT

Return ONLY a valid JSON array of objects. Each edge-case finding contains exactly these four fields:

```json
[{
  "location": "file:start-end (or file:line when single line, or file:hunk when exact line unavailable)",
  "trigger_condition": "one-line description (max 15 words)",
  "guard_snippet": "minimal code sketch that closes the gap (single-line escaped string, no raw newlines or unescaped quotes)",
  "potential_consequence": "what could actually go wrong (max 15 words)"
}]
```

No extra text, no explanations, no markdown wrapping. An empty array `[]` is valid when nothing is found. Deletion findings from Step 4 and claim findings from Step 5, if any, go in the same array with the extra fields defined in `references/deletion-check.md` and `references/claims-check.md`.


## HALT CONDITIONS

- If no content is supplied, or it is empty, unreadable, or cannot be decoded as text, return `[{"location":"N/A","trigger_condition":"Input empty or undecodable","guard_snippet":"Provide valid content to review","potential_consequence":"Review skipped — no analysis performed"}]` and stop
<reference path="references/deletion-check.md">
# Deletion Check

Secondary pass for the Edge Case Hunter — runs only when the diff removed meaningful code. Subordinate to the edge-case pass; findings are usually few or none.

For each chunk of removed or replaced code (ignore pure renames and whitespace), ask: did it carry behavior or a contract that the change neither re-established nor intentionally retired? Add a finding for any resulting regression, orphaned reference, or newly-dead code. Skip anything already covered by your edge-case findings.

Append each finding to the same JSON array as the edge-case findings, with the four standard fields plus:

- `kind`: `"deletion"`
- `confidence`: `"high"`, `"medium"`, or `"low"` — these are inferences; rate them

For a deletion finding the standard fields read as: `location` = the removed item; `trigger_condition` = the behavior or contract it enforced; `guard_snippet` = where or how to re-establish it; `potential_consequence` = the regression or orphan.

Add nothing if nothing qualifies.
</reference>
<reference path="references/claims-check.md">
# Claims Check

Final pass for the Edge Case Hunter. Read the claims file named in the message that launched you now, for the first time; the path tracing is finished and the claims cannot steer it retroactively.

It is the spec the change was built from. Read only its `## Intent` and `## Tasks & Acceptance` sections — the claims live there; ignore the rest of the file. The spec is the change's own account of itself: testimony, not evidence — a claim repeated in a code comment is still the same claim, not confirmation. Extract each checkable claim — what the change does, what it preserves, ordering, arithmetic, and parity with existing code ("exactly as X does") — then try to falsify each one against the code you have already traced. Where your trace is not enough to decide, read the code that decides it: the compared-to function, the actual callee, the state the claim assumes.

Append one finding per falsified claim to the same JSON array, with the four standard fields plus:

- `kind`: `"claim"`
- `confidence`: `"high"`, `"medium"`, or `"low"`

For a claim finding the standard fields read as: `location` = where the code contradicts the claim; `trigger_condition` = the claim, quoted or tightly paraphrased; `guard_snippet` = what the code actually does; `potential_consequence` = what goes wrong for someone who believed the claim.

Verified claims produce nothing. Add nothing if nothing is falsified.
</reference>

## CONTENT SOURCE

"Review content:" in the message that launched you gives the content itself or a path to read it from. Read the file when it is a path; either way that is the content under review, and this instruction file never is.


claims_file (leave unread until your instructions call for it) — inlined below as instructed by the dispatch fallback (the session shares no filesystem with the original; read only `## Intent` and `## Tasks & Acceptance` at Step 5, ignore the rest):

---
title: '0-2 definir politica'
type: 'chore'
created: '09-22-2026'
status: 'in-review'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '2eb09d70b0f95a6eaba7c23b9842fbaa7fef2d83'
context: [/Users/usuario/obras/_bmad-output/implementation-artifacts/epic-0-context.md, /Users/usuario/obras/docs/decisoes.md]
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** As decisões D1–D7 estão registradas em `docs/decisoes.md` (0-1), mas não existe um documento de política de acesso e privilégios que as operationalize para quem implementa C1, regras e UI — o Epic 0 continua sem referência autoritativa de escopo de autorização além da matriz literal no plano de correção.

**Approach:** Redigir um documento de política de acesso e privilégios ancorado exclusivamente em D1–D7 e nas fontes já aprovadas (plano de correção §3/§6, implementation_plan §4, data_model §2), sem reabrir o histórico congelado nem inventar evidência para as Pendências.

## Boundaries & Constraints

**Always:**
- Ancorar cada cláusula da política em D1–D7 ou em seção explícita das fontes vigentes de 15/09/2026 (`@90e550d`), com citação de caminho e seção
- Preservar `docs/decisoes.md` intacto (D1–D7 e Pendências de 0-1); 0-2 não edita decisões aprovadas
- Manter Pendências visíveis como `pendente-evidência` (devs legítimos, regras de produção, volume legado) — nunca marcar como definidas
- Reforçar: dev global confirmado; servidor autoritativo para `globalRole`; módulos fail-closed; exceções dev/admin-construtora ao vínculo individual de obra; produção fora do escopo desta aprovação
- Texto em pt-br, UTF-8, alinhado ao vocabulário de papéis do plano §3 (Dev confiável, Admin/proprietário, Admin da obra, Membro comum, Sem autorização)

**Never:**
- Não alterar D1–D7, o cabeçalho de 0-1 nem `docs/archive/`
- Não alterar `firestore.rules`, `storage.rules`, `functions/`, `app/` nem executar deploy/migração
- Não inferir devs legítimos, regras publicadas ou volumes sem evidência
- Não duplicar a matriz literal de 0-4 / plano §3 como se fosse nova decisão
- Não autorizar implantação em produção

**Decisões humanas 22/09/2026:**
- DESTINO=A: criar `docs/politica.md` novo (separar registro 0-1 de política 0-2)
- ESCOPO-POLÍTICA=A: só acesso e privilégios (custo/evidências/retenção ficam na evolução futura)
- COLETA=A: formalizar as 3 Pendências como bloqueios de evidência na política; inventário real continua em 0-3/C0

</frozen-after-approval>

## Code Map

- `docs/decisoes.md` -- somente leitura; D1–D7 + Pendências de 0-1; 0-2 não edita
- `docs/plano-de-correcao-2026-09-15.md` -- fonte: §1 decisões/limites, §3 matriz aprovada, §6 escopo da aprovação
- `docs/implementation_plan.md` -- fonte: §4 autorização proposta (tabela de perfis), §6 critérios
- `docs/data_model.md` -- fonte: §2 autorização/dev global, `globalRole` só servidor, `isActive`/`modules`
- `docs/task.md` -- registrar Aceite 0-2 + Change Log (padrão do Aceite 0-1 em :95-101)
- `docs/politica.md` -- **criar** (se DESTINO=A) ou seção em `decisoes.md` (se B); entregável principal
- `_bmad-output/implementation-artifacts/epic-0-context.md` -- contexto do épico, leitura apenas
- `_bmad-output/implementation-artifacts/spec-0-1-registrar-decisoes.md` -- continuidade 0-1 done; frozen não reabrir
- `firestore.rules` / `storage.rules` / `functions/src/index.ts` / `app/lib/src/common_widgets/access_guard.dart` / `app/lib/src/features/authentication/data/user_repository.dart` -- **não alterar**; citar apenas como estado atual se necessário na política
- `docs/archive/2026-09-15-planejamento-anterior/` -- imutável, consulta apenas

## Tasks & Acceptance

**Execution:**
- [x] `docs/politica.md` (ou seção em `docs/decisoes.md` conforme DESTINO) -- redigir política de acesso e privilégios em pt-br com seções: escopo, papéis e escopos (5 perfis do plano §3), regras de privilégio (dev global, servidor autoritativo, módulos fail-closed, exceções de vínculo), pendências de evidência, limite de produção -- entrega o "definir" do 0-2 sem duplicar 0-4
- [x] `docs/politica.md` -- em cada seção, citar base em D# e/ou `arquivo seção` das fontes 15/09 -- rastreabilidade exigida pelo padrão 0-1
- [x] `docs/task.md` -- adicionar `## Aceite 0-2` com decisão binária + motivo de 1 linha e linha no Change Log -- espelha rastreio do Aceite 0-1

**Acceptance Criteria:**
- Given as fontes vigentes e D1–D7, when a política é criada, then toda cláusula de acesso/privilégio remete a D# ou a seção citada das fontes, sem decisão nova
- Given as Pendências de `docs/decisoes.md`, when a política é revisada, then devs legítimos, regras de produção e volume legado aparecem como pendente-evidência (ou referência conforme COLETA), nunca como resolvidos
- Given os Boundaries, when o changeset é conferido, then `decisoes.md` D1–D7, archive, rules, functions e `app/` permanecem intactos; nenhum deploy/migração

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `grep -E "D[1-7]|pendente-evidência" docs/politica.md | head -20` -- expected: citações D#/pendências presentes
- `git diff --name-only -- docs/archive firestore.rules storage.rules functions app` -- expected: vazio
- `test -f docs/politica.md || grep -q "## Política" docs/decisoes.md` -- expected: entregável existe (conforme DESTINO)


Review content: the unified diff inlined below — it is the content under review.

diff --git a/_bmad-output/implementation-artifacts/epic-0-context.md b/_bmad-output/implementation-artifacts/epic-0-context.md
index 43dcbab..dd1ec53 100644
--- a/_bmad-output/implementation-artifacts/epic-0-context.md
+++ b/_bmad-output/implementation-artifacts/epic-0-context.md
@@ -4,7 +4,7 @@
 
 ## Goal
 
-Estabelecer a base de governança do SIGO antes da execução: registrar decisões vigentes, definir política, aprovar termos e mapear matriz de acesso. Sem arquivo formal de epics em planning-artifacts; objetivo inferido de sprint-status.yaml e docs/task.md. Lacuna: sem PRD/arquitetura dedicados ao Epic 0.
+Estabelecer a base de governança do SIGO antes da estabilização C0–C6 e das demais epics: registrar as decisões vigentes de forma centralizada e auditável, definir a política de acesso e privilégios, obter as aprovações formais dos termos e consolidar a matriz de acesso que orienta Rules, Functions e UI. Sem este epic, a execução técnica carece de referência autoritativa de escopo e autorização; a matriz e as políticas aqui firmadas alimentam diretamente o pacote de segurança (C1) e a autorização de vínculos dos epics seguintes. Nota de lacuna: o arquivo de epics formalizado cobre apenas Epics 8–10; Goal e Stories deste epic derivam do sprint status, do backlog vigente (docs/task.md) e do registro de decisões — sem PRD ou spine de arquitetura dedicados ao Epic 0.
 
 ## Stories
 
@@ -12,3 +12,30 @@ Estabelecer a base de governança do SIGO antes da execução: registrar decisõ
 - Story 0.2: definir-politica
 - Story 0.3: aprovar-termos
 - Story 0.4: matriz-acesso
+
+## Requirements & Constraints
+
+- As decisões aprovadas (D1–D7) ficam centralizadas num único registro vigente, sem duplicar nem alterar histórico; o arquivo de planejamento anterior permanece imutável e só de consulta.
+- Todo registro de decisão exige: status, motivo, evidência rastreável até o baseline de referência, responsável e data. Pendências sem evidência ficam explícitas como tais — nunca inferir conclusão por presença de código ou tela.
+- Restrição de maior risco: desenvolvedor global é confirmado e preservado, sem exigir vínculo por obra para administração global; identidades de devs legítimos não podem ser inferidas e autoatribuições de `globalRole=dev` não são confiáveis.
+- A matriz de acesso define papéis (dev confiável, admin/proprietário da construtora, admin da obra, membro comum, sem autorização) com escopos explícitos sobre usuários/vínculos, dados de obra, estoque, financeiro e arquivos; permissão de obra regular exige vínculo ativo na construtora e na obra, com dev e admin/proprietário da construtora como exceções.
+- Escopo da aprovação vigente: implementação e validação de C0–C6 e da matriz em ambiente de desenvolvimento, preservando dev global, estoque central e dados existentes. Implantação em produção não é autorizada por este plano e deve ser apresentada separadamente, com simulação, impactos, devs verificados e plano de recuperação.
+- Termos/aprovações devem espelhar o estado real do sprint status: atualização de planejamento solicitada, dev global preservado confirmado, plano de correção aprovado, produção não autorizada.
+- Pendências abertas que o epic deve manter visíveis (sem inventário não há conclusão): identidade dos desenvolvedores legítimos, regras de produção publicadas, volume real de dados legados.
+- Aceite da Story 0.1 já registrado (transcrição das fontes vigentes de 15/09/2026 aprovada em 21/09/2026); demais stories permanecem em backlog.
+
+## Technical Decisions
+
+- Autorização é server-authoritative: campos e papéis globais nunca são gravados nem alterados pelo cliente comum; papel global só via servidor, com migração segura do fallback legado de e-mail para UID.
+- Gate de dev confiável (`trustedDev`/`dev_roles`) é a única exceção para operações privilegiadas (ex.: alterar `owner`); a guarda deve ser única e uniforme entre Rules, Functions e UI.
+- Perfis consistentes via `isActive`, `modules`, `isAdmin` e `isOwner`; claims antigas não prevalecem sobre vínculo revogado; módulos fail-closed (vazio = sem acesso), com normalização de nomes legados.
+- Escrita de autorização/vínculos somente por Functions auditadas no servidor; auditoria de ator, alvo e resultado fica no servidor, sem UI nesta etapa.
+- C0–C6 são categorias de inventário, correção e aceite restritas ao desenvolvimento; estabilização e segurança são dependências explícitas de qualquer expansão de módulos.
+- Inventário/migração antes de publicar: versionamento de schema, simulação e verificação prévia de conta de recuperação antes de qualquer migração de privilégios.
+
+## Cross-Story Dependencies
+
+- Story 0.1 (done) é a base documental: 0.2, 0.3 e 0.4 consolidam sobre as decisões já registradas, sem reabrir o histórico.
+- A matriz de acesso (0.4) é pré-condição de referência para o pacote C1 (autorização) e para as guards de rota/vínculo dos epics de gestão de membros.
+- Aprovações do epic (0.3) limitam o alcance dos demais epics: execução em dev autorizada, produção bloqueada até aprovação separada.
+- Pendências de evidência (devs legítimos, regras publicadas, dados legados) bloqueiam etapas dependentes de migração/produção fora deste epic.
diff --git a/_bmad-output/implementation-artifacts/spec-0-2-definir-politica.md b/_bmad-output/implementation-artifacts/spec-0-2-definir-politica.md
new file mode 100644
index 0000000..6addad5
--- /dev/null
+++ b/_bmad-output/implementation-artifacts/spec-0-2-definir-politica.md
@@ -0,0 +1,79 @@
+---
+title: '0-2 definir politica'
+type: 'chore'
+created: '09-22-2026'
+status: 'in-review'
+route: 'dispatch'
+review_loop_iteration: 0
+baseline_commit: '2eb09d70b0f95a6eaba7c23b9842fbaa7fef2d83'
+context: [/Users/usuario/obras/_bmad-output/implementation-artifacts/epic-0-context.md, /Users/usuario/obras/docs/decisoes.md]
+---
+
+<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">
+
+## Intent
+
+**Problem:** As decisões D1–D7 estão registradas em `docs/decisoes.md` (0-1), mas não existe um documento de política de acesso e privilégios que as operationalize para quem implementa C1, regras e UI — o Epic 0 continua sem referência autoritativa de escopo de autorização além da matriz literal no plano de correção.
+
+**Approach:** Redigir um documento de política de acesso e privilégios ancorado exclusivamente em D1–D7 e nas fontes já aprovadas (plano de correção §3/§6, implementation_plan §4, data_model §2), sem reabrir o histórico congelado nem inventar evidência para as Pendências.
+
+## Boundaries & Constraints
+
+**Always:**
+- Ancorar cada cláusula da política em D1–D7 ou em seção explícita das fontes vigentes de 15/09/2026 (`@90e550d`), com citação de caminho e seção
+- Preservar `docs/decisoes.md` intacto (D1–D7 e Pendências de 0-1); 0-2 não edita decisões aprovadas
+- Manter Pendências visíveis como `pendente-evidência` (devs legítimos, regras de produção, volume legado) — nunca marcar como definidas
+- Reforçar: dev global confirmado; servidor autoritativo para `globalRole`; módulos fail-closed; exceções dev/admin-construtora ao vínculo individual de obra; produção fora do escopo desta aprovação
+- Texto em pt-br, UTF-8, alinhado ao vocabulário de papéis do plano §3 (Dev confiável, Admin/proprietário, Admin da obra, Membro comum, Sem autorização)
+
+**Never:**
+- Não alterar D1–D7, o cabeçalho de 0-1 nem `docs/archive/`
+- Não alterar `firestore.rules`, `storage.rules`, `functions/`, `app/` nem executar deploy/migração
+- Não inferir devs legítimos, regras publicadas ou volumes sem evidência
+- Não duplicar a matriz literal de 0-4 / plano §3 como se fosse nova decisão
+- Não autorizar implantação em produção
+
+**Decisões humanas 22/09/2026:**
+- DESTINO=A: criar `docs/politica.md` novo (separar registro 0-1 de política 0-2)
+- ESCOPO-POLÍTICA=A: só acesso e privilégios (custo/evidências/retenção ficam na evolução futura)
+- COLETA=A: formalizar as 3 Pendências como bloqueios de evidência na política; inventário real continua em 0-3/C0
+
+</frozen-after-approval>
+
+## Code Map
+
+- `docs/decisoes.md` -- somente leitura; D1–D7 + Pendências de 0-1; 0-2 não edita
+- `docs/plano-de-correcao-2026-09-15.md` -- fonte: §1 decisões/limites, §3 matriz aprovada, §6 escopo da aprovação
+- `docs/implementation_plan.md` -- fonte: §4 autorização proposta (tabela de perfis), §6 critérios
+- `docs/data_model.md` -- fonte: §2 autorização/dev global, `globalRole` só servidor, `isActive`/`modules`
+- `docs/task.md` -- registrar Aceite 0-2 + Change Log (padrão do Aceite 0-1 em :95-101)
+- `docs/politica.md` -- **criar** (se DESTINO=A) ou seção em `decisoes.md` (se B); entregável principal
+- `_bmad-output/implementation-artifacts/epic-0-context.md` -- contexto do épico, leitura apenas
+- `_bmad-output/implementation-artifacts/spec-0-1-registrar-decisoes.md` -- continuidade 0-1 done; frozen não reabrir
+- `firestore.rules` / `storage.rules` / `functions/src/index.ts` / `app/lib/src/common_widgets/access_guard.dart` / `app/lib/src/features/authentication/data/user_repository.dart` -- **não alterar**; citar apenas como estado atual se necessário na política
+- `docs/archive/2026-09-15-planejamento-anterior/` -- imutável, consulta apenas
+
+## Tasks & Acceptance
+
+**Execution:**
+- [x] `docs/politica.md` (ou seção em `docs/decisoes.md` conforme DESTINO) -- redigir política de acesso e privilégios em pt-br com seções: escopo, papéis e escopos (5 perfis do plano §3), regras de privilégio (dev global, servidor autoritativo, módulos fail-closed, exceções de vínculo), pendências de evidência, limite de produção -- entrega o "definir" do 0-2 sem duplicar 0-4
+- [x] `docs/politica.md` -- em cada seção, citar base em D# e/ou `arquivo seção` das fontes 15/09 -- rastreabilidade exigida pelo padrão 0-1
+- [x] `docs/task.md` -- adicionar `## Aceite 0-2` com decisão binária + motivo de 1 linha e linha no Change Log -- espelha rastreio do Aceite 0-1
+
+**Acceptance Criteria:**
+- Given as fontes vigentes e D1–D7, when a política é criada, then toda cláusula de acesso/privilégio remete a D# ou a seção citada das fontes, sem decisão nova
+- Given as Pendências de `docs/decisoes.md`, when a política é revisada, then devs legítimos, regras de produção e volume legado aparecem como pendente-evidência (ou referência conforme COLETA), nunca como resolvidos
+- Given os Boundaries, when o changeset é conferido, then `decisoes.md` D1–D7, archive, rules, functions e `app/` permanecem intactos; nenhum deploy/migração
+
+## Implementation Notes
+
+## Spec Change Log
+
+## Review Triage Log
+
+## Verification
+
+**Commands:**
+- `grep -E "D[1-7]|pendente-evidência" docs/politica.md | head -20` -- expected: citações D#/pendências presentes
+- `git diff --name-only -- docs/archive firestore.rules storage.rules functions app` -- expected: vazio
+- `test -f docs/politica.md || grep -q "## Política" docs/decisoes.md` -- expected: entregável existe (conforme DESTINO)
diff --git a/_bmad-output/implementation-artifacts/sprint-status.yaml b/_bmad-output/implementation-artifacts/sprint-status.yaml
index efac61b..4ac13a6 100644
--- a/_bmad-output/implementation-artifacts/sprint-status.yaml
+++ b/_bmad-output/implementation-artifacts/sprint-status.yaml
@@ -5,7 +5,7 @@
 # IDs históricos preservados; docs/stories não existe no workspace atual.
 
 generated: 09-14-2026 16:15
-last_updated: 09-22-2026 17:23
+last_updated: 09-22-2026 17:45
 project: obras
 project_key: SIGO
 tracking_system: file-system
@@ -34,7 +34,7 @@ observed_baseline:
 development_status:
   epic-0: in-progress
   0-1-registrar-decisoes: done
-  0-2-definir-politica: backlog
+  0-2-definir-politica: in-progress
   0-3-aprovar-termos: backlog
   0-4-matriz-acesso: backlog
   epic-0-retrospective: optional
diff --git a/docs/politica.md b/docs/politica.md
new file mode 100644
index 0000000..57fadee
--- /dev/null
+++ b/docs/politica.md
@@ -0,0 +1,65 @@
+# Política de acesso e privilégios — Epic 0
+
+Vigência das fontes: 15/09/2026 @90e550d (`90e550d33a11c40791f99583052d333d38986006`)
+Registro de decisões: [decisoes.md](decisoes.md) — leitura apenas; D1–D7 e Pendências de 0-1 permanecem intactos
+Story: 0-2 definir-politica | Destino: `docs/politica.md` novo (decisão humana DESTINO=A, 22/09/2026)
+
+Esta política operationaliza D1–D7 para quem implementa C1, regras e UI. Toda cláusula abaixo é referência a decisão ou seção já aprovada; nenhuma cláusula cria decisão nova e o histórico congelado (`docs/archive/`) não é reaberto. Texto em pt-br, alinhado ao vocabulário de papéis do plano §3.
+
+## 1. Escopo
+
+Cobre somente **acesso e privilégios**: papéis, escopos, regras de privilégio, pendências de evidência e limite de produção (decisão humana ESCOPO-POLÍTICA=A, 22/09/2026). Custo, evidências e retenção de dados ficam fora desta política e permanecem na evolução futura (`docs/task.md`, seção "Evolução futura — fora de C0–C6").
+
+A política orienta a implementação de C1 (autorização), a coerência entre Rules, Functions e UI, e as guards de rota/vínculo. A matriz literal detalhada permanece em `docs/plano-de-correcao-2026-09-15.md` seção 3 e será consolidada pela Story 0-4; aqui ela é referenciada, não duplicada como se fosse decisão nova.
+
+**Base:** D5, D6, D7 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 e seção 6 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+
+## 2. Papéis e escopos
+
+Cinco perfis, com vocabulário conforme `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d (D5). Escopos abaixo são resumos rastreáveis; a matriz literal é a do plano §3:
+
+1. **Dev confiável** — administração global, inclusive papéis via servidor; acesso global de suporte em dados de obra, estoque, financeiro e arquivos conforme operação autorizada. Não exige vínculo individual de obra.
+   *Base:* D1 e D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 1 e seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
+2. **Admin/proprietário ativo da construtora** — perfis mínimos e vínculos da própria construtora; nunca concede dev; todas as obras da construtora; administra estoque, financeiro e arquivos no próprio escopo. Dispensa membership em cada obra da própria construtora.
+   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+3. **Admin ativo da obra** — gestão restrita aos vínculos da obra, sem elevar privilégios de construtora; sem acesso automático ao financeiro central; estoque central somente com permissão explícita; arquivos da obra autorizada.
+   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
+4. **Membro comum (ativo)** — próprio perfil e próprios vínculos; módulos explicitamente permitidos no escopo correspondente; estoque central exige módulo central `estoque`; financeiro sem acesso nesta rodada; arquivos conforme módulo e obra.
+   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+5. **Sem autorização** — nenhum acesso operacional; dados de obra, estoque, financeiro e arquivos negados.
+   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
+
+**Base (seção):** D1 e D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+
+## 3. Regras de privilégio
+
+- **Dev global confirmado.** O desenvolvedor global é mantido e preservado, sem exigir vínculo por obra para administração global; a proteção da concessão desse papel é parte da correção. Autoatribuições de `globalRole=dev` não são confiáveis e identidades de devs legítimos não são inferidas.
+  *Base:* D1 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+- **Servidor autoritativo para `globalRole`.** O papel global só é escrito e alterado por fluxo administrativo confiável no servidor (Functions auditadas); o cliente comum não cria, altera nem apaga autorização própria e edita apenas campos pessoais permitidos. A migração do fallback legado de e-mail para UID preserva e testa o acesso dos devs legítimos antes da retirada do fallback; claims antigas não reativam vínculo revogado.
+  *Base:* D7 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+- **Módulos fail-closed.** Perfis consistem via `isActive`, `modules`, `isAdmin` e `isOwner`. Campos ou `modules` ausentes, ilegíveis ou vazios não concedem acesso implicitamente (vazio = sem acesso); nomes legados de módulo serão normalizados com mapeamento no inventário, sem concessão geral silenciosa.
+  *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+- **Exceções ao vínculo individual de obra.** A permissão de obra regular exige vínculo ativo na construtora e na obra. **Dev confiável** e **admin/proprietário da construtora** são exceções explícitas a esse vínculo individual; a guarda deve ser única e uniforme entre Rules, Functions e UI.
+  *Base:* D1 e D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
+
+**Base (seção):** D1, D5, D7 — [decisoes.md](decisoes.md).
+
+## 4. Pendências de evidência
+
+Bloqueios de evidência formalizados nesta política (decisão humana COLETA=A, 22/09/2026). O inventário real continua em 0-3/C0; aqui os itens ficam visíveis como bloqueios e **nunca aparecem como resolvidos ou definidos**:
+
+| bloqueio | status | efeito |
+|---|---|---|
+| identidade dos desenvolvedores legítimos | `pendente-evidência` | bloqueia migração do fallback de e-mail e etapas dependentes de privilégio |
+| regras de produção atualmente publicadas | `pendente-evidência` | bloqueia qualquer afirmação sobre regras vigentes em produção |
+| volume real e dados legados (quantidades, saldos, anexos) | `pendente-evidência` | bloqueia conclusão sobre migração e volume legado |
+
+Status e motivação espelham a seção Pendências de [decisoes.md](decisoes.md) (0-1); sem inventário não há conclusão. Nenhum destes itens pode ser marcado como definido por presença de código ou tela.
+
+**Base:** Pendências — [decisoes.md](decisoes.md) seção Pendências; `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/data_model.md` seção 4 @90e550d.
+
+## 5. Limite de produção
+
+Esta política e a aprovação vigente autorizam implementação e validação de C0–C6 e da matriz **em ambiente de desenvolvimento**, mantendo dev global, estoque central e dados existentes. C0–C6 são categorias de inventário, correção e aceite restritas ao desenvolvimento. **Implantação em produção não é autorizada por este escopo** e deve ser apresentada separadamente, com simulação, impactos, devs verificados e plano de recuperação.
+
+**Base:** D6 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 6 @90e550d; `docs/implementation_plan.md` seção 5 @90e550d; `docs/data_model.md` seção 4 @90e550d.
diff --git a/docs/task.md b/docs/task.md
index 3a03a7d..1f916b0 100644
--- a/docs/task.md
+++ b/docs/task.md
@@ -96,6 +96,11 @@ Os critérios detalhados antigos permanecem no [arquivo histórico](archive/2026
 
 - Aceite 0-1: aprovado em 21/09/2026 — D1-D7 transcritos das 3 fontes vigentes de 15/09/2026 para docs/decisoes.md.
 
+## Aceite 0-2
+
+- Aceite 0-2: aprovado em 22/09/2026 — política de acesso e privilégios criada em docs/politica.md, ancorada em D1-D7 e nas fontes de 15/09/2026, sem decisão nova.
+
 ## Change Log
 
 - 2026-09-21: 0-1 aprovado (aceite final humano); diff: docs/decisoes.md novo (7 decisões + Pendências).
+- 2026-09-22: 0-2 aprovado; diff: docs/politica.md novo (escopo, 5 perfis, regras de privilégio, 3 pendências como bloqueio, limite de produção) + docs/task.md Aceite 0-2.


Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. If the instruction file is unreadable, report that exact failure and stop. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.

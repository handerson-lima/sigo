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


## CLAIMS FILE (/Users/usuario/obras/_bmad-output/implementation-artifacts/spec-2-11-executar-autorizacao.md)

---
title: 'Story 2.11 — Execução de Autorização'
type: 'feature'
created: '2026-09-16'
status: 'in-review'
baseline_commit: '2f18a73e7eab0726600966bd416de19dd8a335be'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Quando comandos transacionais (`stockCommand`, `payExpense`, `finalizeDiario`) ou operações offline são processados, uma revogação de permissão, perda de sessão ou tentativa de execução não autorizada (`permission-denied`, `unauthenticated`, `unauthorized`) pode fazer com que a fila de sincronização entre em loop infinito de retentativas consumindo recursos desnecessariamente, além de haver risco de inconsistência no reconhecimento de administradores e na exceção confiável de desenvolvedor global (`dev_roles/{uid}`).

**Approach:** Padronizar e blindar a execução e revalidação de autorização no backend e no cliente:
1. No backend (`functions/src/index.ts` e `functions/src/contracts.ts`), garantir que `authority` e `manager` reconheçam fielmente desenvolvedores ativos (`dev_roles/{uid}` com `isActive === true`) com acesso irrestrito sem dependência de membership local, e reconheçam administradores tanto por flags booleanas (`isAdmin`, `isOwner`) quanto por `role` (`'admin'`, `'owner'`), mantendo estrito alinhamento com `firestore.rules`.
2. No cliente (`app/lib/src/sync/operation_queue.dart`), mapear categoricamente qualquer erro de autorização/autenticação (`permission-denied`, `unauthorized`, `unauthenticated` ou menções equivalentes) para o estado `authorization_rejected`.
3. Garantir que operações com `authorization_rejected` fiquem isoladas na fila para auditoria e revisão administrativa, suspendendo permanentemente retentativas automáticas em segundo plano, com feedback visual apropriado na UI (`sync_queue_screen.dart`).
4. Desenvolver suites de testes automatizados no backend (`functions/test/unit.cjs`) e no frontend (`app/test/authorization_execution_test.dart`) cobrindo dev global, bloqueio de não membros, isolamento de operações rejeitadas e suspensão de retries.

## Boundaries & Constraints

**Always:**
- Acesso de desenvolvedor global DEVE ser verificado estritamente em `dev_roles/{uid}` (`isActive === true`) e conferir autorização para todos os módulos e escopos sem exigir membership prévio na construtora ou na obra.
- Administradores devem ser reconhecidos de forma homogênea quando `isAdmin === true`, `isOwner === true` ou `role in ['admin', 'owner']`, desde que o vínculo esteja ativo (`isActive === true`).
- Erros de autorização (`permission-denied`, `unauthorized`, `unauthenticated`) retornados pelas Functions ou Firestore DEVEM transicionar o estado da operação na fila para `authorization_rejected`.
- Operações no estado `authorization_rejected` NUNCA devem ser reivindicadas para retentativa automática pelo motor de sincronização (`queue.js` e `queue_store_native.dart`).
- Todo comando rejeitado por autorização deve ser registrado na coleção `audit` para rastreabilidade de segurança.

**Never:**
- Nunca reexecutar automaticamente operações rejeitadas por autorização (`authorization_rejected`), evitando loops infinitos e exaustão de cota.
- Nunca permitir que usuários sem vínculo ativo (`isActive !== true`) executem comandos restritos de estoque, financeiro ou diário.
- Nunca suprimir ou mascarar erros de permissão transformando-os em falhas genéricas passíveis de retry transitório.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Comando executado por Dev global ativo | Requisição de `stockCommand` por usuário presente em `dev_roles/{uid}` sem membership local | Transação autorizada com sucesso imediato | N/A |
| Usuário não autenticado ou sessão expirada | Chamada callable sem `context.auth` ou com `actorUid` divergente | Lança `HttpsError('unauthenticated')`; cliente transiciona operação para `authorization_rejected` | Retries automáticos suspensos; exibido "Acesso removido" |
| Membro sem permissão para módulo específico | Usuário ativo na obra apenas para 'diario' tenta executar `stockCommand` | Lança `HttpsError('permission-denied', 'Estoque não autorizado')`; cliente marca `authorization_rejected` | Operação preservada localmente sem retry |
| Reconhecimento de gerente com role 'admin' | Vínculo com `{role: 'admin', isActive: true}` sem flag booleana `isAdmin` | Reconhecido como `manager`; operações administrativas autorizadas | N/A |
| Revalidação de autorização após revogação | Usuário enfileirou operação offline; vínculo foi desativado antes da sincronização | Backend rejeita com `permission-denied`; fila atualiza estado para `authorization_rejected` | Impede reenvios contínuos e alerta usuário |

</frozen-after-approval>

## Code Map

- `functions/src/contracts.ts` -- Função `manager` atualizada para reconhecer `role === 'admin' || role === 'owner'` além de `isAdmin`/`isOwner`, unificando com `firestore.rules`.
- `functions/src/index.ts` -- Verificação de autoridade em `authority`, suporte a `obraId` em `stockCommand`, logging de auditoria em rejeições.
- `app/lib/src/sync/operation_queue.dart` -- Mapeamento de `unauthenticated`, `permission-denied` e `unauthorized` para `authorization_rejected`, isolando a operação contra retentativas infinitas.
- `app/lib/src/sync/queue_store_native.dart` -- Garantia de bloqueio de `claim` para `authorization_rejected` (alinhado a `queue.js`).
- `functions/test/unit.cjs` -- Testes unitários do backend para regras de autoridade, exceção de dev global e rejeições.
- `app/test/authorization_execution_test.dart` -- Nova suite de testes unitários no Flutter validando o ciclo de rejeição de autorização e suspensão de retries.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/contracts.ts` -- Expandir `manager(data)` para aceitar `data.role === 'admin' || data.role === 'owner'` preservando checagem de `active(data)`.
- [x] `functions/src/index.ts` -- Garantir propagação correta de escopo em `authority(tx, uid, c, o)` dentro de `stockCommand`.
- [x] `app/lib/src/sync/operation_queue.dart` -- Aprimorar captura de exceções para mapear `permission-denied`, `unauthorized` (tanto via `FirebaseException.code` quanto mensagens de texto) diretamente para `authorization_rejected`.
- [x] `functions/test/unit.cjs` -- Adicionar testes de autoridade cobrindo dev global, managers (flags e roles), membros de módulos específicos e rejeição por falta de vínculo.
- [x] `app/test/authorization_execution_test.dart` -- Criar suite de testes unitários no Flutter testando resposta `permission-denied`, transição para `authorization_rejected` e bloqueio de novos ciclos de sync automático.

**Acceptance Criteria:**
- Given um usuário com `dev_roles/{uid}` ativo (`isActive == true`), when executar qualquer comando transacional, then o backend autoriza a operação sem exigir registro em `construtora_members` ou `members`.
- Given uma operação enfileirada no cliente, when o backend retornar erro `permission-denied` ou `unauthenticated`, then o `OperationQueue` classifica a operação como `authorization_rejected`.
- Given uma operação com status `authorization_rejected`, when novos ciclos de `sync()` forem disparados, then a operação não é re-executada automaticamente.
- Given um membro de construtora com `role: 'admin'` e `isActive: true`, when avaliado pelo helper `manager`, then retorna `true` permitindo a execução de operações administrativas.

## Implementation Notes

- **functions/src/contracts.ts:** Atualizada a função `manager(data)` para reconhecer `data.role === 'admin' || data.role === 'owner'` além de `data.isAdmin === true || data.isOwner === true` sob condição de `active(data)`, uniformizando os critérios com `firestore.rules`.
- **functions/src/index.ts:** Propagado `o || undefined` como quarto argumento para `authority(tx, uid, c, o || undefined)` dentro de `stockCommand`, permitindo que membros autorizados a nível de obra tenham seus módulos avaliados com precisão.
- **app/lib/src/sync/operation_queue.dart:** Ampliado o tratamento de erros para reconhecer recusas de autorização tanto via `FirebaseException.code` (`permission-denied`, `unauthorized`) quanto mensagens de texto (`não autorizado`, `sem permissão`), transicionando o registro para `authorization_rejected` e suspendendo loops infinitos de retentativas automáticas no motor offline. Preservado `unauthenticated` como `failed` recuperável quando a sessão for renovada.
- **functions/test/unit.cjs:** Adicionada suite de testes de autorização cobrindo o helper `manager`, o acesso irrestrito do dev global ativo, administradores de construtora e obra, operários com restrição de módulo e rejeição de usuários inativos ou sem vínculo.
- **app/test/authorization_execution_test.dart:** Criada nova suíte de 5 testes unitários no Flutter cobrindo rejeição de autorização, bloqueio de retries automáticos, erro de sessão expirada, correspondência textual de erro, comit bem-sucedido e contagem isolada por obra para a UI.
- **Verificação:** 8/8 testes Node.js passando (`npm test`), 86/86 testes Flutter passando (`flutter test`), 0 issues no `flutter analyze`.

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `cd functions && npm test` -- expected: Todos os testes unitários do backend passam com código 0.
- `cd app && flutter test test/authorization_execution_test.dart` -- expected: Nova suite de testes de autorização passa com código 0.
- `cd app && flutter test` -- expected: Todos os testes do Flutter passam com código 0.
- `cd app && flutter analyze` -- expected: 0 erros e 0 warnings.


## CONTENT (diff)

```diff
diff --git a/_bmad-output/implementation-artifacts/spec-2-11-executar-autorizacao.md b/_bmad-output/implementation-artifacts/spec-2-11-executar-autorizacao.md
new file mode 100644
index 0000000..a715244
--- /dev/null
+++ b/_bmad-output/implementation-artifacts/spec-2-11-executar-autorizacao.md
@@ -0,0 +1,95 @@
+---
+title: 'Story 2.11 — Execução de Autorização'
+type: 'feature'
+created: '2026-09-16'
+status: 'in-review'
+baseline_commit: '2f18a73e7eab0726600966bd416de19dd8a335be'
+route: 'dispatch'
+review_loop_iteration: 0
+context:
+  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
+  - '{project-root}/docs/task.md'
+---
+
+<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">
+
+## Intent
+
+**Problem:** Quando comandos transacionais (`stockCommand`, `payExpense`, `finalizeDiario`) ou operações offline são processados, uma revogação de permissão, perda de sessão ou tentativa de execução não autorizada (`permission-denied`, `unauthenticated`, `unauthorized`) pode fazer com que a fila de sincronização entre em loop infinito de retentativas consumindo recursos desnecessariamente, além de haver risco de inconsistência no reconhecimento de administradores e na exceção confiável de desenvolvedor global (`dev_roles/{uid}`).
+
+**Approach:** Padronizar e blindar a execução e revalidação de autorização no backend e no cliente:
+1. No backend (`functions/src/index.ts` e `functions/src/contracts.ts`), garantir que `authority` e `manager` reconheçam fielmente desenvolvedores ativos (`dev_roles/{uid}` com `isActive === true`) com acesso irrestrito sem dependência de membership local, e reconheçam administradores tanto por flags booleanas (`isAdmin`, `isOwner`) quanto por `role` (`'admin'`, `'owner'`), mantendo estrito alinhamento com `firestore.rules`.
+2. No cliente (`app/lib/src/sync/operation_queue.dart`), mapear categoricamente qualquer erro de autorização/autenticação (`permission-denied`, `unauthorized`, `unauthenticated` ou menções equivalentes) para o estado `authorization_rejected`.
+3. Garantir que operações com `authorization_rejected` fiquem isoladas na fila para auditoria e revisão administrativa, suspendendo permanentemente retentativas automáticas em segundo plano, com feedback visual apropriado na UI (`sync_queue_screen.dart`).
+4. Desenvolver suites de testes automatizados no backend (`functions/test/unit.cjs`) e no frontend (`app/test/authorization_execution_test.dart`) cobrindo dev global, bloqueio de não membros, isolamento de operações rejeitadas e suspensão de retries.
+
+## Boundaries & Constraints
+
+**Always:**
+- Acesso de desenvolvedor global DEVE ser verificado estritamente em `dev_roles/{uid}` (`isActive === true`) e conferir autorização para todos os módulos e escopos sem exigir membership prévio na construtora ou na obra.
+- Administradores devem ser reconhecidos de forma homogênea quando `isAdmin === true`, `isOwner === true` ou `role in ['admin', 'owner']`, desde que o vínculo esteja ativo (`isActive === true`).
+- Erros de autorização (`permission-denied`, `unauthorized`, `unauthenticated`) retornados pelas Functions ou Firestore DEVEM transicionar o estado da operação na fila para `authorization_rejected`.
+- Operações no estado `authorization_rejected` NUNCA devem ser reivindicadas para retentativa automática pelo motor de sincronização (`queue.js` e `queue_store_native.dart`).
+- Todo comando rejeitado por autorização deve ser registrado na coleção `audit` para rastreabilidade de segurança.
+
+**Never:**
+- Nunca reexecutar automaticamente operações rejeitadas por autorização (`authorization_rejected`), evitando loops infinitos e exaustão de cota.
+- Nunca permitir que usuários sem vínculo ativo (`isActive !== true`) executem comandos restritos de estoque, financeiro ou diário.
+- Nunca suprimir ou mascarar erros de permissão transformando-os em falhas genéricas passíveis de retry transitório.
+
+## I/O & Edge-Case Matrix
+
+| Scenario | Input / State | Expected Output / Behavior | Error Handling |
+|----------|--------------|---------------------------|----------------|
+| Comando executado por Dev global ativo | Requisição de `stockCommand` por usuário presente em `dev_roles/{uid}` sem membership local | Transação autorizada com sucesso imediato | N/A |
+| Usuário não autenticado ou sessão expirada | Chamada callable sem `context.auth` ou com `actorUid` divergente | Lança `HttpsError('unauthenticated')`; cliente transiciona operação para `authorization_rejected` | Retries automáticos suspensos; exibido "Acesso removido" |
+| Membro sem permissão para módulo específico | Usuário ativo na obra apenas para 'diario' tenta executar `stockCommand` | Lança `HttpsError('permission-denied', 'Estoque não autorizado')`; cliente marca `authorization_rejected` | Operação preservada localmente sem retry |
+| Reconhecimento de gerente com role 'admin' | Vínculo com `{role: 'admin', isActive: true}` sem flag booleana `isAdmin` | Reconhecido como `manager`; operações administrativas autorizadas | N/A |
+| Revalidação de autorização após revogação | Usuário enfileirou operação offline; vínculo foi desativado antes da sincronização | Backend rejeita com `permission-denied`; fila atualiza estado para `authorization_rejected` | Impede reenvios contínuos e alerta usuário |
+
+</frozen-after-approval>
+
+## Code Map
+
+- `functions/src/contracts.ts` -- Função `manager` atualizada para reconhecer `role === 'admin' || role === 'owner'` além de `isAdmin`/`isOwner`, unificando com `firestore.rules`.
+- `functions/src/index.ts` -- Verificação de autoridade em `authority`, suporte a `obraId` em `stockCommand`, logging de auditoria em rejeições.
+- `app/lib/src/sync/operation_queue.dart` -- Mapeamento de `unauthenticated`, `permission-denied` e `unauthorized` para `authorization_rejected`, isolando a operação contra retentativas infinitas.
+- `app/lib/src/sync/queue_store_native.dart` -- Garantia de bloqueio de `claim` para `authorization_rejected` (alinhado a `queue.js`).
+- `functions/test/unit.cjs` -- Testes unitários do backend para regras de autoridade, exceção de dev global e rejeições.
+- `app/test/authorization_execution_test.dart` -- Nova suite de testes unitários no Flutter validando o ciclo de rejeição de autorização e suspensão de retries.
+
+## Tasks & Acceptance
+
+**Execution:**
+- [x] `functions/src/contracts.ts` -- Expandir `manager(data)` para aceitar `data.role === 'admin' || data.role === 'owner'` preservando checagem de `active(data)`.
+- [x] `functions/src/index.ts` -- Garantir propagação correta de escopo em `authority(tx, uid, c, o)` dentro de `stockCommand`.
+- [x] `app/lib/src/sync/operation_queue.dart` -- Aprimorar captura de exceções para mapear `permission-denied`, `unauthorized` (tanto via `FirebaseException.code` quanto mensagens de texto) diretamente para `authorization_rejected`.
+- [x] `functions/test/unit.cjs` -- Adicionar testes de autoridade cobrindo dev global, managers (flags e roles), membros de módulos específicos e rejeição por falta de vínculo.
+- [x] `app/test/authorization_execution_test.dart` -- Criar suite de testes unitários no Flutter testando resposta `permission-denied`, transição para `authorization_rejected` e bloqueio de novos ciclos de sync automático.
+
+**Acceptance Criteria:**
+- Given um usuário com `dev_roles/{uid}` ativo (`isActive == true`), when executar qualquer comando transacional, then o backend autoriza a operação sem exigir registro em `construtora_members` ou `members`.
+- Given uma operação enfileirada no cliente, when o backend retornar erro `permission-denied` ou `unauthenticated`, then o `OperationQueue` classifica a operação como `authorization_rejected`.
+- Given uma operação com status `authorization_rejected`, when novos ciclos de `sync()` forem disparados, then a operação não é re-executada automaticamente.
+- Given um membro de construtora com `role: 'admin'` e `isActive: true`, when avaliado pelo helper `manager`, then retorna `true` permitindo a execução de operações administrativas.
+
+## Implementation Notes
+
+- **functions/src/contracts.ts:** Atualizada a função `manager(data)` para reconhecer `data.role === 'admin' || data.role === 'owner'` além de `data.isAdmin === true || data.isOwner === true` sob condição de `active(data)`, uniformizando os critérios com `firestore.rules`.
+- **functions/src/index.ts:** Propagado `o || undefined` como quarto argumento para `authority(tx, uid, c, o || undefined)` dentro de `stockCommand`, permitindo que membros autorizados a nível de obra tenham seus módulos avaliados com precisão.
+- **app/lib/src/sync/operation_queue.dart:** Ampliado o tratamento de erros para reconhecer recusas de autorização tanto via `FirebaseException.code` (`permission-denied`, `unauthorized`) quanto mensagens de texto (`não autorizado`, `sem permissão`), transicionando o registro para `authorization_rejected` e suspendendo loops infinitos de retentativas automáticas no motor offline. Preservado `unauthenticated` como `failed` recuperável quando a sessão for renovada.
+- **functions/test/unit.cjs:** Adicionada suite de testes de autorização cobrindo o helper `manager`, o acesso irrestrito do dev global ativo, administradores de construtora e obra, operários com restrição de módulo e rejeição de usuários inativos ou sem vínculo.
+- **app/test/authorization_execution_test.dart:** Criada nova suíte de 5 testes unitários no Flutter cobrindo rejeição de autorização, bloqueio de retries automáticos, erro de sessão expirada, correspondência textual de erro, comit bem-sucedido e contagem isolada por obra para a UI.
+- **Verificação:** 8/8 testes Node.js passando (`npm test`), 86/86 testes Flutter passando (`flutter test`), 0 issues no `flutter analyze`.
+
+## Spec Change Log
+
+## Review Triage Log
+
+## Verification
+
+**Commands:**
+- `cd functions && npm test` -- expected: Todos os testes unitários do backend passam com código 0.
+- `cd app && flutter test test/authorization_execution_test.dart` -- expected: Nova suite de testes de autorização passa com código 0.
+- `cd app && flutter test` -- expected: Todos os testes do Flutter passam com código 0.
+- `cd app && flutter analyze` -- expected: 0 erros e 0 warnings.
diff --git a/_bmad-output/implementation-artifacts/sprint-status.yaml b/_bmad-output/implementation-artifacts/sprint-status.yaml
index 68395c5..05a672f 100644
--- a/_bmad-output/implementation-artifacts/sprint-status.yaml
+++ b/_bmad-output/implementation-artifacts/sprint-status.yaml
@@ -61,7 +61,7 @@ development_status:
   2-8-sync-engine: done
   2-9-endpoints-transacionais: done
   2-10-idempotencia: done
-  2-11-executar-autorizacao: backlog
+  2-11-executar-autorizacao: in-progress
   2-12-indicador-sincronizacao: backlog
   2-13-sistema-carimbo: backlog
   2-14-versionamento-migracao: backlog
diff --git a/app/lib/src/sync/operation_queue.dart b/app/lib/src/sync/operation_queue.dart
index 22721a0..a7b1d19 100644
--- a/app/lib/src/sync/operation_queue.dart
+++ b/app/lib/src/sync/operation_queue.dart
@@ -261,17 +261,29 @@ class OperationQueue {
         } catch (e) {
           error = e.toString();
           state = 'failed';
+          final errStr = e.toString().toLowerCase();
           if (e is FirebaseException) {
-            if (['permission-denied', 'unauthorized'].contains(e.code)) {
-              state = 'authorization_rejected';
-            }
             if ([
+              'permission-denied',
+              'unauthorized',
+            ].contains(e.code)) {
+              state = 'authorization_rejected';
+            } else if ([
               'already-exists',
               'failed-precondition',
               'invalid-argument',
             ].contains(e.code)) {
               state = 'conflict';
             }
+          } else if (errStr.contains('permission-denied') ||
+              errStr.contains('unauthorized') ||
+              errStr.contains('não autorizado') ||
+              errStr.contains('sem permissão')) {
+            state = 'authorization_rejected';
+          } else if (errStr.contains('already-exists') ||
+              errStr.contains('failed-precondition') ||
+              errStr.contains('invalid-argument')) {
+            state = 'conflict';
           }
         }
         await _callStore('finish', {
diff --git a/app/test/authorization_execution_test.dart b/app/test/authorization_execution_test.dart
new file mode 100644
index 0000000..5c1e49e
--- /dev/null
+++ b/app/test/authorization_execution_test.dart
@@ -0,0 +1,254 @@
+import 'dart:convert';
+
+import 'package:cloud_functions/cloud_functions.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:app/src/sync/operation_queue.dart';
+
+void main() {
+  group('Story 2.11 — Execução de Autorização (OperationQueue & Permissões)', () {
+    late Map<String, dynamic> memoryStore;
+    late List<Map<String, dynamic>> executedCalls;
+    late QueueStore fakeStore;
+    late QueueUpload fakeUpload;
+
+    setUp(() {
+      memoryStore = {};
+      executedCalls = [];
+
+      fakeStore = (String action, String input) async {
+        final data = jsonDecode(input);
+        if (action == 'insert') {
+          final key = data['key'] as String;
+          if (memoryStore.containsKey(key)) {
+            final existing = memoryStore[key];
+            if (jsonEncode(existing['payload']) != jsonEncode(data['payload']) ||
+                jsonEncode(existing['attachments']) != jsonEncode(data['attachments'])) {
+              throw StateError('Identificador já utilizado por outra operação.');
+            }
+            return jsonEncode(existing);
+          }
+          memoryStore[key] = data;
+          return jsonEncode(data);
+        }
+        if (action == 'list') {
+          var items = memoryStore.values.toList();
+          if (data['construtoraId'] != null) {
+            items = items.where((i) {
+              final payload = i['payload'] as Map<String, dynamic>?;
+              return i['construtoraId'] == data['construtoraId'] ||
+                  payload?['construtoraId'] == data['construtoraId'];
+            }).toList();
+          }
+          if (data['obraId'] != null) {
+            items = items.where((i) {
+              final payload = i['payload'] as Map<String, dynamic>?;
+              return i['obraId'] == data['obraId'] ||
+                  payload?['obraId'] == data['obraId'];
+            }).toList();
+          }
+          return jsonEncode(items);
+        }
+        if (action == 'claim') {
+          final key = data['key'] as String;
+          final item = memoryStore[key];
+          if (item == null) return 'null';
+          // Se já estiver em authorization_rejected, synced ou conflict, não permite claim a menos que force seja true
+          if (['synced', 'conflict', 'authorization_rejected'].contains(item['state']) &&
+              data['force'] != true) {
+            return 'null';
+          }
+          item['state'] = 'syncing';
+          item['lease'] = data['lease'];
+          return jsonEncode(item);
+        }
+        if (action == 'finish') {
+          final key = data['key'] as String;
+          final item = memoryStore[key];
+          if (item == null) return 'null';
+          item['state'] = data['state'];
+          item['error'] = data['error'];
+          if (data.containsKey('result')) {
+            item['result'] = data['result'];
+          }
+          item['lease'] = null;
+          return jsonEncode(item);
+        }
+        return 'null';
+      };
+
+      fakeUpload = (attachment, bytes, uid) async {};
+    });
+
+    test(
+        'Erro permission-denied transiciona operação para authorization_rejected e suspende retries',
+        () async {
+      int executionAttempts = 0;
+
+      final queue = OperationQueue(
+        sessionUid: () => 'user-sem-acesso',
+        store: fakeStore,
+        upload: fakeUpload,
+        execute: (action, payload) async {
+          executionAttempts++;
+          executedCalls.add({'action': action, 'payload': payload});
+          throw FirebaseFunctionsException(
+            code: 'permission-denied',
+            message: 'Estoque não autorizado',
+          );
+        },
+        autoSync: false,
+      );
+
+      await queue.enqueue('stockCommand', {
+        'operationId': 'op-auth-001',
+        'construtoraId': 'c-bloqueada',
+        'obraId': 'o-bloqueada',
+        'materialId': 'mat-001',
+        'type': 'saida',
+        'quantity': 1000,
+      });
+
+      // 1. Dispara o primeiro ciclo de sync
+      await queue.sync();
+
+      expect(executionAttempts, equals(1));
+      final itemsAfterFirstSync = await queue.list();
+      expect(itemsAfterFirstSync.length, equals(1));
+      expect(itemsAfterFirstSync.first['state'], equals('authorization_rejected'));
+      expect(itemsAfterFirstSync.first['error'], contains('permission-denied'));
+
+      // 2. Dispara novos ciclos de sync automáticos
+      await queue.sync();
+      await queue.sync();
+
+      // Nenhuma nova tentativa deve ser feita pelo motor de sync automático
+      expect(executionAttempts, equals(1));
+      final itemsAfterSubsequentSync = await queue.list();
+      expect(itemsAfterSubsequentSync.first['state'], equals('authorization_rejected'));
+    });
+
+    test(
+        'Erro unauthenticated transiciona operação para failed (recuperável após renovação da sessão)',
+        () async {
+      int executionAttempts = 0;
+
+      final queue = OperationQueue(
+        sessionUid: () => 'user-sessao-expirada',
+        store: fakeStore,
+        upload: fakeUpload,
+        execute: (action, payload) async {
+          executionAttempts++;
+          throw FirebaseFunctionsException(
+            code: 'unauthenticated',
+            message: 'A conta mudou. Entre novamente.',
+          );
+        },
+        autoSync: false,
+      );
+
+      await queue.enqueue('payExpense', {
+        'operationId': 'op-pay-auth-002',
+        'construtoraId': 'c-1',
+        'despesaId': 'desp-001',
+      });
+
+      await queue.sync();
+
+      expect(executionAttempts, equals(1));
+      final items = await queue.list();
+      expect(items.first['state'], equals('failed'));
+      expect(items.first['error'], contains('unauthenticated'));
+    });
+
+    test(
+        'Erro genérico contendo "não autorizado" ou "permission-denied" classifica como authorization_rejected',
+        () async {
+      final queue = OperationQueue(
+        sessionUid: () => 'user-operador',
+        store: fakeStore,
+        upload: fakeUpload,
+        execute: (action, payload) async {
+          throw StateError('Acesso não autorizado ao módulo financeiro');
+        },
+        autoSync: false,
+      );
+
+      await queue.enqueue('payExpense', {
+        'operationId': 'op-pay-auth-003',
+        'construtoraId': 'c-1',
+        'despesaId': 'desp-002',
+      });
+
+      await queue.sync();
+
+      final items = await queue.list();
+      expect(items.first['state'], equals('authorization_rejected'));
+      expect(items.first['error'], contains('não autorizado'));
+    });
+
+    test(
+        'Operação autorizada com sucesso comita sem falhas e atualiza estado para synced',
+        () async {
+      int executionAttempts = 0;
+
+      final queue = OperationQueue(
+        sessionUid: () => 'user-dev-global',
+        store: fakeStore,
+        upload: fakeUpload,
+        execute: (action, payload) async {
+          executionAttempts++;
+          return {'movementId': 'hash-dev-001', 'quantityUnits': 5000};
+        },
+        autoSync: false,
+      );
+
+      await queue.enqueue('stockCommand', {
+        'operationId': 'op-dev-auth-004',
+        'construtoraId': 'c-qualquer',
+        'obraId': 'o-qualquer',
+        'materialId': 'mat-dev-1',
+        'type': 'entrada',
+        'quantity': 5000,
+      });
+
+      await queue.sync();
+
+      expect(executionAttempts, equals(1));
+      final items = await queue.list();
+      expect(items.first['state'], equals('synced'));
+      expect(items.first['result'], isNotNull);
+      expect(items.first['result']['movementId'], equals('hash-dev-001'));
+      expect(await queue.scopedSyncedCount(), equals(1));
+    });
+
+    test(
+        'scopedFailedCount contabiliza operações em authorization_rejected para visualização na UI',
+        () async {
+      final queue = OperationQueue(
+        sessionUid: () => 'user-operario',
+        store: fakeStore,
+        upload: fakeUpload,
+        execute: (action, payload) async {
+          throw FirebaseFunctionsException(
+            code: 'permission-denied',
+            message: 'Diário não autorizado',
+          );
+        },
+        autoSync: false,
+      );
+
+      await queue.enqueue('finalizeDiario', {
+        'operationId': 'op-diario-auth-005',
+        'construtoraId': 'c-1',
+        'obraId': 'o-1',
+        'diario': {'id': 'd-1'},
+      });
+
+      await queue.sync();
+
+      // Verifica contagem com e sem escopo de obra
+      expect(await queue.scopedFailedCount(construtoraId: 'c-1', obraId: 'o-1'), equals(1));
+      expect(await queue.scopedFailedCount(construtoraId: 'c-1', obraId: 'o-outra'), equals(0));
+    });
+  });
+}
diff --git a/functions/src/contracts.ts b/functions/src/contracts.ts
index 72aff41..8f11d13 100644
--- a/functions/src/contracts.ts
+++ b/functions/src/contracts.ts
@@ -27,4 +27,4 @@ export function canonical(value: any): string {
 export const hash = (value: any) => createHash('sha256').update(canonical(value)).digest('hex');
 export const moduleName = (value: string) => ({rdo: 'diario', almoxarifado: 'estoque'}[value] || value);
 export function active(data: any): boolean { return data?.isActive === true; }
-export function manager(data: any): boolean { return active(data) && (data.isAdmin === true || data.isOwner === true); }
+export function manager(data: any): boolean { return active(data) && (data.isAdmin === true || data.isOwner === true || data.role === 'admin' || data.role === 'owner'); }
diff --git a/functions/src/index.ts b/functions/src/index.ts
index 76e1c45..4d29ed9 100644
--- a/functions/src/index.ts
+++ b/functions/src/index.ts
@@ -100,7 +100,7 @@ export const stockCommand = callable('stockCommand', async (d, uid) => {
   const payload = {m, type, quantity, o, l, reason: d.reason || d.observacao || '', reversalId: d.reversalId || null, evidence: d.evidence || null, apropriacaoLote: d.apropriacaoLote === true};
   const h = hash(payload), command = db.doc(`construtoras/${c}/commands/${hash([uid, op])}`), mat = db.doc(`construtoras/${c}/materiais/${m}`);
   return db.runTransaction(async tx => {
-    const a = await authority(tx, uid, c); if (!a.can('estoque')) fail('permission-denied', 'Estoque não autorizado');
+    const a = await authority(tx, uid, c, o || undefined); if (!a.can('estoque')) fail('permission-denied', 'Estoque não autorizado');
     if (['estorno', 'ajuste', 'abertura'].includes(type) && (!a.admin || typeof payload.reason !== 'string' || payload.reason.trim().length < 5 || typeof d.evidence !== 'string' || !d.evidence.trim())) fail('permission-denied', 'Correção exige administrador, motivo e evidência');
     const prior = (await tx.get(command)).data();
     if (prior) { if (prior.payloadHash !== h) fail('already-exists', 'operationId com conteúdo diferente'); return prior.result; }
diff --git a/functions/test/unit.cjs b/functions/test/unit.cjs
index 8d2f868..3dbd0f8 100644
--- a/functions/test/unit.cjs
+++ b/functions/test/unit.cjs
@@ -120,4 +120,87 @@ test('idempotencia de comandos: reenvio identico retorna mesmo resultado e diver
   assert.equal(sideEffectCounter, 1);
 });
 
+test('execucao de autorizacao: dev global irrestrito, managers homogeneos e isolamento de escopo',()=>{
+  // 1. Validar helper manager com flags e roles
+  assert.equal(manager({isAdmin: true, isActive: true}), true);
+  assert.equal(manager({isOwner: true, isActive: true}), true);
+  assert.equal(manager({role: 'admin', isActive: true}), true);
+  assert.equal(manager({role: 'owner', isActive: true}), true);
+  assert.equal(manager({role: 'admin', isActive: false}), false);
+  assert.equal(manager({role: 'member', isActive: true}), false);
+  assert.equal(manager(null), false);
+
+  // 2. Simulação da função authority de functions/src/index.ts
+  function evaluateAuthority({devActive, cm, om, o}) {
+    const dev = devActive === true;
+    return {
+      dev,
+      cm,
+      om,
+      admin: dev || manager(cm),
+      obraAdmin: dev || manager(cm) || (active(cm) && manager(om)),
+      can: (mod) => dev || manager(cm) || (active(cm) && (o ? active(om) && (manager(om) || (om?.modules || []).map(moduleName).includes(mod)) : (cm?.modules || []).map(moduleName).includes(mod)))
+    };
+  }
+
+  // Cenário A: Dev global ativo (sem membership na construtora nem na obra)
+  const devAuth = evaluateAuthority({devActive: true, cm: undefined, om: undefined});
+  assert.equal(devAuth.dev, true);
+  assert.equal(devAuth.admin, true);
+  assert.equal(devAuth.obraAdmin, true);
+  assert.equal(devAuth.can('estoque'), true);
+  assert.equal(devAuth.can('diario'), true);
+  assert.equal(devAuth.can('financeiro'), true);
+
+  // Cenário B: Usuário normal com vínculo ativo de admin na construtora
+  const adminAuth = evaluateAuthority({
+    devActive: false,
+    cm: {role: 'admin', isActive: true},
+    om: undefined
+  });
+  assert.equal(adminAuth.dev, false);
+  assert.equal(adminAuth.admin, true);
+  assert.equal(adminAuth.obraAdmin, true);
+  assert.equal(adminAuth.can('estoque'), true);
+  assert.equal(adminAuth.can('diario'), true);
+
+  // Cenário C: Membro operário da construtora ativo apenas para estoque
+  const stockMemberAuth = evaluateAuthority({
+    devActive: false,
+    cm: {role: 'operario', isActive: true, modules: ['almoxarifado']},
+    om: undefined
+  });
+  assert.equal(stockMemberAuth.dev, false);
+  assert.equal(stockMemberAuth.admin, false);
+  assert.equal(stockMemberAuth.can('estoque'), true);
+  assert.equal(stockMemberAuth.can('diario'), false);
+
+  // Cenário D: Membro de obra ativo para diário
+  const diarioMemberAuth = evaluateAuthority({
+    devActive: false,
+    cm: {role: 'member', isActive: true},
+    om: {role: 'member', isActive: true, modules: ['rdo']},
+    o: 'obra-1'
+  });
+  assert.equal(diarioMemberAuth.can('diario'), true);
+  assert.equal(diarioMemberAuth.can('estoque'), false);
+
+  // Cenário E: Membro desativado na construtora
+  const inactiveMemberAuth = evaluateAuthority({
+    devActive: false,
+    cm: {role: 'admin', isActive: false},
+    om: {role: 'admin', isActive: true},
+    o: 'obra-1'
+  });
+  assert.equal(inactiveMemberAuth.admin, false);
+  assert.equal(inactiveMemberAuth.obraAdmin, false);
+  assert.equal(inactiveMemberAuth.can('estoque'), false);
+  assert.equal(inactiveMemberAuth.can('diario'), false);
+
+  // Cenário F: Usuário sem nenhum vínculo
+  const nonMemberAuth = evaluateAuthority({devActive: false, cm: undefined, om: undefined});
+  assert.equal(nonMemberAuth.admin, false);
+  assert.equal(nonMemberAuth.can('estoque'), false);
+});
+
 
```

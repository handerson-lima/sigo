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


claims_file: 
---
title: 'Story 13.2 - Rotas Declarativas e Drill-down Inicial (Construtora → Loteamento → Quadra)'
type: 'feature'
created: '2026-09-25'
status: 'in-progress'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '2e48915ec6ea4a0469248f2940882b438061f75f'
context: ['_bmad-output/implementation-artifacts/epic-13-context.md', '_bmad-output/planning-artifacts/architecture/architecture-obras-2026-09-24/ARCHITECTURE-SPINE.md', '_bmad-output/specs/spec-navegacao-loteamento-etapa/SPEC.md', '_bmad-output/planning-artifacts/architecture/architecture-modular-routing-2026-09-23/ARCHITECTURE-SPINE.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A navegação usa o prefixo singular `/construtora/:cId`, divergente do AD-2 (`/construtoras/:cid/loteamentos/:lid/quadras/:qid/...`), e a UI principal ainda exibe "Obras" e "Lotes e Setores". O card de construtora cai em `ObrasListScreen` em vez da lista de Loteamentos, e parte do contexto depende de singletons (`obraSelecionadaProvider`, `ObraSwitcher`) em vez da URL.

**Approach:** Padronizar as rotas declarativas em `/construtoras/:cid/...`, derivando o contexto dos parâmetros da URL, com drill-down até Quadra (Lote/Etapa/Equipe ficam para 13.3/13.4). Renomear "Obras"→"Loteamentos" na navegação principal e fazer o card de construtora abrir a listagem de Loteamentos (CAP-1).

## Boundaries & Constraints

**Always:**
- Paths plurais e minúsculos: `/construtoras`, `/loteamentos`, `/quadras`, `/lotes`, `/etapas`, `/equipes` (AD-2 e Conventions da spine).
- Cada listagem carrega a partir dos params da URL; nunca de singleton global de seleção (AD-2).
- Breadcrumbs derivam do path e exibem também o nível Construtora.
- Navegação usa exclusivamente a terminologia Loteamento/Quadra/Lote/Etapa/Equipe.

**Never:**
- Não alterar o esquema de dados entregue na 13.1 nem criar subcollections.
- Não remover as features obra-scoped ainda em uso (diário, RH, compras, custos) sem rota substituta.
- Não mudar perfis de acesso nem o dashboard principal além de label/clique (non-goal do SPEC).

**Decisions:**
- Prefixo plural `/construtoras` com rota de compatibilidade: `/construtora/:cid/...` → redirect para `/construtoras/:cid/...` preservando query/fragment.
- Rotas obra-scoped (`/obra/:oid/{diarios,rh,compras,despesas,custos-360}`) permanecem vivas sob `/construtoras/:cid/...`; apenas o entrypoint da construtora passa a Loteamentos.
- Higienização do estado global `obraSelecionadaProvider`/`ObraSwitcher` fica diferida (registrada em `deferred-work.md`).
- Card de construtora abre direto `/construtoras/:cid/loteamentos`.
- Spec mantido completo (coeso; ~1638 tokens, pouco acima do alvo).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH | toque no card de uma construtora | URL vira `/construtoras/:cid/loteamentos` e lista os Loteamentos da construtora | N/A |
| DEEP_LINK | abrir `/construtoras/:cid/loteamentos/:lid/quadras` direto | renderiza as Quadras do loteamento da URL | estado vazio contextual se não houver quadras |
| PARENT_REDIRECT | abrir `/construtoras/:cid/loteamentos/:lid` | redireciona para `.../:lid/quadras` preservando query/fragment | N/A |
| LEGACY_SINGULAR | abrir `/construtora/:cid/...` | redireciona para `/construtoras/:cid/...` preservando query/fragment | N/A |
| BREADCRUMB_ASCENT | tocar no crumb "Loteamentos" | ascende para a lista de Loteamentos | N/A |
| EMPTY_STATE | construtora sem loteamentos | exibe vazio contextual com CTA de criação (se houver) | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/routing/app_router.dart:29,60-64` — `routerProvider`; spread de `authRoutes`/`devRoutes`/`construtoraRoutes`; redirect central de auth/dev em `:36-59`.
- `app/lib/src/features/construtoras/routing/construtora_routes.dart:24,32-71` — `ConstrutoraPaths.detail = '/construtora/:cId'` e o nó-pai que recebe `...obraRoutes`, `...loteamentosRoutes`, etc. (`:58-69`). Prefixo singular a migrar.
- `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart:7-8,24-36` — `loteamentos`/`loteamentos/:loteamentoId`; redirect `:loteamentoId`→`/quadras` em `:27-31`.
- `app/lib/src/features/quadras/routing/quadras_routes.dart:7-8,26-38` — `quadras`/`quadras/:quadraId`; redirect `:quadraId`→`/lotes`.
- `app/lib/src/features/lotes/routing/lotes_routes.dart:8-9,50-59` — `lotes`/`:loteId`→`/etapas`; `...etapasRoutes` composto em `:54`.
- `app/lib/src/features/etapas/routing/etapas_routes.dart:7,29-41` e `.../equipes/routing/equipes_routes.dart:6-30` — módulos Lote→Etapa→Equipe (já entregues; manter funcionando).
- `app/lib/src/features/obras/routing/obra_routes.dart:8-27` — `obra/:oId` → `ObraDashboardScreen`; módulos obra-scoped (`diario_routes.dart:11-13`, `rh_routes.dart:16-19`, `epi_routes.dart:10`, `despesas_adm_routes.dart:10-14`, `compras_routes.dart:10-14`, `custos_360_routes.dart:9-11`).
- `app/lib/src/common_widgets/sigo_breadcrumbs.dart:16-62` — deriva de `uri.pathSegments`; reconhece só `loteamentos|quadras|lotes|etapas|equipes`; **ignora `construtora`/`construtoras`** e não emite crumb da construtora.
- `app/lib/src/common_widgets/sigo_sidebar.dart:28` — parser testa `pathSegments[0] == 'construtora'`; itens "Dashboard" (`:220-229`), "Lotes e Setores" (`:235-243`, navega para `/construtora/$cId/loteamentos`), "Diário de Obra" (`:250`).
- `app/lib/src/common_widgets/sigo_top_bar.dart:69-73,206-282` — parser singular em `:69`; `ObraSwitcher` navega para `/construtora/$construtoraId/obra/$newObraId` em `:272`.
- `app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart:68` — card navega para `/construtora/${construtora.id}` (cai em `ObrasListScreen`).
- `app/lib/src/features/obras/presentation/obras_list_screen.dart:82-110,174-399` — entrypoint atual; labels "Obra"/"Nova Obra"; atalho "Loteamentos" em `:104-110`.
- `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart:88-155` — "Painel da Obra"; card "Lotes e Setores" (`:144-150`) → `/construtora/$cId/loteamentos`.
- `app/lib/src/features/construtoras/presentation/membros_providers.dart:206-217` — `obraSelecionadaProvider` (estado global).
- Screens que montam `activeRoute`/`context.go` com prefixo singular: `loteamentos_list_screen.dart:25,55`, `quadras_list_screen.dart:28,58`, `lotes_list_screen.dart:37`, `etapas_list_screen.dart:35`, `equipes_list_screen.dart:40`.
- Testes a migrar para plural: `app/test/loteamento_quadra_lote_navigation_test.dart`, `app/test/sigo_breadcrumbs_test.dart`, `app/test/loteamento_quadra_lote_providers_test.dart`, `app/test/sigo_top_bar_test.dart`, `app/test/obra_switcher_layout_test.dart`, `app/test/sigo_sidebar_test.dart`, `app/test/sigo_sidebar_collapsed_test.dart`, e `app/test/src/features/**/presentation/*_test.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/construtoras/routing/construtora_routes.dart` — trocar `ConstrutoraPaths.detail` para `/construtoras/:cid` e ajustar `membros`/subárvore; manter os módulos obra-scoped vivos sob o plural (ver Decisions).
- [x] `app/lib/src/features/{loteamentos,quadras,lotes,etapas,equipes}/routing/*_routes.dart` — atualizar paths/`*For()` para plural e `:cid`; preservar os redirects pai→filho existentes.
- [x] `app/lib/src/routing/app_router.dart` — adicionar redirect de `/construtora/...` → `/construtoras/...` preservando query/fragment (rota de compatibilidade).
- [x] `app/lib/src/common_widgets/sigo_breadcrumbs.dart` — reconhecer `construtoras` e emitir o crumb da Construtora (link para `/construtoras/:cid/loteamentos`), sem quebrar os crumbs existentes.
- [x] `app/lib/src/common_widgets/sigo_sidebar.dart` e `sigo_top_bar.dart` — parser para `construtoras`; renomear "Lotes e Setores"→"Loteamentos" e demais labels de navegação.
- [x] `app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart` — card navega para `/construtoras/:cid/loteamentos` (CAP-1).
- [x] `app/lib/src/features/obras/presentation/obras_list_screen.dart` / `obra_dashboard_screen.dart` — ajustar entrypoint e labels "Obra"→"Loteamento" na navegação (card da construtora → Loteamentos; ver Decisions).
- [x] `app/test/**` — migrar paths para plural e cobrir: card→Loteamentos, deep-link até Quadra, redirects pai→filho, redirect de compatibilidade (se A) e crumb da Construtora.

**Acceptance Criteria:**
- Given um usuário logado, when toca o card de uma construtora, then a URL é `/construtoras/:cid/loteamentos` e vê os Loteamentos da construtora.
- Given a lista de Loteamentos, when seleciona um loteamento, then a URL vira `.../loteamentos/:lid/quadras` e vê apenas as Quadras desse loteamento.
- Given deep-link em `/construtoras/:cid/loteamentos/:lid/quadras`, when abre direto, then renderiza as Quadras corretas a partir da URL.
- Given abertura de path pai (`.../loteamentos/:lid`), when navega, then redireciona para a listagem filha preservando query/fragment.
- Given qualquer path com "Obras"/"Setor" na navegação, when renderiza, then os labels exibem Loteamentos/Etapa.
- Given a rota legada, when abre `/construtora/:cid/loteamentos`, then redireciona para `/construtoras/:cid/loteamentos` preservando query/fragment.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

**Rota modular (padrão existente):** cada feature expõe `<Feature>Paths` + `get <feature>Routes` e é composta por spread no nó-pai (`construtora_routes.dart:58-69`); manter esse padrão e apenas migrar o prefixo/params. Não introduzir provider de navegação global — a URL é a fonte do contexto (AD-2).

```dart
abstract class ConstrutoraPaths {
  static const detail = '/construtoras/:cid';
  static String detailFor(String cid) => '/construtoras/$cid';
}
```

**Redirects pai→filho:** manter o padrão atual que preserva query/fragment (`state.uri.path == state.matchedLocation ? state.uri.replace(path: '...') : null`) já usado em `loteamentos_routes.dart:27-31` e `quadras_routes.dart:29-33`.

## Verification

**Commands:**
- `flutter analyze` (workdir `app/`) — expected: `No issues found!`
- `flutter test` (workdir `app/`) — expected: todos os testes passam, incluindo navegação e breadcrumbs migrados para `/construtoras`.
- `flutter test test/loteamento_quadra_lote_navigation_test.dart test/sigo_breadcrumbs_test.dart` — expected: deep-links, redirects e crumb da Construtora passam.

**Manual checks (if no CLI):**
- Tocar o card de construtora e confirmar `/construtoras/:cid/loteamentos` com Loteamentos.
- Clicar num Loteamento → Quadras, conferindo a URL e o breadcrumb (incluindo Construtora).
- Abrir um deep-link direto de Quadras e confirmar render a partir da URL.


Review content:
diff --git a/_bmad-output/implementation-artifacts/spec-13-2-rotas-declarativas-drill-down.md b/_bmad-output/implementation-artifacts/spec-13-2-rotas-declarativas-drill-down.md
index f6e7783..b32e60e 100644
--- a/_bmad-output/implementation-artifacts/spec-13-2-rotas-declarativas-drill-down.md
+++ b/_bmad-output/implementation-artifacts/spec-13-2-rotas-declarativas-drill-down.md
@@ -2,9 +2,10 @@
 title: 'Story 13.2 - Rotas Declarativas e Drill-down Inicial (Construtora → Loteamento → Quadra)'
 type: 'feature'
 created: '2026-09-25'
-status: 'ready-for-dev'
+status: 'in-progress'
 route: 'dispatch'
 review_loop_iteration: 0
+baseline_commit: '2e48915ec6ea4a0469248f2940882b438061f75f'
 context: ['_bmad-output/implementation-artifacts/epic-13-context.md', '_bmad-output/planning-artifacts/architecture/architecture-obras-2026-09-24/ARCHITECTURE-SPINE.md', '_bmad-output/specs/spec-navegacao-loteamento-etapa/SPEC.md', '_bmad-output/planning-artifacts/architecture/architecture-modular-routing-2026-09-23/ARCHITECTURE-SPINE.md']
 ---
 
@@ -71,14 +72,14 @@ context: ['_bmad-output/implementation-artifacts/epic-13-context.md', '_bmad-out
 ## Tasks & Acceptance
 
 **Execution:**
-- [ ] `app/lib/src/features/construtoras/routing/construtora_routes.dart` — trocar `ConstrutoraPaths.detail` para `/construtoras/:cid` e ajustar `membros`/subárvore; manter os módulos obra-scoped vivos sob o plural (ver Decisions).
-- [ ] `app/lib/src/features/{loteamentos,quadras,lotes,etapas,equipes}/routing/*_routes.dart` — atualizar paths/`*For()` para plural e `:cid`; preservar os redirects pai→filho existentes.
-- [ ] `app/lib/src/routing/app_router.dart` — adicionar redirect de `/construtora/...` → `/construtoras/...` preservando query/fragment (rota de compatibilidade).
-- [ ] `app/lib/src/common_widgets/sigo_breadcrumbs.dart` — reconhecer `construtoras` e emitir o crumb da Construtora (link para `/construtoras/:cid/loteamentos`), sem quebrar os crumbs existentes.
-- [ ] `app/lib/src/common_widgets/sigo_sidebar.dart` e `sigo_top_bar.dart` — parser para `construtoras`; renomear "Lotes e Setores"→"Loteamentos" e demais labels de navegação.
-- [ ] `app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart` — card navega para `/construtoras/:cid/loteamentos` (CAP-1).
-- [ ] `app/lib/src/features/obras/presentation/obras_list_screen.dart` / `obra_dashboard_screen.dart` — ajustar entrypoint e labels "Obra"→"Loteamento" na navegação (card da construtora → Loteamentos; ver Decisions).
-- [ ] `app/test/**` — migrar paths para plural e cobrir: card→Loteamentos, deep-link até Quadra, redirects pai→filho, redirect de compatibilidade (se A) e crumb da Construtora.
+- [x] `app/lib/src/features/construtoras/routing/construtora_routes.dart` — trocar `ConstrutoraPaths.detail` para `/construtoras/:cid` e ajustar `membros`/subárvore; manter os módulos obra-scoped vivos sob o plural (ver Decisions).
+- [x] `app/lib/src/features/{loteamentos,quadras,lotes,etapas,equipes}/routing/*_routes.dart` — atualizar paths/`*For()` para plural e `:cid`; preservar os redirects pai→filho existentes.
+- [x] `app/lib/src/routing/app_router.dart` — adicionar redirect de `/construtora/...` → `/construtoras/...` preservando query/fragment (rota de compatibilidade).
+- [x] `app/lib/src/common_widgets/sigo_breadcrumbs.dart` — reconhecer `construtoras` e emitir o crumb da Construtora (link para `/construtoras/:cid/loteamentos`), sem quebrar os crumbs existentes.
+- [x] `app/lib/src/common_widgets/sigo_sidebar.dart` e `sigo_top_bar.dart` — parser para `construtoras`; renomear "Lotes e Setores"→"Loteamentos" e demais labels de navegação.
+- [x] `app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart` — card navega para `/construtoras/:cid/loteamentos` (CAP-1).
+- [x] `app/lib/src/features/obras/presentation/obras_list_screen.dart` / `obra_dashboard_screen.dart` — ajustar entrypoint e labels "Obra"→"Loteamento" na navegação (card da construtora → Loteamentos; ver Decisions).
+- [x] `app/test/**` — migrar paths para plural e cobrir: card→Loteamentos, deep-link até Quadra, redirects pai→filho, redirect de compatibilidade (se A) e crumb da Construtora.
 
 **Acceptance Criteria:**
 - Given um usuário logado, when toca o card de uma construtora, then a URL é `/construtoras/:cid/loteamentos` e vê os Loteamentos da construtora.
diff --git a/_bmad-output/implementation-artifacts/sprint-status.yaml b/_bmad-output/implementation-artifacts/sprint-status.yaml
index 58a63e8..72ddeb7 100644
--- a/_bmad-output/implementation-artifacts/sprint-status.yaml
+++ b/_bmad-output/implementation-artifacts/sprint-status.yaml
@@ -5,7 +5,7 @@
 # IDs históricos preservados; docs/stories não existe no workspace atual.
 
 generated: 09-14-2026 16:15
-last_updated: 09-25-2026 12:31
+last_updated: 09-25-2026 12:33
 project: obras
 project_key: SIGO
 tracking_system: file-system
@@ -59,9 +59,9 @@ development_status:
   12-2-ocultar-construtoras-inativas-na-listagem-do-usuário: review
   epic-12-retrospective: optional
 
-  epic-13: backlog
+  epic-13: in-progress
   13-1-atualizar-esquema-de-dados-raiz-no-firestore: backlog
-  13-2-rotas-declarativas-e-drill-down-inicial: backlog
+  13-2-rotas-declarativas-e-drill-down-inicial: in-progress
   13-3-ramificação-específica-de-etapas-por-lote: backlog
   13-4-navegação-final-alocação-de-equipe-na-etapa: backlog
   epic-13-retrospective: optional
diff --git a/app/lib/src/common_widgets/sigo_breadcrumbs.dart b/app/lib/src/common_widgets/sigo_breadcrumbs.dart
index 2784233..e9eaa74 100644
--- a/app/lib/src/common_widgets/sigo_breadcrumbs.dart
+++ b/app/lib/src/common_widgets/sigo_breadcrumbs.dart
@@ -23,7 +23,12 @@ class SigoBreadcrumbs extends StatelessWidget {
     for (int i = 0; i < pathSegments.length; i++) {
       currentUrl += '/${pathSegments[i]}';
       
-      if (pathSegments[i] == 'loteamentos') {
+      if (pathSegments[i] == 'construtoras') {
+        if (i + 1 < pathSegments.length) {
+          final cid = pathSegments[i + 1];
+          segments.add(BreadcrumbSegment(label: 'Construtora', url: '/construtoras/$cid/loteamentos'));
+        }
+      } else if (pathSegments[i] == 'loteamentos') {
         if (i + 1 < pathSegments.length) {
           segments.add(BreadcrumbSegment(label: 'Loteamento', url: currentUrl));
         } else {
diff --git a/app/lib/src/common_widgets/sigo_sidebar.dart b/app/lib/src/common_widgets/sigo_sidebar.dart
index 6e7f095..811cd3d 100644
--- a/app/lib/src/common_widgets/sigo_sidebar.dart
+++ b/app/lib/src/common_widgets/sigo_sidebar.dart
@@ -25,7 +25,7 @@ class SigoSidebar extends ConsumerWidget {
     final pathSegments = uri.pathSegments;
     String? cId;
     String? oId;
-    if (pathSegments.length >= 2 && pathSegments[0] == 'construtora') {
+    if (pathSegments.length >= 2 && pathSegments[0] == 'construtoras') {
       cId = pathSegments[1];
       if (pathSegments.length >= 4 && pathSegments[2] == 'obra') {
         oId = pathSegments[3];
@@ -221,10 +221,10 @@ class SigoSidebar extends ConsumerWidget {
                   _NavItem(
                     icon: Icons.dashboard,
                     title: 'Dashboard',
-                    isActive: activeRoute == '/construtora/$cId/obra/$oId',
+                    isActive: activeRoute == '/construtoras/$cId/obra/$oId',
                     onTap: () {
                       Scaffold.maybeOf(context)?.closeDrawer();
-                      context.go('/construtora/$cId/obra/$oId');
+                      context.go('/construtoras/$cId/obra/$oId');
                     },
                   ),
                   if (isDev ||
@@ -234,11 +234,11 @@ class SigoSidebar extends ConsumerWidget {
                           construtoraModules.contains('lotes')))
                     _NavItem(
                       icon: Icons.map,
-                      title: 'Lotes e Setores',
-                      isActive: activeRoute.contains('/lotes'),
+                      title: 'Loteamentos',
+                      isActive: activeRoute.contains('/loteamentos'),
                       onTap: () {
                         Scaffold.maybeOf(context)?.closeDrawer();
-                        context.go('/construtora/$cId/loteamentos');
+                        context.go('/construtoras/$cId/loteamentos');
                       },
                     ),
                   if (obra != null &&
@@ -251,7 +251,7 @@ class SigoSidebar extends ConsumerWidget {
                       isActive: activeRoute.contains('/diarios'),
                       onTap: () {
                         Scaffold.maybeOf(context)?.closeDrawer();
-                        context.go('/construtora/$cId/obra/$oId/diarios');
+                        context.go('/construtoras/$cId/obra/$oId/diarios');
                       },
                     ),
                   if (obra != null &&
@@ -265,7 +265,7 @@ class SigoSidebar extends ConsumerWidget {
                       isActive: activeRoute.contains('/rh/chamadas'),
                       onTap: () {
                         Scaffold.maybeOf(context)?.closeDrawer();
-                        context.go('/construtora/$cId/obra/$oId/rh/chamadas');
+                        context.go('/construtoras/$cId/obra/$oId/rh/chamadas');
                       },
                     ),
                   if (canEpi)
@@ -275,7 +275,7 @@ class SigoSidebar extends ConsumerWidget {
                       isActive: activeRoute.contains('/epis/entrega'),
                       onTap: () {
                         Scaffold.maybeOf(context)?.closeDrawer();
-                        context.go('/construtora/$cId/obra/$oId/epis/entrega');
+                        context.go('/construtoras/$cId/obra/$oId/epis/entrega');
                       },
                     ),
                   if (canAdm)
@@ -285,7 +285,7 @@ class SigoSidebar extends ConsumerWidget {
                       isActive: activeRoute.contains('/despesas'),
                       onTap: () {
                         Scaffold.maybeOf(context)?.closeDrawer();
-                        context.go('/construtora/$cId/obra/$oId/despesas');
+                        context.go('/construtoras/$cId/obra/$oId/despesas');
                       },
                     ),
                   if (canCompras)
@@ -295,7 +295,7 @@ class SigoSidebar extends ConsumerWidget {
                       isActive: activeRoute.contains('/compras'),
                       onTap: () {
                         Scaffold.maybeOf(context)?.closeDrawer();
-                        context.go('/construtora/$cId/obra/$oId/compras');
+                        context.go('/construtoras/$cId/obra/$oId/compras');
                       },
                     ),
                   if (canAdm || canFinanceiro)
@@ -305,7 +305,7 @@ class SigoSidebar extends ConsumerWidget {
                       isActive: activeRoute.contains('/custos-360'),
                       onTap: () {
                         Scaffold.maybeOf(context)?.closeDrawer();
-                        context.go('/construtora/$cId/obra/$oId/custos-360');
+                        context.go('/construtoras/$cId/obra/$oId/custos-360');
                       },
                     ),
                   if (!collapsed) ...[
@@ -343,7 +343,7 @@ class SigoSidebar extends ConsumerWidget {
                     icon: Icons.sync,
                     title: 'Fila deste dispositivo',
                     isActive: activeRoute.endsWith('/sync'),
-                    onTap: () => context.go('/construtora/$cId/sync'),
+                    onTap: () => context.go('/construtoras/$cId/sync'),
                   ),
                 if (cId != null && canRh)
                   _NavItem(
@@ -353,7 +353,7 @@ class SigoSidebar extends ConsumerWidget {
                         !activeRoute.contains('/chamadas'),
                     onTap: () {
                       Scaffold.maybeOf(context)?.closeDrawer();
-                      context.go('/construtora/$cId/rh/funcionarios');
+                      context.go('/construtoras/$cId/rh/funcionarios');
                     },
                   ),
                 if (cId != null && canEpiCatalogo)
@@ -363,7 +363,7 @@ class SigoSidebar extends ConsumerWidget {
                     isActive: activeRoute.contains('/epis') && !activeRoute.contains('/obra/'),
                     onTap: () {
                       Scaffold.maybeOf(context)?.closeDrawer();
-                      context.go('/construtora/$cId/epis');
+                      context.go('/construtoras/$cId/epis');
                     },
                   ),
                 if (cId != null && canValidacao)
@@ -373,7 +373,7 @@ class SigoSidebar extends ConsumerWidget {
                     isActive: activeRoute.contains('/validacao/templates'),
                     onTap: () {
                       Scaffold.maybeOf(context)?.closeDrawer();
-                      context.go('/construtora/$cId/validacao/templates');
+                      context.go('/construtoras/$cId/validacao/templates');
                     },
                   ),
                 if (cId != null && canFornecedores)
@@ -383,7 +383,7 @@ class SigoSidebar extends ConsumerWidget {
                     isActive: activeRoute.contains('/fornecedores'),
                     onTap: () {
                       Scaffold.maybeOf(context)?.closeDrawer();
-                      context.go('/construtora/$cId/fornecedores');
+                      context.go('/construtoras/$cId/fornecedores');
                     },
                   ),
                 if (cId != null && canEstoque)
@@ -393,7 +393,7 @@ class SigoSidebar extends ConsumerWidget {
                     isActive: activeRoute.contains('/almoxarifado'),
                     onTap: () {
                       Scaffold.maybeOf(context)?.closeDrawer();
-                      context.go('/construtora/$cId/almoxarifado');
+                      context.go('/construtoras/$cId/almoxarifado');
                     },
                   ),
                 if (cId != null && canFinanceiro)
@@ -403,7 +403,7 @@ class SigoSidebar extends ConsumerWidget {
                     isActive: activeRoute.contains('/financeiro'),
                     onTap: () {
                       Scaffold.maybeOf(context)?.closeDrawer();
-                      context.go('/construtora/$cId/financeiro');
+                      context.go('/construtoras/$cId/financeiro');
                     },
                   ),
                 if (cId != null && canMembros)
@@ -413,7 +413,7 @@ class SigoSidebar extends ConsumerWidget {
                     isActive: activeRoute.contains('/membros'),
                     onTap: () {
                       Scaffold.maybeOf(context)?.closeDrawer();
-                      context.go('/construtora/$cId/membros');
+                      context.go('/construtoras/$cId/membros');
                     },
                   ),
                 if (isDev)
diff --git a/app/lib/src/common_widgets/sigo_top_bar.dart b/app/lib/src/common_widgets/sigo_top_bar.dart
index 8f2e558..f775e76 100644
--- a/app/lib/src/common_widgets/sigo_top_bar.dart
+++ b/app/lib/src/common_widgets/sigo_top_bar.dart
@@ -66,7 +66,7 @@ class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
     if (route != null) {
       final uri = Uri.tryParse(route);
       final segments = uri?.pathSegments ?? [];
-      if (segments.length >= 2 && segments[0] == 'construtora') {
+      if (segments.length >= 2 && segments[0] == 'construtoras') {
         cId = segments[1];
         if (segments.length >= 4 && segments[2] == 'obra') {
           oId = segments[3];
@@ -235,7 +235,7 @@ class ObraSwitcher extends ConsumerWidget {
               key: const Key('obra-switcher-dropdown'),
               value: selectedValue,
               hint: const Text(
-                'Selecionar Obra',
+                'Selecionar Loteamento',
                 style: TextStyle(fontSize: 12, color: Colors.black54),
               ),
               icon: const Icon(Icons.swap_horiz, size: 18, color: Colors.amber),
@@ -269,7 +269,7 @@ class ObraSwitcher extends ConsumerWidget {
               }).toList(),
               onChanged: (newObraId) {
                 if (newObraId != null && newObraId != currentObraId) {
-                  context.go('/construtora/$construtoraId/obra/$newObraId');
+                  context.go('/construtoras/$construtoraId/obra/$newObraId');
                 }
               },
             ),
diff --git a/app/lib/src/features/almoxarifado/presentation/add_material_screen.dart b/app/lib/src/features/almoxarifado/presentation/add_material_screen.dart
index 4921a15..0ff9157 100644
--- a/app/lib/src/features/almoxarifado/presentation/add_material_screen.dart
+++ b/app/lib/src/features/almoxarifado/presentation/add_material_screen.dart
@@ -57,7 +57,7 @@ class _AddMaterialScreenState extends ConsumerState<AddMaterialScreen> {
   Widget build(BuildContext context) {
     return SigoLayout(
       title: 'Novo Material no Catálogo',
-      activeRoute: '/construtora/${widget.construtoraId}/almoxarifado',
+      activeRoute: '/construtoras/${widget.construtoraId}/almoxarifado',
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Form(
diff --git a/app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart b/app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart
index 8305f42..e56f2d4 100644
--- a/app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart
+++ b/app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart
@@ -30,10 +30,10 @@ class AlmoxarifadoListScreen extends ConsumerWidget {
 
     return SigoLayout(
       title: 'Almoxarifado Central',
-      activeRoute: '/construtora/$construtoraId/almoxarifado',
+      activeRoute: '/construtoras/$construtoraId/almoxarifado',
       floatingActionButton: FloatingActionButton.extended(
         onPressed: () => context.go(
-          '/construtora/$construtoraId/almoxarifado/novo_material',
+          '/construtoras/$construtoraId/almoxarifado/novo_material',
         ),
         icon: const Icon(Icons.add),
         label: const Text('Novo Material'),
@@ -112,7 +112,7 @@ class AlmoxarifadoListScreen extends ConsumerWidget {
                       icon: const Icon(Icons.arrow_upward, color: Colors.green),
                       tooltip: 'Registrar Entrada',
                       onPressed: () => context.go(
-                        '/construtora/$construtoraId/almoxarifado/movimentacao',
+                        '/construtoras/$construtoraId/almoxarifado/movimentacao',
                         extra: {'material': material, 'type': 'entrada'},
                       ),
                     ),
@@ -120,7 +120,7 @@ class AlmoxarifadoListScreen extends ConsumerWidget {
                       icon: const Icon(Icons.arrow_downward, color: Colors.red),
                       tooltip: 'Registrar Saída',
                       onPressed: () => context.go(
-                        '/construtora/$construtoraId/almoxarifado/movimentacao',
+                        '/construtoras/$construtoraId/almoxarifado/movimentacao',
                         extra: {'material': material, 'type': 'saida'},
                       ),
                     ),
diff --git a/app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart b/app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart
index 3de126e..ea21e08 100644
--- a/app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart
+++ b/app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart
@@ -252,7 +252,7 @@ class _MovimentacaoScreenState extends ConsumerState<MovimentacaoScreen> {
     final isSaida = widget.type == MovimentacaoType.saida;
     return SigoLayout(
       title: isSaida ? 'Saída de Material' : 'Entrada de Material',
-      activeRoute: '/construtora/${widget.construtoraId}/almoxarifado',
+      activeRoute: '/construtoras/${widget.construtoraId}/almoxarifado',
       child: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
         child: Form(
diff --git a/app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart b/app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart
index 2b1e571..826b2e8 100644
--- a/app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart
+++ b/app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart
@@ -332,7 +332,7 @@ class StockHistoryScreen extends StatelessWidget {
   @override
   Widget build(BuildContext context) => SigoLayout(
     title: 'Histórico · ${material.name}',
-    activeRoute: '/construtora/$c/almoxarifado',
+    activeRoute: '/construtoras/$c/almoxarifado',
     child: Column(
       children: [
         if (canManage)
diff --git a/app/lib/src/features/almoxarifado/routing/almoxarifado_routes.dart b/app/lib/src/features/almoxarifado/routing/almoxarifado_routes.dart
index 8e70831..67aa5e9 100644
--- a/app/lib/src/features/almoxarifado/routing/almoxarifado_routes.dart
+++ b/app/lib/src/features/almoxarifado/routing/almoxarifado_routes.dart
@@ -14,11 +14,11 @@ abstract class AlmoxarifadoPaths {
   static const novoMaterial = 'almoxarifado/novo_material';
   static const movimentacao = 'almoxarifado/movimentacao';
 
-  static String listFor(String cId) => '/construtora/$cId/almoxarifado';
+  static String listFor(String cId) => '/construtoras/$cId/almoxarifado';
   static String novoMaterialFor(String cId) =>
-      '/construtora/$cId/almoxarifado/novo_material';
+      '/construtoras/$cId/almoxarifado/novo_material';
   static String movimentacaoFor(String cId) =>
-      '/construtora/$cId/almoxarifado/movimentacao';
+      '/construtoras/$cId/almoxarifado/movimentacao';
 }
 
 /// Rotas do módulo de almoxarifado.
diff --git a/app/lib/src/features/compras_parcelas/presentation/compra_detalhes_screen.dart b/app/lib/src/features/compras_parcelas/presentation/compra_detalhes_screen.dart
index 4fb0422..d3f7ab7 100644
--- a/app/lib/src/features/compras_parcelas/presentation/compra_detalhes_screen.dart
+++ b/app/lib/src/features/compras_parcelas/presentation/compra_detalhes_screen.dart
@@ -227,7 +227,7 @@ class _CompraDetalhesScreenState extends ConsumerState<CompraDetalhesScreen> {
     return SigoLayout(
       title: 'Detalhes da Compra / NF',
       activeRoute:
-          '/construtora/${widget.construtoraId}/obra/${widget.obraId}/compras',
+          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/compras',
       actions: [
         compraAsync.maybeWhen(
           data: (compra) {
@@ -240,7 +240,7 @@ class _CompraDetalhesScreenState extends ConsumerState<CompraDetalhesScreen> {
               onSelected: (val) {
                 if (val == 'editar') {
                   context.push(
-                    '/construtora/${widget.construtoraId}/obra/${widget.obraId}/compras/${widget.compraId}/editar',
+                    '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/compras/${widget.compraId}/editar',
                   );
                 } else if (val == 'cancelar') {
                   _cancelarCompra(compra);
diff --git a/app/lib/src/features/compras_parcelas/presentation/compra_form_screen.dart b/app/lib/src/features/compras_parcelas/presentation/compra_form_screen.dart
index 9a82cbf..0f1ebff 100644
--- a/app/lib/src/features/compras_parcelas/presentation/compra_form_screen.dart
+++ b/app/lib/src/features/compras_parcelas/presentation/compra_form_screen.dart
@@ -434,7 +434,7 @@ class _CompraFormScreenState extends ConsumerState<CompraFormScreen> {
           ? 'Nova Compra / Nota Fiscal'
           : 'Editar Compra / NF',
       activeRoute:
-          '/construtora/${widget.construtoraId}/obra/${widget.obraId}/compras',
+          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/compras',
       child: _isLoading
           ? const Center(child: CircularProgressIndicator())
           : SingleChildScrollView(
diff --git a/app/lib/src/features/compras_parcelas/presentation/compras_list_screen.dart b/app/lib/src/features/compras_parcelas/presentation/compras_list_screen.dart
index 7b57b1a..6a3a082 100644
--- a/app/lib/src/features/compras_parcelas/presentation/compras_list_screen.dart
+++ b/app/lib/src/features/compras_parcelas/presentation/compras_list_screen.dart
@@ -44,11 +44,11 @@ class _ComprasListScreenState extends ConsumerState<ComprasListScreen> {
     return SigoLayout(
       title: 'Compras e Notas Fiscais',
       activeRoute:
-          '/construtora/${widget.construtoraId}/obra/${widget.obraId}/compras',
+          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/compras',
       floatingActionButton: FloatingActionButton.extended(
         onPressed: () {
           context.push(
-            '/construtora/${widget.construtoraId}/obra/${widget.obraId}/compras/nova',
+            '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/compras/nova',
           );
         },
         icon: const Icon(Icons.add),
@@ -264,7 +264,7 @@ class _ComprasListScreenState extends ConsumerState<ComprasListScreen> {
           borderRadius: BorderRadius.circular(10),
           onTap: () {
             context.push(
-              '/construtora/${widget.construtoraId}/obra/${widget.obraId}/compras/${compra.id}',
+              '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/compras/${compra.id}',
             );
           },
           child: Padding(
diff --git a/app/lib/src/features/compras_parcelas/routing/compras_routes.dart b/app/lib/src/features/compras_parcelas/routing/compras_routes.dart
index 43b6eca..b09c4f2 100644
--- a/app/lib/src/features/compras_parcelas/routing/compras_routes.dart
+++ b/app/lib/src/features/compras_parcelas/routing/compras_routes.dart
@@ -14,13 +14,13 @@ abstract class ComprasPaths {
       'obra/:oId/compras/:compraId/editar';
 
   static String listFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/compras';
+      '/construtoras/$cId/obra/$oId/compras';
   static String novaFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/compras/nova';
+      '/construtoras/$cId/obra/$oId/compras/nova';
   static String detalhesFor(String cId, String oId, String compraId) =>
-      '/construtora/$cId/obra/$oId/compras/$compraId';
+      '/construtoras/$cId/obra/$oId/compras/$compraId';
   static String editarFor(String cId, String oId, String compraId) =>
-      '/construtora/$cId/obra/$oId/compras/$compraId/editar';
+      '/construtoras/$cId/obra/$oId/compras/$compraId/editar';
 }
 
 /// Rotas do módulo de compras e parcelas.
diff --git a/app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart b/app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart
index 684e496..204f8b3 100644
--- a/app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart
+++ b/app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart
@@ -65,7 +65,7 @@ class ConstrutorasListScreen extends ConsumerWidget {
               return Card(
                 elevation: 4,
                 child: InkWell(
-                  onTap: () => context.go('/construtora/${construtora.id}'),
+                  onTap: () => context.go('/construtoras/${construtora.id}/loteamentos'),
                   child: Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Column(
diff --git a/app/lib/src/features/construtoras/presentation/membros_screen.dart b/app/lib/src/features/construtoras/presentation/membros_screen.dart
index fa86bbf..84adb01 100644
--- a/app/lib/src/features/construtoras/presentation/membros_screen.dart
+++ b/app/lib/src/features/construtoras/presentation/membros_screen.dart
@@ -166,7 +166,7 @@ class _MembrosScreenState extends ConsumerState<MembrosScreen> {
 
     return SigoLayout(
       title: 'Gestão de Membros',
-      activeRoute: '/construtora/$construtoraId/membros',
+      activeRoute: '/construtoras/$construtoraId/membros',
       actions: [
         IconButton(
           icon: const Icon(Icons.person_add),
diff --git a/app/lib/src/features/construtoras/routing/construtora_routes.dart b/app/lib/src/features/construtoras/routing/construtora_routes.dart
index f4854b7..6d562e4 100644
--- a/app/lib/src/features/construtoras/routing/construtora_routes.dart
+++ b/app/lib/src/features/construtoras/routing/construtora_routes.dart
@@ -21,11 +21,11 @@ import '../../custos_360/routing/custos_360_routes.dart';
 /// Constantes de path para construtoras.
 abstract class ConstrutoraPaths {
   static const list = '/';
-  static const detail = '/construtora/:cId';
+  static const detail = '/construtoras/:cId';
   static const membros = 'membros';
 
-  static String detailFor(String cId) => '/construtora/$cId';
-  static String membrosFor(String cId) => '/construtora/$cId/membros';
+  static String detailFor(String cId) => '/construtoras/$cId';
+  static String membrosFor(String cId) => '/construtoras/$cId/membros';
 }
 
 /// Rotas do módulo de construtoras.
diff --git a/app/lib/src/features/custos_360/presentation/lote_custo_detalhe_screen.dart b/app/lib/src/features/custos_360/presentation/lote_custo_detalhe_screen.dart
index 704673e..6279d16 100644
--- a/app/lib/src/features/custos_360/presentation/lote_custo_detalhe_screen.dart
+++ b/app/lib/src/features/custos_360/presentation/lote_custo_detalhe_screen.dart
@@ -159,7 +159,7 @@ class _LoteCustoDetalheScreenState
 
     return SigoLayout(
       title: titulo,
-      activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/custos-360',
+      activeRoute: '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/custos-360',
       actions: [
         IconButton(
           icon: const Icon(Icons.edit_calendar_outlined),
diff --git a/app/lib/src/features/custos_360/presentation/visao_360_custos_screen.dart b/app/lib/src/features/custos_360/presentation/visao_360_custos_screen.dart
index ed8a19e..d25632e 100644
--- a/app/lib/src/features/custos_360/presentation/visao_360_custos_screen.dart
+++ b/app/lib/src/features/custos_360/presentation/visao_360_custos_screen.dart
@@ -38,7 +38,7 @@ class Visao360CustosScreen extends ConsumerWidget {
 
     return SigoLayout(
       title: 'Visão 360º de Custos',
-      activeRoute: '/construtora/$construtoraId/obra/$obraId/custos-360',
+      activeRoute: '/construtoras/$construtoraId/obra/$obraId/custos-360',
       actions: [
         IconButton(
           icon: const Icon(Icons.refresh),
@@ -384,7 +384,7 @@ class Visao360CustosScreen extends ConsumerWidget {
         borderRadius: BorderRadius.circular(12),
         onTap: () {
           context.go(
-            '/construtora/$construtoraId/obra/$obraId/custos-360/lotes/${lote.loteId}',
+            '/construtoras/$construtoraId/obra/$obraId/custos-360/lotes/${lote.loteId}',
           );
         },
         child: Padding(
diff --git a/app/lib/src/features/custos_360/routing/custos_360_routes.dart b/app/lib/src/features/custos_360/routing/custos_360_routes.dart
index 625f71b..d03300c 100644
--- a/app/lib/src/features/custos_360/routing/custos_360_routes.dart
+++ b/app/lib/src/features/custos_360/routing/custos_360_routes.dart
@@ -11,9 +11,9 @@ abstract class Custos360Paths {
       'obra/:oId/custos-360/lotes/:loteId';
 
   static String visao360For(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/custos-360';
+      '/construtoras/$cId/obra/$oId/custos-360';
   static String loteCustoFor(String cId, String oId, String loteId) =>
-      '/construtora/$cId/obra/$oId/custos-360/lotes/$loteId';
+      '/construtoras/$cId/obra/$oId/custos-360/lotes/$loteId';
 }
 
 /// Rotas do módulo de custos 360.
diff --git a/app/lib/src/features/despesas_adm/presentation/despesa_adm_details_screen.dart b/app/lib/src/features/despesas_adm/presentation/despesa_adm_details_screen.dart
index 47edd70..87b495b 100644
--- a/app/lib/src/features/despesas_adm/presentation/despesa_adm_details_screen.dart
+++ b/app/lib/src/features/despesas_adm/presentation/despesa_adm_details_screen.dart
@@ -69,7 +69,7 @@ class DespesaAdmDetailsScreen extends ConsumerWidget {
 
     return SigoLayout(
       title: 'Detalhes da Despesa',
-      activeRoute: '/construtora/$construtoraId/obra/$obraId/despesas/$despesaId',
+      activeRoute: '/construtoras/$construtoraId/obra/$obraId/despesas/$despesaId',
       actions: [
         despesaAsync.maybeWhen(
           data: (despesa) {
@@ -81,7 +81,7 @@ class DespesaAdmDetailsScreen extends ConsumerWidget {
               tooltip: 'Editar Despesa',
               onPressed: () {
                 context.push(
-                  '/construtora/$construtoraId/obra/$obraId/despesas/$despesaId/editar',
+                  '/construtoras/$construtoraId/obra/$obraId/despesas/$despesaId/editar',
                 );
               },
             );
diff --git a/app/lib/src/features/despesas_adm/presentation/despesa_adm_form_screen.dart b/app/lib/src/features/despesas_adm/presentation/despesa_adm_form_screen.dart
index e8797ac..87dd9a1 100644
--- a/app/lib/src/features/despesas_adm/presentation/despesa_adm_form_screen.dart
+++ b/app/lib/src/features/despesas_adm/presentation/despesa_adm_form_screen.dart
@@ -279,7 +279,7 @@ class _DespesaAdmFormScreenState extends ConsumerState<DespesaAdmFormScreen> {
       title: widget.despesaId != null
           ? 'Editar Despesa'
           : 'Nova Despesa / Conta a Pagar',
-      activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/despesas',
+      activeRoute: '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/despesas',
       child: _isLoading
           ? const Center(child: CircularProgressIndicator())
           : SingleChildScrollView(
diff --git a/app/lib/src/features/despesas_adm/presentation/despesas_adm_list_screen.dart b/app/lib/src/features/despesas_adm/presentation/despesas_adm_list_screen.dart
index d0d8fba..f51874e 100644
--- a/app/lib/src/features/despesas_adm/presentation/despesas_adm_list_screen.dart
+++ b/app/lib/src/features/despesas_adm/presentation/despesas_adm_list_screen.dart
@@ -144,12 +144,12 @@ class _DespesasAdmListScreenState extends ConsumerState<DespesasAdmListScreen> {
 
     return SigoLayout(
       title: 'Módulo ADM — Contas a Pagar',
-      activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/despesas',
+      activeRoute: '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/despesas',
       actions: [
         ElevatedButton.icon(
           onPressed: () {
             context.push(
-              '/construtora/${widget.construtoraId}/obra/${widget.obraId}/despesas/nova',
+              '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/despesas/nova',
             );
           },
           icon: const Icon(Icons.add),
@@ -390,7 +390,7 @@ class _DespesasAdmListScreenState extends ConsumerState<DespesasAdmListScreen> {
                             despesa: d,
                             onTap: () {
                               context.push(
-                                '/construtora/${widget.construtoraId}/obra/${widget.obraId}/despesas/${d.id}',
+                                '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/despesas/${d.id}',
                               );
                             },
                             onLiquidar: () => _abrirModalLiquidacao(d),
diff --git a/app/lib/src/features/despesas_adm/routing/despesas_adm_routes.dart b/app/lib/src/features/despesas_adm/routing/despesas_adm_routes.dart
index 0aeecaf..5d6e083 100644
--- a/app/lib/src/features/despesas_adm/routing/despesas_adm_routes.dart
+++ b/app/lib/src/features/despesas_adm/routing/despesas_adm_routes.dart
@@ -14,13 +14,13 @@ abstract class DespesasAdmPaths {
       'obra/:oId/despesas/:despesaId/editar';
 
   static String listFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/despesas';
+      '/construtoras/$cId/obra/$oId/despesas';
   static String novaFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/despesas/nova';
+      '/construtoras/$cId/obra/$oId/despesas/nova';
   static String detalhesFor(String cId, String oId, String despesaId) =>
-      '/construtora/$cId/obra/$oId/despesas/$despesaId';
+      '/construtoras/$cId/obra/$oId/despesas/$despesaId';
   static String editarFor(String cId, String oId, String despesaId) =>
-      '/construtora/$cId/obra/$oId/despesas/$despesaId/editar';
+      '/construtoras/$cId/obra/$oId/despesas/$despesaId/editar';
 }
 
 /// Rotas do módulo de despesas administrativas.
diff --git a/app/lib/src/features/diario/presentation/add_diario_screen.dart b/app/lib/src/features/diario/presentation/add_diario_screen.dart
index fd9286c..b279b63 100644
--- a/app/lib/src/features/diario/presentation/add_diario_screen.dart
+++ b/app/lib/src/features/diario/presentation/add_diario_screen.dart
@@ -138,7 +138,7 @@ class _AddDiarioScreenState extends ConsumerState<AddDiarioScreen> {
   Widget build(BuildContext context) {
     return SigoLayout(
       title: 'Novo RDO',
-      activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/diarios',
+      activeRoute: '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/diarios',
       child: _isLoading
           ? const Center(child: CircularProgressIndicator())
           : Form(
diff --git a/app/lib/src/features/diario/presentation/diarios_list_screen.dart b/app/lib/src/features/diario/presentation/diarios_list_screen.dart
index 75d7c7a..de70b56 100644
--- a/app/lib/src/features/diario/presentation/diarios_list_screen.dart
+++ b/app/lib/src/features/diario/presentation/diarios_list_screen.dart
@@ -17,16 +17,16 @@ class DiariosListScreen extends ConsumerWidget {
 
     return SigoLayout(
       title: 'Diários de Obra (RDO)',
-      activeRoute: '/construtora/$construtoraId/obra/$obraId/diarios',
+      activeRoute: '/construtoras/$construtoraId/obra/$obraId/diarios',
       actions: [
         IconButton(
           icon: const Icon(Icons.sync),
           tooltip: 'Fila de Sincronização',
-          onPressed: () => context.push('/construtora/$construtoraId/obra/$obraId/diarios/sync'),
+          onPressed: () => context.push('/construtoras/$construtoraId/obra/$obraId/diarios/sync'),
         ),
       ],
       floatingActionButton: FloatingActionButton.extended(
-        onPressed: () => context.go('/construtora/$construtoraId/obra/$obraId/diarios/novo'),
+        onPressed: () => context.go('/construtoras/$construtoraId/obra/$obraId/diarios/novo'),
         icon: const Icon(Icons.add),
         label: const Text('Novo RDO'),
       ),
diff --git a/app/lib/src/features/diario/presentation/sync_queue_screen.dart b/app/lib/src/features/diario/presentation/sync_queue_screen.dart
index 5391b0e..4ec40a8 100644
--- a/app/lib/src/features/diario/presentation/sync_queue_screen.dart
+++ b/app/lib/src/features/diario/presentation/sync_queue_screen.dart
@@ -28,7 +28,7 @@ class SyncQueueScreen extends StatelessWidget {
   @override
   Widget build(BuildContext context) => SigoLayout(
     title: 'Fila deste dispositivo',
-    activeRoute: '/construtora/$construtoraId/obra/$obraId/diarios',
+    activeRoute: '/construtoras/$construtoraId/obra/$obraId/diarios',
     child: StreamBuilder<List<Map<String, dynamic>>>(
       stream: OperationQueue.instance.watch(),
       builder: (context, snapshot) {
diff --git a/app/lib/src/features/diario/routing/diario_routes.dart b/app/lib/src/features/diario/routing/diario_routes.dart
index f893c24..53d0bfc 100644
--- a/app/lib/src/features/diario/routing/diario_routes.dart
+++ b/app/lib/src/features/diario/routing/diario_routes.dart
@@ -12,13 +12,13 @@ abstract class DiarioPaths {
   static const novo = 'obra/:oId/diarios/novo';
   static const sync = 'obra/:oId/diarios/sync';
 
-  static String syncConstrutoraFor(String cId) => '/construtora/$cId/sync';
+  static String syncConstrutoraFor(String cId) => '/construtoras/$cId/sync';
   static String listFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/diarios';
+      '/construtoras/$cId/obra/$oId/diarios';
   static String novoFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/diarios/novo';
+      '/construtoras/$cId/obra/$oId/diarios/novo';
   static String syncFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/diarios/sync';
+      '/construtoras/$cId/obra/$oId/diarios/sync';
 }
 
 /// Rotas do módulo de diário de obra.
diff --git a/app/lib/src/features/epi/presentation/catalogo_epis_screen.dart b/app/lib/src/features/epi/presentation/catalogo_epis_screen.dart
index 12db73e..cbe6f34 100644
--- a/app/lib/src/features/epi/presentation/catalogo_epis_screen.dart
+++ b/app/lib/src/features/epi/presentation/catalogo_epis_screen.dart
@@ -45,7 +45,7 @@ class _CatalogoEpisScreenState extends ConsumerState<CatalogoEpisScreen> {
 
     return SigoLayout(
       title: 'Catálogo de EPIs',
-      activeRoute: '/construtora/${widget.construtoraId}/epis',
+      activeRoute: '/construtoras/${widget.construtoraId}/epis',
       actions: [
         ElevatedButton.icon(
           onPressed: () => _abrirFormulario(),
diff --git a/app/lib/src/features/epi/presentation/entrega_epi_screen.dart b/app/lib/src/features/epi/presentation/entrega_epi_screen.dart
index b037744..69bda63 100644
--- a/app/lib/src/features/epi/presentation/entrega_epi_screen.dart
+++ b/app/lib/src/features/epi/presentation/entrega_epi_screen.dart
@@ -212,7 +212,7 @@ class _EntregaEpiScreenState extends ConsumerState<EntregaEpiScreen> {
 
     return SigoLayout(
       title: 'Entrega de EPI',
-      activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/epis/entrega',
+      activeRoute: '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/epis/entrega',
       child: SingleChildScrollView(
         child: Form(
           key: _formKey,
diff --git a/app/lib/src/features/epi/routing/epi_routes.dart b/app/lib/src/features/epi/routing/epi_routes.dart
index 5a8e5ed..cc4883d 100644
--- a/app/lib/src/features/epi/routing/epi_routes.dart
+++ b/app/lib/src/features/epi/routing/epi_routes.dart
@@ -9,9 +9,9 @@ abstract class EpiPaths {
   static const catalogo = 'epis';
   static const entrega = 'obra/:oId/epis/entrega';
 
-  static String catalogoFor(String cId) => '/construtora/$cId/epis';
+  static String catalogoFor(String cId) => '/construtoras/$cId/epis';
   static String entregaFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/epis/entrega';
+      '/construtoras/$cId/obra/$oId/epis/entrega';
 }
 
 /// Rotas do módulo de EPIs.
diff --git a/app/lib/src/features/equipes/presentation/equipes_list_screen.dart b/app/lib/src/features/equipes/presentation/equipes_list_screen.dart
index 2d8833a..b8e2c63 100644
--- a/app/lib/src/features/equipes/presentation/equipes_list_screen.dart
+++ b/app/lib/src/features/equipes/presentation/equipes_list_screen.dart
@@ -37,7 +37,7 @@ class EquipesListScreen extends ConsumerWidget {
     return SigoLayout(
       title: 'Equipes',
       activeRoute:
-          '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/etapas/$etapaId/equipes',
+          '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/etapas/$etapaId/equipes',
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
diff --git a/app/lib/src/features/etapas/presentation/etapas_list_screen.dart b/app/lib/src/features/etapas/presentation/etapas_list_screen.dart
index 7b60b7b..98555d5 100644
--- a/app/lib/src/features/etapas/presentation/etapas_list_screen.dart
+++ b/app/lib/src/features/etapas/presentation/etapas_list_screen.dart
@@ -32,7 +32,7 @@ class EtapasListScreen extends ConsumerWidget {
     );
     final etapasAsync = ref.watch(watchEtapasProvider(params));
     final baseRoute =
-        '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/etapas';
+        '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/etapas';
 
     return SigoLayout(
       title: 'Etapas',
diff --git a/app/lib/src/features/financeiro/presentation/add_despesa_screen.dart b/app/lib/src/features/financeiro/presentation/add_despesa_screen.dart
index 5d32fde..b8850db 100644
--- a/app/lib/src/features/financeiro/presentation/add_despesa_screen.dart
+++ b/app/lib/src/features/financeiro/presentation/add_despesa_screen.dart
@@ -66,7 +66,7 @@ class _AddDespesaScreenState extends ConsumerState<AddDespesaScreen> {
 
     return SigoLayout(
       title: 'Nova Despesa',
-      activeRoute: '/construtora/${widget.construtoraId}/financeiro',
+      activeRoute: '/construtoras/${widget.construtoraId}/financeiro',
       child: _isLoading
           ? const Center(child: CircularProgressIndicator())
           : Form(
diff --git a/app/lib/src/features/financeiro/presentation/financeiro_list_screen.dart b/app/lib/src/features/financeiro/presentation/financeiro_list_screen.dart
index 8044934..0e073f0 100644
--- a/app/lib/src/features/financeiro/presentation/financeiro_list_screen.dart
+++ b/app/lib/src/features/financeiro/presentation/financeiro_list_screen.dart
@@ -18,10 +18,10 @@ class FinanceiroListScreen extends ConsumerWidget {
 
     return SigoLayout(
       title: 'Contas a Pagar / Financeiro',
-      activeRoute: '/construtora/$construtoraId/financeiro',
+      activeRoute: '/construtoras/$construtoraId/financeiro',
       floatingActionButton: FloatingActionButton.extended(
         onPressed: () =>
-            context.go('/construtora/$construtoraId/financeiro/novo'),
+            context.go('/construtoras/$construtoraId/financeiro/novo'),
         icon: const Icon(Icons.add),
         label: const Text('Nova Despesa'),
       ),
diff --git a/app/lib/src/features/financeiro/routing/financeiro_routes.dart b/app/lib/src/features/financeiro/routing/financeiro_routes.dart
index ac6d6cc..8fe1e98 100644
--- a/app/lib/src/features/financeiro/routing/financeiro_routes.dart
+++ b/app/lib/src/features/financeiro/routing/financeiro_routes.dart
@@ -9,8 +9,8 @@ abstract class FinanceiroPaths {
   static const list = 'financeiro';
   static const novo = 'financeiro/novo';
 
-  static String listFor(String cId) => '/construtora/$cId/financeiro';
-  static String novoFor(String cId) => '/construtora/$cId/financeiro/novo';
+  static String listFor(String cId) => '/construtoras/$cId/financeiro';
+  static String novoFor(String cId) => '/construtoras/$cId/financeiro/novo';
 }
 
 /// Rotas do módulo financeiro.
diff --git a/app/lib/src/features/fornecedores/presentation/fornecedor_form_screen.dart b/app/lib/src/features/fornecedores/presentation/fornecedor_form_screen.dart
index 174bafc..97b5506 100644
--- a/app/lib/src/features/fornecedores/presentation/fornecedor_form_screen.dart
+++ b/app/lib/src/features/fornecedores/presentation/fornecedor_form_screen.dart
@@ -294,7 +294,7 @@ class _FornecedorFormScreenState extends ConsumerState<FornecedorFormScreen> {
 
     return SigoLayout(
       title: isEdicao ? 'Editar Fornecedor' : 'Novo Fornecedor',
-      activeRoute: '/construtora/${widget.construtoraId}/fornecedores',
+      activeRoute: '/construtoras/${widget.construtoraId}/fornecedores',
       child: Form(
         key: _formKey,
         child: SingleChildScrollView(
diff --git a/app/lib/src/features/fornecedores/presentation/fornecedores_list_screen.dart b/app/lib/src/features/fornecedores/presentation/fornecedores_list_screen.dart
index 4a9fc7f..228b79c 100644
--- a/app/lib/src/features/fornecedores/presentation/fornecedores_list_screen.dart
+++ b/app/lib/src/features/fornecedores/presentation/fornecedores_list_screen.dart
@@ -102,12 +102,12 @@ class _FornecedoresListScreenState
 
     return SigoLayout(
       title: 'Catálogo de Fornecedores',
-      activeRoute: '/construtora/${widget.construtoraId}/fornecedores',
+      activeRoute: '/construtoras/${widget.construtoraId}/fornecedores',
       actions: [
         ElevatedButton.icon(
           onPressed: () {
             context.push(
-              '/construtora/${widget.construtoraId}/fornecedores/novo',
+              '/construtoras/${widget.construtoraId}/fornecedores/novo',
             );
           },
           icon: const Icon(Icons.add_business),
@@ -274,7 +274,7 @@ class _FornecedoresListScreenState
                         ElevatedButton.icon(
                           onPressed: () {
                             context.push(
-                              '/construtora/${widget.construtoraId}/fornecedores/novo',
+                              '/construtoras/${widget.construtoraId}/fornecedores/novo',
                             );
                           },
                           icon: const Icon(Icons.add),
@@ -571,7 +571,7 @@ class _FornecedoresListScreenState
                 ElevatedButton.icon(
                   onPressed: () {
                     context.push(
-                      '/construtora/${widget.construtoraId}/fornecedores/${f.id}/editar',
+                      '/construtoras/${widget.construtoraId}/fornecedores/${f.id}/editar',
                     );
                   },
                   icon: const Icon(Icons.edit_outlined, size: 16),
diff --git a/app/lib/src/features/fornecedores/presentation/widgets/fornecedor_autocomplete_field.dart b/app/lib/src/features/fornecedores/presentation/widgets/fornecedor_autocomplete_field.dart
index 2b7c11d..60ed331 100644
--- a/app/lib/src/features/fornecedores/presentation/widgets/fornecedor_autocomplete_field.dart
+++ b/app/lib/src/features/fornecedores/presentation/widgets/fornecedor_autocomplete_field.dart
@@ -97,7 +97,7 @@ class FornecedorAutocompleteField extends ConsumerWidget {
                   tooltip: 'Cadastrar Novo Fornecedor',
                   onPressed: () {
                     context.push(
-                      '/construtora/$construtoraId/fornecedores/novo',
+                      '/construtoras/$construtoraId/fornecedores/novo',
                     );
                   },
                 ),
diff --git a/app/lib/src/features/fornecedores/routing/fornecedores_routes.dart b/app/lib/src/features/fornecedores/routing/fornecedores_routes.dart
index 5331a22..fe01f56 100644
--- a/app/lib/src/features/fornecedores/routing/fornecedores_routes.dart
+++ b/app/lib/src/features/fornecedores/routing/fornecedores_routes.dart
@@ -10,10 +10,10 @@ abstract class FornecedoresPaths {
   static const novo = 'fornecedores/novo';
   static const editar = 'fornecedores/:fornecedorId/editar';
 
-  static String listFor(String cId) => '/construtora/$cId/fornecedores';
-  static String novoFor(String cId) => '/construtora/$cId/fornecedores/novo';
+  static String listFor(String cId) => '/construtoras/$cId/fornecedores';
+  static String novoFor(String cId) => '/construtoras/$cId/fornecedores/novo';
   static String editarFor(String cId, String fornecedorId) =>
-      '/construtora/$cId/fornecedores/$fornecedorId/editar';
+      '/construtoras/$cId/fornecedores/$fornecedorId/editar';
 }
 
 /// Rotas do módulo de fornecedores.
diff --git a/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart b/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart
index 005a05c..1ea4564 100644
--- a/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart
+++ b/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart
@@ -22,7 +22,7 @@ class LoteamentosListScreen extends ConsumerWidget {
 
     return SigoLayout(
       title: 'Loteamentos',
-      activeRoute: '/construtora/$construtoraId/loteamentos',
+      activeRoute: '/construtoras/$construtoraId/loteamentos',
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
@@ -52,7 +52,7 @@ class LoteamentosListScreen extends ConsumerWidget {
                       trailing: const Icon(Icons.arrow_forward_ios),
                       onTap: () {
                         context.go(
-                          '/construtora/$construtoraId/loteamentos/${item.id}/quadras',
+                          '/construtoras/$construtoraId/loteamentos/${item.id}/quadras',
                         );
                       },
                     );
diff --git a/app/lib/src/features/lotes/presentation/add_lote_screen.dart b/app/lib/src/features/lotes/presentation/add_lote_screen.dart
index 327b088..605dfc1 100644
--- a/app/lib/src/features/lotes/presentation/add_lote_screen.dart
+++ b/app/lib/src/features/lotes/presentation/add_lote_screen.dart
@@ -75,7 +75,7 @@ class _AddLoteScreenState extends ConsumerState<AddLoteScreen> {
   Widget build(BuildContext context) {
     return SigoLayout(
       title: 'Novo Lote',
-      activeRoute: '/construtora/${widget.construtoraId}/loteamentos/${widget.loteamentoId}/quadras/${widget.quadraId}/lotes',
+      activeRoute: '/construtoras/${widget.construtoraId}/loteamentos/${widget.loteamentoId}/quadras/${widget.quadraId}/lotes',
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Form(
diff --git a/app/lib/src/features/lotes/presentation/lotes_list_screen.dart b/app/lib/src/features/lotes/presentation/lotes_list_screen.dart
index 511206f..99639ad 100644
--- a/app/lib/src/features/lotes/presentation/lotes_list_screen.dart
+++ b/app/lib/src/features/lotes/presentation/lotes_list_screen.dart
@@ -34,7 +34,7 @@ class LotesListScreen extends ConsumerWidget {
         (member?['isAdmin'] == true || member?['isOwner'] == true);
 
     final baseRoute =
-        '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes';
+        '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes';
 
     return SigoLayout(
       title: 'Lotes',
diff --git a/app/lib/src/features/obras/presentation/obra_dashboard_screen.dart b/app/lib/src/features/obras/presentation/obra_dashboard_screen.dart
index 23156ff..fe75f0b 100644
--- a/app/lib/src/features/obras/presentation/obra_dashboard_screen.dart
+++ b/app/lib/src/features/obras/presentation/obra_dashboard_screen.dart
@@ -85,8 +85,8 @@ class ObraDashboardScreen extends ConsumerWidget {
         }
 
         return SigoLayout(
-          title: 'Painel da Obra',
-          activeRoute: '/construtora/$construtoraId/obra/$obraId',
+          title: 'Painel do Loteamento',
+          activeRoute: '/construtoras/$construtoraId/obra/$obraId',
           child: SingleChildScrollView(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
@@ -116,7 +116,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                       member.isAdmin ? 'Nível: Administrador' : 'Nível: Membro',
                       style: const TextStyle(fontWeight: FontWeight.bold),
                     ),
-                    subtitle: Text('ID da Obra: $obraId'),
+                    subtitle: Text('ID do Loteamento: $obraId'),
                   ),
                 ),
                 const SizedBox(height: 28),
@@ -143,9 +143,9 @@ class ObraDashboardScreen extends ConsumerWidget {
                     if (canCentralLotes)
                       SigoModuleCard(
                         icon: Icons.map,
-                        title: 'Lotes e Setores',
+                        title: 'Loteamentos',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/loteamentos',
+                          '/construtoras/$construtoraId/loteamentos',
                         ),
                       ),
                     if (member.isAdmin ||
@@ -154,7 +154,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                         icon: Icons.assignment,
                         title: 'Diário de Obra',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/obra/$obraId/diarios',
+                          '/construtoras/$construtoraId/obra/$obraId/diarios',
                         ),
                       ),
                     if (canValidacao)
@@ -162,7 +162,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                         icon: Icons.rule,
                         title: 'Validação & Qualidade',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/validacao/templates',
+                          '/construtoras/$construtoraId/validacao/templates',
                         ),
                       ),
                   ],
@@ -193,7 +193,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                         icon: Icons.playlist_add_check,
                         title: 'Chamada Diária (RH)',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/obra/$obraId/rh/chamadas',
+                          '/construtoras/$construtoraId/obra/$obraId/rh/chamadas',
                         ),
                       ),
                     if (canEpi)
@@ -201,7 +201,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                         icon: Icons.health_and_safety,
                         title: 'Entrega de EPIs',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/obra/$obraId/epis/entrega',
+                          '/construtoras/$construtoraId/obra/$obraId/epis/entrega',
                         ),
                       ),
                   ],
@@ -232,7 +232,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                         icon: Icons.receipt_long,
                         title: 'Contas a Pagar / ADM',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/obra/$obraId/despesas',
+                          '/construtoras/$construtoraId/obra/$obraId/despesas',
                         ),
                       ),
                     if (canCompras)
@@ -240,7 +240,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                         icon: Icons.shopping_cart_outlined,
                         title: 'Compras e NF',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/obra/$obraId/compras',
+                          '/construtoras/$construtoraId/obra/$obraId/compras',
                         ),
                       ),
                     if (canAdm || canFinanceiro)
@@ -248,7 +248,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                         icon: Icons.query_stats_rounded,
                         title: 'Visão 360 Custos',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/obra/$obraId/custos-360',
+                          '/construtoras/$construtoraId/obra/$obraId/custos-360',
                         ),
                       ),
                     if (canEstoque)
@@ -256,7 +256,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                         icon: Icons.inventory_2,
                         title: 'Almoxarifado',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/almoxarifado',
+                          '/construtoras/$construtoraId/almoxarifado',
                         ),
                       ),
                     if (canFinanceiro)
@@ -264,7 +264,7 @@ class ObraDashboardScreen extends ConsumerWidget {
                         icon: Icons.account_balance_wallet,
                         title: 'Financeiro',
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/financeiro',
+                          '/construtoras/$construtoraId/financeiro',
                         ),
                       ),
                   ],
diff --git a/app/lib/src/features/obras/presentation/obras_list_screen.dart b/app/lib/src/features/obras/presentation/obras_list_screen.dart
index ecd7e0e..295afb4 100644
--- a/app/lib/src/features/obras/presentation/obras_list_screen.dart
+++ b/app/lib/src/features/obras/presentation/obras_list_screen.dart
@@ -80,12 +80,12 @@ class ObrasListScreen extends ConsumerWidget {
 
     return SigoLayout(
       title: 'Painel da Construtora',
-      activeRoute: '/construtora/$construtoraId',
+      activeRoute: '/construtoras/$construtoraId',
       actions: [
         if (admin)
           IconButton(
             icon: const Icon(Icons.add_business, color: Colors.black54),
-            tooltip: 'Nova Obra',
+            tooltip: 'Novo Loteamento',
             onPressed: () {
               showDialog(
                 context: context,
@@ -98,7 +98,7 @@ class ObrasListScreen extends ConsumerWidget {
             icon: const Icon(Icons.people, color: Colors.black54),
             tooltip: 'Gerenciar Membros',
             onPressed: () {
-              context.go('/construtora/$construtoraId/membros');
+              context.go('/construtoras/$construtoraId/membros');
             },
           ),
         if (canViewLoteamentos)
@@ -106,7 +106,7 @@ class ObrasListScreen extends ConsumerWidget {
             icon: const Icon(Icons.map_outlined, color: Colors.black54),
             tooltip: 'Loteamentos',
             onPressed: () {
-              context.go('/construtora/$construtoraId/loteamentos');
+              context.go('/construtoras/$construtoraId/loteamentos');
             },
           ),
         if (hasRh)
@@ -114,7 +114,7 @@ class ObrasListScreen extends ConsumerWidget {
             icon: const Icon(Icons.badge, color: Colors.black54),
             tooltip: 'Recursos Humanos (RH)',
             onPressed: () {
-              context.go('/construtora/$construtoraId/rh');
+              context.go('/construtoras/$construtoraId/rh');
             },
           ),
         if (stock)
@@ -122,7 +122,7 @@ class ObrasListScreen extends ConsumerWidget {
             icon: const Icon(Icons.inventory_2, color: Colors.black54),
             tooltip: 'Almoxarifado Global',
             onPressed: () {
-              context.go('/construtora/$construtoraId/almoxarifado');
+              context.go('/construtoras/$construtoraId/almoxarifado');
             },
           ),
         if (admin)
@@ -133,7 +133,7 @@ class ObrasListScreen extends ConsumerWidget {
             ),
             tooltip: 'Financeiro Global',
             onPressed: () {
-              context.go('/construtora/$construtoraId/financeiro');
+              context.go('/construtoras/$construtoraId/financeiro');
             },
           ),
         if (hasValidacao)
@@ -141,7 +141,7 @@ class ObrasListScreen extends ConsumerWidget {
             icon: const Icon(Icons.rule, color: Colors.black54),
             tooltip: 'Templates de Validação',
             onPressed: () {
-              context.go('/construtora/$construtoraId/validacao/templates');
+              context.go('/construtoras/$construtoraId/validacao/templates');
             },
           ),
         if (hasEpi)
@@ -149,7 +149,7 @@ class ObrasListScreen extends ConsumerWidget {
             icon: const Icon(Icons.health_and_safety, color: Colors.black54),
             tooltip: 'Catálogo de EPIs',
             onPressed: () {
-              context.go('/construtora/$construtoraId/epis');
+              context.go('/construtoras/$construtoraId/epis');
             },
           ),
         if (hasFornecedores)
@@ -157,7 +157,7 @@ class ObrasListScreen extends ConsumerWidget {
             icon: const Icon(Icons.storefront, color: Colors.black54),
             tooltip: 'Fornecedores',
             onPressed: () {
-              context.go('/construtora/$construtoraId/fornecedores');
+              context.go('/construtoras/$construtoraId/fornecedores');
             },
           ),
       ],
@@ -171,7 +171,7 @@ class ObrasListScreen extends ConsumerWidget {
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Text(
-                    'Nenhuma obra encontrada para você nesta construtora.',
+                    'Nenhum loteamento encontrado para você nesta construtora.',
                     textAlign: TextAlign.center,
                   ),
                   if (admin) ...[
@@ -185,7 +185,7 @@ class ObrasListScreen extends ConsumerWidget {
                         );
                       },
                       icon: const Icon(Icons.add),
-                      label: const Text('Criar Nova Obra'),
+                      label: const Text('Criar Novo Loteamento'),
                     ),
                   ],
                 ],
@@ -284,7 +284,7 @@ class ObrasListScreen extends ConsumerWidget {
                       elevation: 4,
                       child: InkWell(
                         onTap: () => context.go(
-                          '/construtora/$construtoraId/obra/${obra.id}',
+                          '/construtoras/$construtoraId/obra/${obra.id}',
                         ),
                         child: Padding(
                           padding: const EdgeInsets.all(16.0),
@@ -367,13 +367,13 @@ class _AddObraDialogState extends ConsumerState<_AddObraDialog> {
       if (mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
-          const SnackBar(content: Text('Obra cadastrada com sucesso!')),
+          const SnackBar(content: Text('Loteamento cadastrado com sucesso!')),
         );
       }
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
-          SnackBar(content: Text('Erro ao cadastrar obra: $e')),
+          SnackBar(content: Text('Erro ao cadastrar loteamento: $e')),
         );
       }
     } finally {
@@ -384,7 +384,7 @@ class _AddObraDialogState extends ConsumerState<_AddObraDialog> {
   @override
   Widget build(BuildContext context) {
     return AlertDialog(
-      title: const Text('Nova Obra'),
+      title: const Text('Novo Loteamento'),
       content: SizedBox(
         width: 450,
         child: Form(
@@ -396,7 +396,7 @@ class _AddObraDialogState extends ConsumerState<_AddObraDialog> {
                 TextFormField(
                   controller: _nameController,
                   decoration: const InputDecoration(
-                    labelText: 'Nome da Obra *',
+                    labelText: 'Nome do Loteamento *',
                     hintText: 'Ex: Residencial Flores',
                   ),
                   autofocus: true,
diff --git a/app/lib/src/features/obras/routing/obra_routes.dart b/app/lib/src/features/obras/routing/obra_routes.dart
index 297006a..ed7d16c 100644
--- a/app/lib/src/features/obras/routing/obra_routes.dart
+++ b/app/lib/src/features/obras/routing/obra_routes.dart
@@ -8,7 +8,7 @@ abstract class ObraPaths {
   static const dashboard = 'obra/:oId';
 
   static String dashboardFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId';
+      '/construtoras/$cId/obra/$oId';
 }
 
 /// Rotas do módulo de obras.
diff --git a/app/lib/src/features/quadras/presentation/quadras_list_screen.dart b/app/lib/src/features/quadras/presentation/quadras_list_screen.dart
index 90fd412..f315a4e 100644
--- a/app/lib/src/features/quadras/presentation/quadras_list_screen.dart
+++ b/app/lib/src/features/quadras/presentation/quadras_list_screen.dart
@@ -25,7 +25,7 @@ class QuadrasListScreen extends ConsumerWidget {
     return SigoLayout(
       title: 'Quadras',
       activeRoute:
-          '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras',
+          '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras',
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
@@ -55,7 +55,7 @@ class QuadrasListScreen extends ConsumerWidget {
                       trailing: const Icon(Icons.arrow_forward_ios),
                       onTap: () {
                         context.go(
-                          '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/${item.id}/lotes',
+                          '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/${item.id}/lotes',
                         );
                       },
                     );
diff --git a/app/lib/src/features/rh/presentation/chamada_form_screen.dart b/app/lib/src/features/rh/presentation/chamada_form_screen.dart
index 4d4fd48..f8ab5e8 100644
--- a/app/lib/src/features/rh/presentation/chamada_form_screen.dart
+++ b/app/lib/src/features/rh/presentation/chamada_form_screen.dart
@@ -119,7 +119,7 @@ class _ChamadaFormScreenState extends ConsumerState<ChamadaFormScreen> {
             textColor: Colors.white,
             onPressed: () {
               context.pushReplacement(
-                '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/${existing.id}',
+                '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/${existing.id}',
               );
             },
           ),
@@ -515,7 +515,7 @@ class _ChamadaFormScreenState extends ConsumerState<ChamadaFormScreen> {
 
             return ChamadaFormView(
               activeRoute:
-                  '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas',
+                  '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas',
               existingChamada: _existingChamada,
               selectedDate: _selectedDate,
               formattedDate: _formattedDate,
diff --git a/app/lib/src/features/rh/presentation/chamadas_list_screen.dart b/app/lib/src/features/rh/presentation/chamadas_list_screen.dart
index 24867fe..9fd6fd1 100644
--- a/app/lib/src/features/rh/presentation/chamadas_list_screen.dart
+++ b/app/lib/src/features/rh/presentation/chamadas_list_screen.dart
@@ -39,13 +39,13 @@ class _ChamadasListScreenState extends ConsumerState<ChamadasListScreen> {
 
     return SigoLayout(
       title: 'Chamada Diária (RH)',
-      activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas',
+      activeRoute: '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas',
       actions: [
         IconButton(
           icon: const Icon(Icons.add),
           tooltip: 'Nova Chamada',
           onPressed: () => context.push(
-            '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/nova',
+            '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/nova',
           ),
         ),
       ],
@@ -53,7 +53,7 @@ class _ChamadasListScreenState extends ConsumerState<ChamadasListScreen> {
         icon: const Icon(Icons.playlist_add_check),
         label: const Text('Nova Chamada'),
         onPressed: () => context.push(
-          '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/nova',
+          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/nova',
         ),
       ),
       child: Column(
@@ -126,7 +126,7 @@ class _ChamadasListScreenState extends ConsumerState<ChamadasListScreen> {
                             icon: const Icon(Icons.add),
                             label: const Text('Lançar Chamada de Hoje'),
                             onPressed: () => context.push(
-                              '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/nova',
+                              '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/nova',
                             ),
                           ),
                         ],
@@ -143,7 +143,7 @@ class _ChamadasListScreenState extends ConsumerState<ChamadasListScreen> {
                     return _ChamadaCard(
                       chamada: chamada,
                       onTap: () => context.push(
-                        '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/${chamada.id}',
+                        '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/${chamada.id}',
                       ),
                     );
                   },
diff --git a/app/lib/src/features/rh/presentation/funcionario_form_screen.dart b/app/lib/src/features/rh/presentation/funcionario_form_screen.dart
index 470710b..7096606 100644
--- a/app/lib/src/features/rh/presentation/funcionario_form_screen.dart
+++ b/app/lib/src/features/rh/presentation/funcionario_form_screen.dart
@@ -187,7 +187,7 @@ class _FuncionarioFormScreenState extends ConsumerState<FuncionarioFormScreen> {
       final listAsync = ref.watch(funcionariosStreamProvider(widget.construtoraId));
       return SigoLayout(
         title: isEditing ? 'Editar Colaborador' : 'Novo Colaborador',
-        activeRoute: '/construtora/${widget.construtoraId}/rh/funcionarios',
+        activeRoute: '/construtoras/${widget.construtoraId}/rh/funcionarios',
         child: listAsync.when(
           loading: () => const Center(child: CircularProgressIndicator()),
           error: (e, _) => Center(child: Text('Erro ao carregar dados: $e')),
@@ -218,7 +218,7 @@ class _FuncionarioFormScreenState extends ConsumerState<FuncionarioFormScreen> {
 
     return SigoLayout(
       title: isEditing ? 'Editar Colaborador' : 'Novo Colaborador',
-      activeRoute: '/construtora/${widget.construtoraId}/rh/funcionarios',
+      activeRoute: '/construtoras/${widget.construtoraId}/rh/funcionarios',
       child: SingleChildScrollView(
         padding: const EdgeInsets.all(24),
         child: Center(
diff --git a/app/lib/src/features/rh/presentation/funcionarios_list_screen.dart b/app/lib/src/features/rh/presentation/funcionarios_list_screen.dart
index e17efff..90b44d0 100644
--- a/app/lib/src/features/rh/presentation/funcionarios_list_screen.dart
+++ b/app/lib/src/features/rh/presentation/funcionarios_list_screen.dart
@@ -40,7 +40,7 @@ class _FuncionariosListScreenState
 
     return SigoLayout(
       title: 'Recursos Humanos — Funcionários',
-      activeRoute: '/construtora/${widget.construtoraId}/rh',
+      activeRoute: '/construtoras/${widget.construtoraId}/rh',
       actions: [
         IconButton(
           key: const Key('btn_open_equipes'),
@@ -60,7 +60,7 @@ class _FuncionariosListScreenState
           tooltip: 'Novo Funcionário',
           onPressed: () {
             context.push(
-              '/construtora/${widget.construtoraId}/rh/funcionarios/novo',
+              '/construtoras/${widget.construtoraId}/rh/funcionarios/novo',
             );
           },
         ),
@@ -69,7 +69,7 @@ class _FuncionariosListScreenState
         key: const Key('btn_add_funcionario_fab'),
         onPressed: () {
           context.push(
-            '/construtora/${widget.construtoraId}/rh/funcionarios/novo',
+            '/construtoras/${widget.construtoraId}/rh/funcionarios/novo',
           );
         },
         icon: const Icon(Icons.add),
diff --git a/app/lib/src/features/rh/routing/rh_routes.dart b/app/lib/src/features/rh/routing/rh_routes.dart
index b3a3e0e..c0bd578 100644
--- a/app/lib/src/features/rh/routing/rh_routes.dart
+++ b/app/lib/src/features/rh/routing/rh_routes.dart
@@ -18,19 +18,19 @@ abstract class RhPaths {
   static const editarChamada =
       'obra/:oId/rh/chamadas/:chId';
 
-  static String rhFor(String cId) => '/construtora/$cId/rh';
+  static String rhFor(String cId) => '/construtoras/$cId/rh';
   static String funcionariosFor(String cId) =>
-      '/construtora/$cId/rh/funcionarios';
+      '/construtoras/$cId/rh/funcionarios';
   static String novoFuncionarioFor(String cId) =>
-      '/construtora/$cId/rh/funcionarios/novo';
+      '/construtoras/$cId/rh/funcionarios/novo';
   static String editarFuncionarioFor(String cId, String fId) =>
-      '/construtora/$cId/rh/funcionarios/$fId/editar';
+      '/construtoras/$cId/rh/funcionarios/$fId/editar';
   static String chamadasFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/rh/chamadas';
+      '/construtoras/$cId/obra/$oId/rh/chamadas';
   static String novaChamadaFor(String cId, String oId) =>
-      '/construtora/$cId/obra/$oId/rh/chamadas/nova';
+      '/construtoras/$cId/obra/$oId/rh/chamadas/nova';
   static String editarChamadaFor(String cId, String oId, String chId) =>
-      '/construtora/$cId/obra/$oId/rh/chamadas/$chId';
+      '/construtoras/$cId/obra/$oId/rh/chamadas/$chId';
 }
 
 /// Rotas do módulo de RH (funcionários + chamadas).
diff --git a/app/lib/src/features/validacao/presentation/lote_validacoes_screen.dart b/app/lib/src/features/validacao/presentation/lote_validacoes_screen.dart
index 0ebc126..0ab150c 100644
--- a/app/lib/src/features/validacao/presentation/lote_validacoes_screen.dart
+++ b/app/lib/src/features/validacao/presentation/lote_validacoes_screen.dart
@@ -187,12 +187,12 @@ class LoteValidacoesScreen extends ConsumerWidget {
 
     return SigoLayout(
       title: 'Validação & Qualidade do Lote',
-      activeRoute: '/construtora/$construtoraId/obra/$obraId/lotes/$loteId/validacoes',
+      activeRoute: '/construtoras/$construtoraId/obra/$obraId/lotes/$loteId/validacoes',
       actions: [
         ElevatedButton.icon(
           onPressed: () {
             context.go(
-              '/construtora/$construtoraId/obra/$obraId/lotes/$loteId/validacoes/nova',
+              '/construtoras/$construtoraId/obra/$obraId/lotes/$loteId/validacoes/nova',
             );
           },
           icon: const Icon(Icons.playlist_add),
@@ -207,7 +207,7 @@ class LoteValidacoesScreen extends ConsumerWidget {
               IconButton(
                 icon: const Icon(Icons.arrow_back),
                 onPressed: () {
-                  context.go('/construtora/$construtoraId/obra/$obraId');
+                  context.go('/construtoras/$construtoraId/obra/$obraId');
                 },
                 tooltip: 'Voltar aos Lotes',
               ),
@@ -257,7 +257,7 @@ class LoteValidacoesScreen extends ConsumerWidget {
                               ElevatedButton.icon(
                                 onPressed: () {
                                   context.go(
-                                    '/construtora/$construtoraId/obra/$obraId/lotes/$loteId/validacoes/nova',
+                                    '/construtoras/$construtoraId/obra/$obraId/lotes/$loteId/validacoes/nova',
                                   );
                                 },
                                 icon: const Icon(Icons.add_task),
@@ -285,7 +285,7 @@ class LoteValidacoesScreen extends ConsumerWidget {
                                 borderRadius: BorderRadius.circular(12),
                                 onTap: () {
                                   context.go(
-                                    '/construtora/$construtoraId/obra/$obraId/lotes/$loteId/validacoes/${vistoria.id}',
+                                    '/construtoras/$construtoraId/obra/$obraId/lotes/$loteId/validacoes/${vistoria.id}',
                                   );
                                 },
                                 child: Padding(
diff --git a/app/lib/src/features/validacao/presentation/templates_list_screen.dart b/app/lib/src/features/validacao/presentation/templates_list_screen.dart
index 8bb2971..5de755e 100644
--- a/app/lib/src/features/validacao/presentation/templates_list_screen.dart
+++ b/app/lib/src/features/validacao/presentation/templates_list_screen.dart
@@ -38,7 +38,7 @@ class _TemplatesListScreenState extends ConsumerState<TemplatesListScreen> {
 
     return SigoLayout(
       title: 'Templates de Validação & Qualidade',
-      activeRoute: '/construtora/${widget.construtoraId}/validacao/templates',
+      activeRoute: '/construtoras/${widget.construtoraId}/validacao/templates',
       actions: [
         ElevatedButton.icon(
           onPressed: () => _abrirDialogTemplate(),
diff --git a/app/lib/src/features/validacao/presentation/validacao_form_screen.dart b/app/lib/src/features/validacao/presentation/validacao_form_screen.dart
index bc6cba6..209280b 100644
--- a/app/lib/src/features/validacao/presentation/validacao_form_screen.dart
+++ b/app/lib/src/features/validacao/presentation/validacao_form_screen.dart
@@ -270,7 +270,7 @@ class _ValidacaoFormScreenState extends ConsumerState<ValidacaoFormScreen> {
           ),
         );
         context.go(
-          '/construtora/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
+          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
         );
       }
     } catch (e) {
@@ -360,7 +360,7 @@ class _ValidacaoFormScreenState extends ConsumerState<ValidacaoFormScreen> {
           ),
         );
         context.go(
-          '/construtora/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
+          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
         );
       }
     } catch (e) {
@@ -428,7 +428,7 @@ class _ValidacaoFormScreenState extends ConsumerState<ValidacaoFormScreen> {
               icon: const Icon(Icons.arrow_back),
               onPressed: () {
                 context.go(
-                  '/construtora/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
+                  '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
                 );
               },
             ),
@@ -468,7 +468,7 @@ class _ValidacaoFormScreenState extends ConsumerState<ValidacaoFormScreen> {
                       ElevatedButton(
                         onPressed: () {
                           context.go(
-                            '/construtora/${widget.construtoraId}/validacao/templates',
+                            '/construtoras/${widget.construtoraId}/validacao/templates',
                           );
                         },
                         child: const Text('Ir para Templates de Validação'),
@@ -530,7 +530,7 @@ class _ValidacaoFormScreenState extends ConsumerState<ValidacaoFormScreen> {
               icon: const Icon(Icons.arrow_back),
               onPressed: () {
                 context.go(
-                  '/construtora/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
+                  '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
                 );
               },
             ),
@@ -941,7 +941,7 @@ class _ValidacaoFormScreenState extends ConsumerState<ValidacaoFormScreen> {
     return SigoLayout(
       title: 'Vistoria de Validação',
       activeRoute:
-          '/construtora/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
+          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
       child: _carregando
           ? const Center(child: CircularProgressIndicator())
           : _erroCarregamento != null
diff --git a/app/lib/src/features/validacao/routing/validacao_routes.dart b/app/lib/src/features/validacao/routing/validacao_routes.dart
index a9672cb..c938209 100644
--- a/app/lib/src/features/validacao/routing/validacao_routes.dart
+++ b/app/lib/src/features/validacao/routing/validacao_routes.dart
@@ -16,14 +16,14 @@ abstract class ValidacaoPaths {
       'obra/:oId/lotes/:loteId/validacoes/:validacaoId';
 
   static String templatesFor(String cId) =>
-      '/construtora/$cId/validacao/templates';
+      '/construtoras/$cId/validacao/templates';
   static String loteValidacoesFor(String cId, String oId, String loteId) =>
-      '/construtora/$cId/obra/$oId/lotes/$loteId/validacoes';
+      '/construtoras/$cId/obra/$oId/lotes/$loteId/validacoes';
   static String novaValidacaoFor(String cId, String oId, String loteId) =>
-      '/construtora/$cId/obra/$oId/lotes/$loteId/validacoes/nova';
+      '/construtoras/$cId/obra/$oId/lotes/$loteId/validacoes/nova';
   static String editarValidacaoFor(
           String cId, String oId, String loteId, String validacaoId) =>
-      '/construtora/$cId/obra/$oId/lotes/$loteId/validacoes/$validacaoId';
+      '/construtoras/$cId/obra/$oId/lotes/$loteId/validacoes/$validacaoId';
 }
 
 /// Rotas do módulo de validação.
diff --git a/app/lib/src/routing/app_router.dart b/app/lib/src/routing/app_router.dart
index cdb3b15..ba5ee9c 100644
--- a/app/lib/src/routing/app_router.dart
+++ b/app/lib/src/routing/app_router.dart
@@ -55,6 +55,10 @@ final routerProvider = Provider<GoRouter>((ref) {
         }
       }
 
+      if (state.uri.path.startsWith('/construtora/')) {
+        return state.uri.replace(path: state.uri.path.replaceFirst('/construtora/', '/construtoras/')).toString();
+      }
+
       return null;
     },
     routes: [
diff --git a/app/lib/src/sync/sync_indicator.dart b/app/lib/src/sync/sync_indicator.dart
index e0a3167..0de6091 100644
--- a/app/lib/src/sync/sync_indicator.dart
+++ b/app/lib/src/sync/sync_indicator.dart
@@ -366,9 +366,9 @@ Future<void> showSyncStatusDialog({
                   onPressed: () {
                     Navigator.of(dialogContext).pop();
                     if (obraId != null && obraId.isNotEmpty) {
-                      context.go('/construtora/$construtoraId/obra/$obraId/diarios/sync');
+                      context.go('/construtoras/$construtoraId/obra/$obraId/diarios/sync');
                     } else {
-                      context.go('/construtora/$construtoraId/sync');
+                      context.go('/construtoras/$construtoraId/sync');
                     }
                   },
                 ),
diff --git a/app/test/loteamento_quadra_lote_navigation_test.dart b/app/test/loteamento_quadra_lote_navigation_test.dart
index 1fa6e64..ba84d4f 100644
--- a/app/test/loteamento_quadra_lote_navigation_test.dart
+++ b/app/test/loteamento_quadra_lote_navigation_test.dart
@@ -164,10 +164,10 @@ void main() {
   testWidgets('LoteamentosListScreen navega para a lista de quadras',
       (tester) async {
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos',
+      initialLocation: '/construtoras/c1/loteamentos',
       routes: [
         GoRoute(
-          path: '/construtora/:cId/loteamentos',
+          path: '/construtoras/:cId/loteamentos',
           builder: (context, state) => LoteamentosListScreen(
             construtoraId: state.pathParameters['cId']!,
           ),
@@ -207,10 +207,10 @@ void main() {
 
   testWidgets('QuadrasListScreen navega para a lista de lotes', (tester) async {
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1/quadras',
+      initialLocation: '/construtoras/c1/loteamentos/l1/quadras',
       routes: [
         GoRoute(
-          path: '/construtora/:cId/loteamentos/:loteamentoId/quadras',
+          path: '/construtoras/:cId/loteamentos/:loteamentoId/quadras',
           builder: (context, state) => QuadrasListScreen(
             construtoraId: state.pathParameters['cId']!,
             loteamentoId: state.pathParameters['loteamentoId']!,
@@ -254,7 +254,7 @@ void main() {
       'rotas reais aninhadas renderizam breadcrumbs e crumb-pai ascende para a lista',
       (tester) async {
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
       routes: construtoraRoutes,
     );
 
@@ -302,13 +302,13 @@ void main() {
     expect(find.text('Quadra q1'), findsOneWidget);
     expect(
       router.state.uri.path,
-      '/construtora/c1/loteamentos/l1/quadras',
+      '/construtoras/c1/loteamentos/l1/quadras',
     );
   });
 
   testWidgets('crumb raiz ascende para a lista de loteamentos', (tester) async {
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
       routes: construtoraRoutes,
     );
 
@@ -338,14 +338,14 @@ void main() {
     expect(find.byType(LoteamentosListScreen), findsOneWidget);
     expect(
       router.state.uri.path,
-      '/construtora/c1/loteamentos',
+      '/construtoras/c1/loteamentos',
     );
   });
 
   testWidgets('deep-link em :loteId redireciona para a lista de etapas',
       (tester) async {
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1',
+      initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1',
       routes: construtoraRoutes,
     );
 
@@ -367,7 +367,7 @@ void main() {
     expect(find.text('Etapa e1'), findsOneWidget);
     expect(
       router.state.uri.path,
-      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas',
+      '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas',
     );
   });
 
@@ -375,7 +375,7 @@ void main() {
       (tester) async {
     final router = GoRouter(
       initialLocation:
-          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/e1',
+          '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/e1',
       routes: construtoraRoutes,
     );
 
@@ -398,14 +398,14 @@ void main() {
     expect(find.text('Equipe e1'), findsOneWidget);
     expect(
       router.state.uri.path,
-      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/e1/equipes',
+      '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/e1/equipes',
     );
   });
 
   testWidgets('crumb de Etapa ascende para a lista de etapas', (tester) async {
     final router = GoRouter(
       initialLocation:
-          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/e1/equipes',
+          '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/e1/equipes',
       routes: construtoraRoutes,
     );
 
@@ -433,14 +433,14 @@ void main() {
     expect(find.byType(EtapasListScreen), findsOneWidget);
     expect(
       router.state.uri.path,
-      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas',
+      '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas',
     );
   });
 
   testWidgets('deep-link em :loteamentoId redireciona para a lista de quadras',
       (tester) async {
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1',
+      initialLocation: '/construtoras/c1/loteamentos/l1',
       routes: construtoraRoutes,
     );
 
@@ -465,14 +465,14 @@ void main() {
     expect(find.text('Quadra q1'), findsOneWidget);
     expect(
       router.state.uri.path,
-      '/construtora/c1/loteamentos/l1/quadras',
+      '/construtoras/c1/loteamentos/l1/quadras',
     );
   });
 
   testWidgets('deep-link em :quadraId redireciona para a lista de lotes',
       (tester) async {
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1',
+      initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1',
       routes: construtoraRoutes,
     );
 
@@ -497,7 +497,7 @@ void main() {
     expect(find.text('Lote lo1'), findsOneWidget);
     expect(
       router.state.uri.path,
-      '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
     );
   });
 
@@ -505,7 +505,7 @@ void main() {
       (tester) async {
     final router = GoRouter(
       initialLocation:
-          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1?x=1#alvo',
+          '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1?x=1#alvo',
       routes: construtoraRoutes,
     );
 
@@ -523,7 +523,7 @@ void main() {
 
     expect(
       router.state.uri.path,
-      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas',
+      '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas',
     );
     expect(router.state.uri.queryParameters['x'], '1');
     expect(router.state.uri.fragment, 'alvo');
@@ -532,7 +532,7 @@ void main() {
   testWidgets('admin toca Novo Lote e abre AddLoteScreen com os ids corretos',
       (tester) async {
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
       routes: construtoraRoutes,
     );
 
@@ -563,7 +563,7 @@ void main() {
   testWidgets('membro nao-admin nao acessa a rota lotes/novo', (tester) async {
     final router = GoRouter(
       initialLocation:
-          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/novo',
+          '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/novo',
       routes: construtoraRoutes,
     );
 
@@ -590,20 +590,20 @@ void main() {
   });
 
   testWidgets(
-      'card legado de Lotes e Setores navega para a lista de loteamentos',
+      'card legado de Loteamentos navega para a lista de loteamentos',
       (tester) async {
     final router = GoRouter(
-      initialLocation: '/construtora/c1/obra/o1',
+      initialLocation: '/construtoras/c1/obra/o1',
       routes: [
         GoRoute(
-          path: '/construtora/:cId/obra/:oId',
+          path: '/construtoras/:cId/obra/:oId',
           builder: (context, state) => ObraDashboardScreen(
             construtoraId: state.pathParameters['cId']!,
             obraId: state.pathParameters['oId']!,
           ),
         ),
         GoRoute(
-          path: '/construtora/:cId/loteamentos',
+          path: '/construtoras/:cId/loteamentos',
           builder: (context, state) => LoteamentosListScreen(
             construtoraId: state.pathParameters['cId']!,
           ),
@@ -645,10 +645,10 @@ void main() {
 
     await tester.pumpAndSettle();
 
-    await tester.tap(find.text('Lotes e Setores'));
+    await tester.tap(find.text('Loteamentos'));
     await tester.pumpAndSettle();
 
-    expect(router.state.uri.path, '/construtora/c1/loteamentos');
+    expect(router.state.uri.path, '/construtoras/c1/loteamentos');
     expect(find.byType(LoteamentosListScreen), findsOneWidget);
   });
 }
\ No newline at end of file
diff --git a/app/test/obra_switcher_layout_test.dart b/app/test/obra_switcher_layout_test.dart
index c5530c2..070075d 100644
--- a/app/test/obra_switcher_layout_test.dart
+++ b/app/test/obra_switcher_layout_test.dart
@@ -18,10 +18,10 @@ void main() {
       addTearDown(() => tester.view.resetPhysicalSize());
 
       final router = GoRouter(
-        initialLocation: '/construtora/c1/obra/obraA',
+        initialLocation: '/construtoras/c1/obra/obraA',
         routes: [
           GoRoute(
-            path: '/construtora/:cId/obra/:oId',
+            path: '/construtoras/:cId/obra/:oId',
             builder: (context, state) {
               final cId = state.pathParameters['cId']!;
               final oId = state.pathParameters['oId']!;
@@ -94,7 +94,7 @@ void main() {
       // Na Obra A: exibe Diário de Obra (na sidebar e no dashboard card); o
       // atalho de Lotes é liberado pela permissão central.
       expect(find.text('Diário de Obra'), findsNWidgets(2));
-      expect(find.text('Lotes e Setores'), findsNWidgets(2));
+      expect(find.text('Loteamentos'), findsNWidgets(2));
 
       // Abre dropdown do seletor de obra e seleciona Obra Beta
       final dropdown = find.byKey(const Key('obra-switcher-dropdown'));
@@ -106,8 +106,8 @@ void main() {
       await tester.tap(itemB);
       await tester.pumpAndSettle();
 
-      // Na Obra B: atualiza instantaneamente para exibir Lotes e Setores e ocultar Diário
-      expect(find.text('Lotes e Setores'), findsNWidgets(2));
+      // Na Obra B: atualiza instantaneamente para exibir Loteamentos e ocultar Diário
+      expect(find.text('Loteamentos'), findsNWidgets(2));
       expect(find.text('Diário de Obra'), findsNothing);
     },
   );
diff --git a/app/test/obras_lotes_crud_test.dart b/app/test/obras_lotes_crud_test.dart
index 0383cd5..a339d2c 100644
--- a/app/test/obras_lotes_crud_test.dart
+++ b/app/test/obras_lotes_crud_test.dart
@@ -163,7 +163,7 @@ void main() {
       expect(find.text('Lote 01'), findsOneWidget);
     });
 
-    testWidgets('ObrasListScreen exibe botao de Nova Obra para Administrador', (tester) async {
+    testWidgets('ObrasListScreen exibe botao de Novo Loteamento para Administrador', (tester) async {
       final fakeRepo = FakeObraRepository();
 
       await tester.pumpWidget(
@@ -187,17 +187,17 @@ void main() {
       await tester.pumpAndSettle();
 
       // Encontra o botão de criar obra na AppBar e no centro do estado vazio
-      expect(find.byTooltip('Nova Obra'), findsOneWidget);
-      expect(find.text('Criar Nova Obra'), findsOneWidget);
+      expect(find.byTooltip('Novo Loteamento'), findsOneWidget);
+      expect(find.text('Criar Novo Loteamento'), findsOneWidget);
       // Admin/owner enxerga o atalho de Loteamentos
       expect(find.byTooltip('Loteamentos'), findsOneWidget);
 
-      // Clica em Nova Obra e abre diálogo
-      await tester.tap(find.byTooltip('Nova Obra'));
+      // Clica em Novo Loteamento e abre diálogo
+      await tester.tap(find.byTooltip('Novo Loteamento'));
       await tester.pumpAndSettle();
 
-      expect(find.text('Nova Obra'), findsOneWidget);
-      expect(find.text('Nome da Obra *'), findsOneWidget);
+      expect(find.text('Novo Loteamento'), findsOneWidget);
+      expect(find.text('Nome do Loteamento *'), findsOneWidget);
 
       // Preenche e submete
       await tester.enterText(find.byType(TextFormField).first, 'Residencial Bela Vista');
@@ -209,7 +209,7 @@ void main() {
       expect(fakeRepo.obras.first.construtoraId, 'c1');
     });
 
-    testWidgets('ObrasListScreen oculta botao de Nova Obra para membro comum nao-admin', (tester) async {
+    testWidgets('ObrasListScreen oculta botao de Novo Loteamento para membro comum nao-admin', (tester) async {
       final fakeRepo = FakeObraRepository();
 
       await tester.pumpWidget(
@@ -233,8 +233,8 @@ void main() {
       await tester.pumpAndSettle();
 
       // Membro comum não vê ações administrativas de criação de obra
-      expect(find.byTooltip('Nova Obra'), findsNothing);
-      expect(find.text('Criar Nova Obra'), findsNothing);
+      expect(find.byTooltip('Novo Loteamento'), findsNothing);
+      expect(find.text('Criar Novo Loteamento'), findsNothing);
       // Sem módulo lotes, o atalho de Loteamentos fica oculto
       expect(find.byTooltip('Loteamentos'), findsNothing);
     });
diff --git a/app/test/sigo_breadcrumbs_test.dart b/app/test/sigo_breadcrumbs_test.dart
index 4683b43..479a215 100644
--- a/app/test/sigo_breadcrumbs_test.dart
+++ b/app/test/sigo_breadcrumbs_test.dart
@@ -4,10 +4,10 @@ import 'package:flutter_test/flutter_test.dart';
 import 'package:go_router/go_router.dart';
 
 GoRouter _router() => GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
       routes: [
         GoRoute(
-          path: '/construtora/:cId',
+          path: '/construtoras/:cId',
           builder: (context, state) => const SizedBox(),
           routes: [
             GoRoute(
@@ -51,10 +51,11 @@ void main() {
     await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
     await tester.pumpAndSettle();
 
+    expect(find.text('Construtora'), findsOneWidget);
     expect(find.text('Loteamento'), findsOneWidget);
     expect(find.text('Quadra'), findsOneWidget);
     expect(find.text('Lotes'), findsOneWidget);
-    expect(find.text('/'), findsNWidgets(2));
+    expect(find.text('/'), findsNWidgets(3));
   });
 
   testWidgets('tocar num segmento com url navega para a lista do nivel',
diff --git a/app/test/sigo_sidebar_collapsed_test.dart b/app/test/sigo_sidebar_collapsed_test.dart
index 10fc70c..c181cb6 100644
--- a/app/test/sigo_sidebar_collapsed_test.dart
+++ b/app/test/sigo_sidebar_collapsed_test.dart
@@ -33,7 +33,7 @@ void main() {
           data: MediaQueryData(size: physicalSize),
           child: const SigoLayout(
             title: 'Painel Teste',
-            activeRoute: '/construtora/c1/obra/o1',
+            activeRoute: '/construtoras/c1/obra/o1',
             child: Text('Conteudo Principal'),
           ),
         ),
diff --git a/app/test/sigo_sidebar_test.dart b/app/test/sigo_sidebar_test.dart
index fea3385..117c540 100644
--- a/app/test/sigo_sidebar_test.dart
+++ b/app/test/sigo_sidebar_test.dart
@@ -16,10 +16,10 @@ void main() {
       addTearDown(() => tester.view.resetPhysicalSize());
 
       final router = GoRouter(
-        initialLocation: '/construtora/c1/obra/obraA',
+        initialLocation: '/construtoras/c1/obra/obraA',
         routes: [
           GoRoute(
-            path: '/construtora/:cId/obra/:oId',
+            path: '/construtoras/:cId/obra/:oId',
             builder: (context, state) {
               final cId = state.pathParameters['cId']!;
               final oId = state.pathParameters['oId']!;
@@ -42,7 +42,7 @@ void main() {
       );
 
       await tester.pumpAndSettle();
-      expect(find.text('Lotes e Setores'), findsNothing);
+      expect(find.text('Loteamentos'), findsNothing);
       expect(find.text('Diário de Obra'), findsNothing);
     },
   );
@@ -55,10 +55,10 @@ void main() {
       addTearDown(() => tester.view.resetPhysicalSize());
 
       final router = GoRouter(
-        initialLocation: '/construtora/c1/obra/obraA',
+        initialLocation: '/construtoras/c1/obra/obraA',
         routes: [
           GoRoute(
-            path: '/construtora/:cId/obra/:oId',
+            path: '/construtoras/:cId/obra/:oId',
             builder: (context, state) {
               final cId = state.pathParameters['cId']!;
               final oId = state.pathParameters['oId']!;
diff --git a/app/test/sigo_top_bar_test.dart b/app/test/sigo_top_bar_test.dart
index f113259..de74c39 100644
--- a/app/test/sigo_top_bar_test.dart
+++ b/app/test/sigo_top_bar_test.dart
@@ -32,7 +32,7 @@ void main() {
             builder: (context, state) => const Scaffold(
               appBar: SigoTopBar(
                 title: 'Painel',
-                activeRoute: '/construtora/c9/obra/o9',
+                activeRoute: '/construtoras/c9/obra/o9',
               ),
             ),
           ),
diff --git a/app/test/src/features/loteamentos/presentation/loteamentos_list_screen_test.dart b/app/test/src/features/loteamentos/presentation/loteamentos_list_screen_test.dart
index 50f4eae..0741e0e 100644
--- a/app/test/src/features/loteamentos/presentation/loteamentos_list_screen_test.dart
+++ b/app/test/src/features/loteamentos/presentation/loteamentos_list_screen_test.dart
@@ -29,10 +29,10 @@ Loteamento makeLoteamento(String id) => Loteamento(
 
 Widget buildTestWidget(Widget child) {
   final router = GoRouter(
-    initialLocation: '/construtora/c1/loteamentos',
+    initialLocation: '/construtoras/c1/loteamentos',
     routes: [
       GoRoute(
-        path: '/construtora/c1/loteamentos',
+        path: '/construtoras/c1/loteamentos',
         builder: (context, state) => child,
       ),
     ],
@@ -144,10 +144,10 @@ void main() {
     var buildCount = 0;
 
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos',
+      initialLocation: '/construtoras/c1/loteamentos',
       routes: [
         GoRoute(
-          path: '/construtora/c1/loteamentos',
+          path: '/construtoras/c1/loteamentos',
           builder: (context, state) => ValueListenableBuilder<int>(
             valueListenable: rebuild,
             builder: (context, _, _) {
diff --git a/app/test/src/features/lotes/presentation/lotes_list_screen_test.dart b/app/test/src/features/lotes/presentation/lotes_list_screen_test.dart
index 6fc66cf..3ee084f 100644
--- a/app/test/src/features/lotes/presentation/lotes_list_screen_test.dart
+++ b/app/test/src/features/lotes/presentation/lotes_list_screen_test.dart
@@ -35,10 +35,10 @@ Lote makeLote(String id) => Lote(
 
 Widget buildTestWidget(Widget child) {
   final router = GoRouter(
-    initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+    initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
     routes: [
       GoRoute(
-        path: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+        path: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
         builder: (context, state) => child,
       ),
     ],
@@ -165,10 +165,10 @@ void main() {
     var buildCount = 0;
 
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
       routes: [
         GoRoute(
-          path: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+          path: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
           builder: (context, state) => ValueListenableBuilder<int>(
             valueListenable: rebuild,
             builder: (context, _, _) {
diff --git a/app/test/src/features/quadras/presentation/quadras_list_screen_test.dart b/app/test/src/features/quadras/presentation/quadras_list_screen_test.dart
index 166bd76..ccddf39 100644
--- a/app/test/src/features/quadras/presentation/quadras_list_screen_test.dart
+++ b/app/test/src/features/quadras/presentation/quadras_list_screen_test.dart
@@ -30,10 +30,10 @@ Quadra makeQuadra(String id) => Quadra(
 
 Widget buildTestWidget(Widget child) {
   final router = GoRouter(
-    initialLocation: '/construtora/c1/loteamentos/l1/quadras',
+    initialLocation: '/construtoras/c1/loteamentos/l1/quadras',
     routes: [
       GoRoute(
-        path: '/construtora/c1/loteamentos/l1/quadras',
+        path: '/construtoras/c1/loteamentos/l1/quadras',
         builder: (context, state) => child,
       ),
     ],
@@ -148,10 +148,10 @@ void main() {
     var buildCount = 0;
 
     final router = GoRouter(
-      initialLocation: '/construtora/c1/loteamentos/l1/quadras',
+      initialLocation: '/construtoras/c1/loteamentos/l1/quadras',
       routes: [
         GoRoute(
-          path: '/construtora/c1/loteamentos/l1/quadras',
+          path: '/construtoras/c1/loteamentos/l1/quadras',
           builder: (context, state) => ValueListenableBuilder<int>(
             valueListenable: rebuild,
             builder: (context, _, _) {


Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. If the instruction file is unreadable, report that exact failure and stop. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.
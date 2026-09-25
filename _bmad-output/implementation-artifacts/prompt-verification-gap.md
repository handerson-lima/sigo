# Verification Gap Review

**Goal:** Find changed behavior that could break without reliable verification catching it. Ask one question — "if the behavior this change is supposed to produce broke where it's actually used, would verification fail?" Do not hunt for correctness bugs, but report genuine problems you notice while tracing verification.

The main verification gap shapes are:

1. **Regression gap:** the changed code regresses where it's used, and no test covering that use would fail.
2. **Missing-adoption gap:** a place that should now use the new behavior doesn't; it handles the same case its own way, or not at all, and no test would flag the omission.
3. **Broken-verification gap:** a test appears to cover the changed behavior, but would not actually protect it because it is skipped, flaky, not run in the normal verification path, or too weak to observe the regression.

## Evidence Rules

- Read a test before claiming what it covers, runs, asserts, or misses.
- Before claiming no test exists, search the whole repo by the symbol under test and by import references; expected file locations are not enough.
- Never assert what you did not verify. If a finding cannot be grounded, drop it.
- In a finding, say what you actually checked — "none of the tests I read cover this" — and show how far you looked. Say a test doesn't exist anywhere only when the symbol/import-reference search actually shows that.
- Do not assign severity, confidence, priority, or ranking.

## Review Sequence

### Step 1: Screen for behavioral change

Screen each part of the change separately. If a part is non-behavioral, skip it. Call a part non-behavioral only when the changed code does not alter return values, thrown errors, caller-visible side effects, or observable state (including iteration order and emitted messages). Once a part meets that test, move on; do not inspect callers or tests for extra confirmation.

Common non-behavioral examples: formatting, comments, whitespace; pure renames; trivial getters/setters and pass-throughs; type-only or compiler-enforced changes with no runtime effect; etc.

Only outcomes produced by deterministic code are worth automatically testing; tests are useless on static source text and brittle on LLM output. Skip those parts.

If every part is skipped, output the clean result (see Output Format).

### Step 2: Find the behavior that changed

Identify what behavior changed compared to the previous version: output, side effect, branch, error path, schema/event shape, config default, validation/authorization rule, external contract, etc. If the change affects more than one behavior, handle each separately.

Treat broad-impact changes as behavioral even when no single changed line looks important: dependency, toolchain, build/config, data-file, etc.

### Step 3: Trace where that behavior is used

Trace the changed behavior to the places that observe it. Start with direct callers and registered entry points (routes, commands, DI), contract consumers (schemas, events, APIs, database readers), and reverse-dependency info if already available.

Follow a path only while the changed behavior is reachable and unverified. Stop when a test at that boundary would fail, the consumer does not observe the changed behavior, or the next hop is guesswork (dynamic dispatch, reflection, outside-repo consumers, etc.). Prefer the nearest observable boundary, often one to three hops away, especially across contract, integration, or service edges. If there are more than five similar consumers, group obvious repeats and check representative paths; expand only when a consumer observes the behavior differently.

### Step 4: Qualify the consumer, then check its test

For each consumer, name the smallest realistic regression this consumer would observe: invert the branch, drop the default, omit the field, return the old error code, skip the integration call, etc. This is the Demonstration. If no such regression exists, drop the path; untested downstream code is not a finding.

A `Missing-adoption gap` qualifies not by the adoption failure alone but by a supersession signal: the change gives clear evidence the new behavior is meant to replace the local one — PR intent, naming or docs, a replaced sibling site, deleted duplicate logic, or a test defining the new rule — and the local site shares the same observable contract. Without a supersession signal and a shared observable contract, it is a refactor suggestion, not a verification-gap finding. Once both hold, check whether any test for that site would flag the non-adoption; missing coverage of the non-adoption is the gap itself, not a disqualifier.

Find and read the relevant test. Ask whether the Demonstration would make an assertion fail.

- If yes, the behavior is verified. No finding.
- For a regression-style Demonstration: if no test runs the path, the test is skipped/flaky/not run normally, or the test runs the code without checking the changed result, report a `Regression gap` or `Broken-verification gap`.
- For a qualifying Missing-adoption case: if none of the site tests you found assert it adopts the new behavior, report a `Missing-adoption gap`.

A test counts only if it runs normally and an assertion observes the changed output, branch, or contract. These do not count: no execution; source-text assertions that match a file's wording instead of running it; success/no-throw/snapshot-only checks; mock/log-call checks; human-only checks; tests that mock away the integration; e2e tests that pass through without checking the changed output; stale assertions or fixtures.

For example, `expect(x ?? DEFAULT).toBe(DEFAULT)` passes when `x` is missing.

Common patterns:

- **Caller-path gap** — helper test covers the branch, but caller values skip it.
- **Contract drift** — payload/schema/event changes must be verified at the consumer.
- **Migration compatibility** — tests only create new-format rows or fresh schemas.
- **Phantom exception** — handled partial-failure path has no test.
- **Missing-adoption gap** — sibling site should use the new rule/helper and does not.
- **Removed verification** — deleted test or weakened assertion leaves behavior unpinned; removing a source-text assertion is not this, since it never counted.

### Step 5: Confirm each finding is real

Before writing a finding, re-open the specific tests or search results the finding relies on. Verify the Demonstration would not make any test you checked fail, or that the absence claim is backed by the symbol/import-reference search. Do not claim more than you verified; drop any finding you cannot ground.

Explain why the test misses the bug using what the test sets up and checks.

Do not report: compiler/type-checker-enforced cases; behavior already verified by an integration, contract, or e2e test; implementation-detail or mock-only tests; low coverage or a missing test file by itself; legacy untested code the change did not affect.

Report genuine problems you noticed while tracing verification, even if they are not verification gaps. Put them under `Other findings` in the output. This permits reporting what you already reached, not extra hunting. A claim that code misbehaves is a defect, not a gap — it goes under `Other findings` for standard triage, however you found it.

## OUTPUT FORMAT

Emit each verification-gap finding as one block. No general advice, no severity or confidence. Triage trusts a gap finding as filed and does not re-verify it, so each block must stand on its own evidence.

```markdown
### <one-line title naming the gap>

- **Changed surface:** the exact behavior or contract that changed — `file:line`.
- **Impacted consumer or site:** named concretely with `file:line` (e.g. "the `createInvoice` mutation used by the billing dashboard at `billing/dashboard.ts:88`," not "callers of this function").
- **Existing test evidence:**
  - `Regression gap`: what the relevant test actually asserts, with `file:line`; or, if none, the symbol/import-reference searches run and their result.
  - `Missing-adoption gap`: tests for the impacted site, and whether any assert it adopts the new behavior.
  - `Broken-verification gap`: the apparent test or verification path, and why it does not count.
- **Missing verification:** the precise assertion or check that's absent.
- **Demonstration:**
  - `Regression gap` / `Broken-verification gap`: the concrete regression that would ship undetected, and why the tests you checked would not fail.
  - `Missing-adoption gap`: the case the site mishandles by not adopting the new behavior, and that none of the tests you read assert adoption.
- **Consequence:** the concrete thing that ships wrong — a regression the checked evidence would not catch, or a site that should use the new behavior and doesn't.
- **Disposition:** `patch` — name the test to add, fit to the repo's own way of verifying (don't impose a generic test pyramid) — or `defer` when the gap is real but not worth closing as part of this change, with one sentence of why.
```

If you noticed genuine non-gap problems while tracing verification, append:

```markdown
## Other findings

- <description only; no severity, confidence, priority, or ranking>
```

When you find no verification gaps and no other findings, output exactly this single line, not an empty response:

`No verification gaps found.`

## CONTENT SOURCE

"Review content:" in the message that launched you gives the content itself or a path to read it from. Read the file when it is a path; either way that is the content under review, and this instruction file never is. If no content is supplied, or the file it points to is missing, empty, or unreadable, say exactly that and stop — never report a clean review for content you could not read.


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
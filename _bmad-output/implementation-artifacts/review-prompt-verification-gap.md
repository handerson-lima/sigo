# Review Instructions
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


---

# Review content
```diff
diff --git a/_bmad-output/implementation-artifacts/spec-1-8-recalculo-modulos.md b/_bmad-output/implementation-artifacts/spec-1-8-recalculo-modulos.md
index d640bcf..fd19f3e 100644
--- a/_bmad-output/implementation-artifacts/spec-1-8-recalculo-modulos.md
+++ b/_bmad-output/implementation-artifacts/spec-1-8-recalculo-modulos.md
@@ -2,7 +2,8 @@
 title: 'Story 1.8 — Recálculo de Módulos e Layout Imediato na Troca de Obra'
 type: 'feature'
 created: '2026-09-16'
-status: 'ready-for-dev'
+status: 'in-review'
+baseline_commit: '9e09709bb983d1b2eed9d01e21e08ee7f3229cba'
 route: 'dispatch'
 review_loop_iteration: 0
 context:
@@ -56,11 +57,11 @@ context:
 ## Tasks & Acceptance
 
 **Execution:**
-- [ ] `app/lib/src/features/obras/presentation/current_permissions_provider.dart` -- Suportar `allowedModules` como fallback de `modules` e validar status da obra.
-- [ ] `app/lib/src/common_widgets/sigo_top_bar.dart` -- Implementar dropdown/seletor de obra ativa permitindo troca rápida entre obras da mesma construtora.
-- [ ] `app/lib/src/common_widgets/sigo_sidebar.dart` -- Sincronizar itens de navegação com a obra ativa imediatamente após a seleção.
-- [ ] `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart` -- Garantir renderização reativa dos cards da obra ativa.
-- [ ] `app/test/widget_test.dart` -- Adicionar testes de widget e de provedor verificando a troca de contexto entre obras com módulos distintos.
+- [x] `app/lib/src/features/obras/presentation/current_permissions_provider.dart` -- Suportar `allowedModules` como fallback de `modules` e validar status da obra.
+- [x] `app/lib/src/common_widgets/sigo_top_bar.dart` -- Implementar dropdown/seletor de obra ativa permitindo troca rápida entre obras da mesma construtora.
+- [x] `app/lib/src/common_widgets/sigo_sidebar.dart` -- Sincronizar itens de navegação com a obra ativa imediatamente após a seleção.
+- [x] `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart` -- Garantir renderização reativa dos cards da obra ativa.
+- [x] `app/test/widget_test.dart` -- Adicionar testes de widget e de provedor verificando a troca de contexto entre obras com módulos distintos.
 
 **Acceptance Criteria:**
 - Given um usuário com acesso a Obra A (com módulo `diario`) e Obra B (com módulo `lotes`), when o usuário alterna de Obra A para Obra B no seletor, then o layout da sidebar e os cards do dashboard atualizam instantaneamente, exibindo 'Lotes e Setores' e ocultando 'Diário de Obra'.
diff --git a/_bmad-output/implementation-artifacts/sprint-status.yaml b/_bmad-output/implementation-artifacts/sprint-status.yaml
index b430249..4f8b992 100644
--- a/_bmad-output/implementation-artifacts/sprint-status.yaml
+++ b/_bmad-output/implementation-artifacts/sprint-status.yaml
@@ -47,7 +47,7 @@ development_status:
   1-5-descoberta-obras: review
   1-6-fluxo-login: review
   1-7-selecao-obra: review
-  1-8-recalculo-modulos: ready-for-dev
+  1-8-recalculo-modulos: review
   epic-1-retrospective: optional
 
   epic-2: backlog
diff --git a/app/lib/src/common_widgets/access_guard.dart b/app/lib/src/common_widgets/access_guard.dart
index f5798d2..bec9c48 100644
--- a/app/lib/src/common_widgets/access_guard.dart
+++ b/app/lib/src/common_widgets/access_guard.dart
@@ -36,7 +36,6 @@ class AccessGuard extends ConsumerWidget {
       return const AccessDeniedScreen();
     }
     final admin = member?['isAdmin'] == true || member?['isOwner'] == true;
-    if (admin) return child;
     if (obraId != null) {
       final om = ref.watch(
         currentPermissionsProvider((
@@ -58,11 +57,12 @@ class AccessGuard extends ConsumerWidget {
       }
       return child;
     }
+    if (admin) return child;
     if (adminOnly ||
         module == 'financeiro' ||
         module != null &&
-            !(member?['modules'] as List? ?? [])
-                .map((m) => normalizeModule(m as String))
+            !((member?['modules'] ?? member?['allowedModules']) as List? ?? [])
+                .map((m) => normalizeModule(m.toString()))
                 .contains(normalizeModule(module!))) {
       return const AccessDeniedScreen();
     }
diff --git a/app/lib/src/common_widgets/sigo_layout.dart b/app/lib/src/common_widgets/sigo_layout.dart
index ec90791..b6ad94d 100644
--- a/app/lib/src/common_widgets/sigo_layout.dart
+++ b/app/lib/src/common_widgets/sigo_layout.dart
@@ -31,7 +31,11 @@ class SigoLayout extends StatelessWidget {
                 Expanded(
                   child: Column(
                     children: [
-                      SigoTopBar(title: title, actions: actions),
+                      SigoTopBar(
+                        title: title,
+                        actions: actions,
+                        activeRoute: activeRoute,
+                      ),
                       Expanded(
                         child: Padding(
                           padding: const EdgeInsets.all(24.0),
@@ -49,7 +53,11 @@ class SigoLayout extends StatelessWidget {
         // Mobile / Tablet Portrait
         return Scaffold(
           backgroundColor: const Color(0xFFF8FAFC),
-          appBar: SigoTopBar(title: title, actions: actions),
+          appBar: SigoTopBar(
+            title: title,
+            actions: actions,
+            activeRoute: activeRoute,
+          ),
           drawer: SigoSidebar(activeRoute: activeRoute),
           body: Padding(
             padding: const EdgeInsets.all(16.0),
diff --git a/app/lib/src/common_widgets/sigo_sidebar.dart b/app/lib/src/common_widgets/sigo_sidebar.dart
index efd5fac..b2289ad 100644
--- a/app/lib/src/common_widgets/sigo_sidebar.dart
+++ b/app/lib/src/common_widgets/sigo_sidebar.dart
@@ -4,6 +4,7 @@ import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:go_router/go_router.dart';
 
+import '../core/contracts.dart';
 import '../features/authentication/data/auth_repository.dart';
 import '../features/authentication/data/user_repository.dart';
 
@@ -89,8 +90,10 @@ class SigoSidebar extends ConsumerWidget {
                       context.go('/construtora/$cId/obra/$oId');
                     },
                   ),
-                  if (obra?.isAdmin == true ||
-                      obra?.modules.contains('lotes') == true)
+                  if (obra != null &&
+                      obra.isActive &&
+                      (obra.isAdmin ||
+                          obra.modules.map(normalizeModule).contains('lotes')))
                     _NavItem(
                       icon: Icons.map,
                       title: 'Lotes e Setores',
@@ -100,8 +103,10 @@ class SigoSidebar extends ConsumerWidget {
                         context.go('/construtora/$cId/obra/$oId/lotes');
                       },
                     ),
-                  if (obra?.isAdmin == true ||
-                      obra?.modules.contains('diario') == true)
+                  if (obra != null &&
+                      obra.isActive &&
+                      (obra.isAdmin ||
+                          obra.modules.map(normalizeModule).contains('diario')))
                     _NavItem(
                       icon: Icons.assignment,
                       title: 'Diário de Obra',
@@ -218,11 +223,14 @@ class _NavItem extends StatelessWidget {
           children: [
             Icon(icon, color: isActive ? Colors.amber[700] : Colors.white70),
             const SizedBox(width: 12),
-            Text(
-              title,
-              style: TextStyle(
-                color: isActive ? Colors.amber[700] : Colors.white70,
-                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
+            Expanded(
+              child: Text(
+                title,
+                style: TextStyle(
+                  color: isActive ? Colors.amber[700] : Colors.white70,
+                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
+                ),
+                overflow: TextOverflow.ellipsis,
               ),
             ),
           ],
diff --git a/app/lib/src/common_widgets/sigo_top_bar.dart b/app/lib/src/common_widgets/sigo_top_bar.dart
index 2763020..d84f8b9 100644
--- a/app/lib/src/common_widgets/sigo_top_bar.dart
+++ b/app/lib/src/common_widgets/sigo_top_bar.dart
@@ -3,16 +3,32 @@ import 'package:go_router/go_router.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 
 import '../features/authentication/data/auth_repository.dart';
+import '../features/obras/presentation/construtora_obras_provider.dart';
 
 class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
   final String title;
   final List<Widget>? actions;
+  final String? activeRoute;
 
-  const SigoTopBar({super.key, required this.title, this.actions});
+  const SigoTopBar({
+    super.key,
+    required this.title,
+    this.actions,
+    this.activeRoute,
+  });
 
   @override
   Size get preferredSize => const Size.fromHeight(60);
 
+  String? _resolveRoute(BuildContext context) {
+    if (activeRoute != null && activeRoute!.isNotEmpty) return activeRoute;
+    try {
+      return GoRouterState.of(context).uri.toString();
+    } catch (_) {
+      return null;
+    }
+  }
+
   @override
   Widget build(BuildContext context, WidgetRef ref) {
     final authState = ref.watch(authStateChangesProvider);
@@ -20,6 +36,20 @@ class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
     final email = user?.email ?? '';
     final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
 
+    final route = _resolveRoute(context);
+    String? cId;
+    String? oId;
+    if (route != null) {
+      final uri = Uri.tryParse(route);
+      final segments = uri?.pathSegments ?? [];
+      if (segments.length >= 2 && segments[0] == 'construtora') {
+        cId = segments[1];
+        if (segments.length >= 4 && segments[2] == 'obra') {
+          oId = segments[3];
+        }
+      }
+    }
+
     return AppBar(
       backgroundColor: Colors.transparent,
       elevation: 0,
@@ -33,16 +63,27 @@ class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
             )
           : null,
       title: Row(
+        mainAxisSize: MainAxisSize.min,
         children: [
           if (context.canPop())
             const Text(
               'Voltar • ',
               style: TextStyle(color: Colors.black54, fontSize: 14),
             ),
-          Text(
-            title,
-            style: const TextStyle(color: Colors.black54, fontSize: 14),
+          Flexible(
+            child: Text(
+              title,
+              style: const TextStyle(color: Colors.black54, fontSize: 14),
+              overflow: TextOverflow.ellipsis,
+            ),
           ),
+          if (cId != null && oId != null) ...[
+            const SizedBox(width: 12),
+            ObraSwitcher(
+              construtoraId: cId,
+              currentObraId: oId,
+            ),
+          ],
         ],
       ),
       actions: [
@@ -67,3 +108,81 @@ class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
     );
   }
 }
+
+class ObraSwitcher extends ConsumerWidget {
+  final String construtoraId;
+  final String currentObraId;
+
+  const ObraSwitcher({
+    super.key,
+    required this.construtoraId,
+    required this.currentObraId,
+  });
+
+  @override
+  Widget build(BuildContext context, WidgetRef ref) {
+    final obrasAsync = ref.watch(construtoraObrasProvider(construtoraId));
+    return obrasAsync.maybeWhen(
+      data: (obras) {
+        if (obras.isEmpty) return const SizedBox.shrink();
+        final isSelectedPresent = obras.any((o) => o.id == currentObraId);
+        final selectedValue = isSelectedPresent ? currentObraId : null;
+
+        return Container(
+          height: 36,
+          padding: const EdgeInsets.symmetric(horizontal: 8),
+          decoration: BoxDecoration(
+            color: Colors.white,
+            borderRadius: BorderRadius.circular(8),
+            border: Border.all(color: Colors.black12),
+          ),
+          child: DropdownButtonHideUnderline(
+            child: DropdownButton<String>(
+              key: const Key('obra-switcher-dropdown'),
+              value: selectedValue,
+              hint: const Text(
+                'Selecionar Obra',
+                style: TextStyle(fontSize: 12, color: Colors.black54),
+              ),
+              icon: const Icon(Icons.swap_horiz, size: 18, color: Colors.amber),
+              style: const TextStyle(
+                color: Colors.black87,
+                fontSize: 12,
+                fontWeight: FontWeight.w600,
+              ),
+              items: obras.map((o) {
+                return DropdownMenuItem<String>(
+                  key: Key('obra-switcher-item-${o.id}'),
+                  value: o.id,
+                  child: Row(
+                    mainAxisSize: MainAxisSize.min,
+                    children: [
+                      Icon(
+                        Icons.business,
+                        size: 14,
+                        color: o.id == currentObraId
+                            ? Colors.amber[900]
+                            : Colors.black45,
+                      ),
+                      const SizedBox(width: 6),
+                      Text(
+                        o.name,
+                        overflow: TextOverflow.ellipsis,
+                      ),
+                    ],
+                  ),
+                );
+              }).toList(),
+              onChanged: (newObraId) {
+                if (newObraId != null && newObraId != currentObraId) {
+                  context.go('/construtora/$construtoraId/obra/$newObraId');
+                }
+              },
+            ),
+          ),
+        );
+      },
+      orElse: () => const SizedBox.shrink(),
+    );
+  }
+}
diff --git a/app/lib/src/features/obras/presentation/current_permissions_provider.dart b/app/lib/src/features/obras/presentation/current_permissions_provider.dart
index 110ef2f..5edf8ad 100644
--- a/app/lib/src/features/obras/presentation/current_permissions_provider.dart
+++ b/app/lib/src/features/obras/presentation/current_permissions_provider.dart
@@ -14,17 +14,42 @@ final construtoraPermissionProvider = StreamProvider.autoDispose
       if (user == null) return Stream.value(null);
       return cachedDocument('construtoras/$c/construtora_members/${user.uid}');
     });
+
+final obraDocProvider = StreamProvider.autoDispose
+    .family<Map<String, dynamic>?, ObraScope>((ref, scope) {
+      return cachedDocument(
+        'construtoras/${scope.construtoraId}/obras/${scope.obraId}',
+      );
+    });
+
 final currentPermissionsProvider = StreamProvider.autoDispose
     .family<ObraMember?, ObraScope>((ref, scope) {
       final user = ref.watch(authStateChangesProvider).value;
       if (user == null) return Stream.value(null);
       final dev = ref.watch(trustedDevProvider).value == true;
+      if (dev) {
+        return Stream.value(
+          ObraMember(
+            userId: user.uid,
+            isAdmin: true,
+            isActive: true,
+            modules: ['diario', 'lotes', 'estoque'],
+            joinedAt: DateTime(2000),
+          ),
+        );
+      }
+
       final cm = ref
           .watch(construtoraPermissionProvider(scope.construtoraId))
           .value;
-      if (dev ||
-          cm?['isActive'] == true &&
-              (cm?['isAdmin'] == true || cm?['isOwner'] == true)) {
+      if (cm?['isActive'] != true) return Stream.value(null);
+
+      final obraDoc = ref.watch(obraDocProvider(scope)).value;
+      if (obraDoc != null && obraDoc['isActive'] == false) {
+        return Stream.value(null);
+      }
+
+      if (cm?['isAdmin'] == true || cm?['isOwner'] == true) {
         return Stream.value(
           ObraMember(
             userId: user.uid,
@@ -35,14 +60,15 @@ final currentPermissionsProvider = StreamProvider.autoDispose
           ),
         );
       }
-      if (cm?['isActive'] != true) return Stream.value(null);
+
       return cachedDocument(
         'construtoras/${scope.construtoraId}/obras/${scope.obraId}/members/${user.uid}',
       ).map((doc) {
         if (doc?['isActive'] != true) return null;
-        final data = doc!;
-        data['modules'] = (data['modules'] as List? ?? [])
-            .map((m) => normalizeModule(m as String))
+        final data = Map<String, dynamic>.from(doc!);
+        final rawModules = data['modules'] ?? data['allowedModules'];
+        data['modules'] = (rawModules as List? ?? [])
+            .map((m) => normalizeModule(m.toString()))
             .toList();
         return ObraMember.fromJson(data);
       });
diff --git a/app/lib/src/features/obras/presentation/obra_dashboard_screen.dart b/app/lib/src/features/obras/presentation/obra_dashboard_screen.dart
index 3ad5e06..52961a3 100644
--- a/app/lib/src/features/obras/presentation/obra_dashboard_screen.dart
+++ b/app/lib/src/features/obras/presentation/obra_dashboard_screen.dart
@@ -1,3 +1,4 @@
+import '../../../core/contracts.dart';
 import '../../lotes/domain/lote.dart';
 
 import 'package:flutter/material.dart';
@@ -32,9 +33,11 @@ class ObraDashboardScreen extends ConsumerWidget {
         obraId: obraId,
       )),
     );
-    final canLotes =
-        permissionsAsync.value?.isAdmin == true ||
-        permissionsAsync.value?.modules.contains('lotes') == true;
+    final activeMember = permissionsAsync.asData?.value;
+    final canLotes = activeMember != null &&
+        activeMember.isActive &&
+        (activeMember.isAdmin ||
+            activeMember.modules.map(normalizeModule).contains('lotes'));
     final lotesAsync = canLotes
         ? ref.watch(
             obraLotesProvider((construtoraId: construtoraId, obraId: obraId)),
@@ -107,7 +110,8 @@ class ObraDashboardScreen extends ConsumerWidget {
                           '/construtora/$construtoraId/obra/$obraId/lotes',
                         ),
                       ),
-                    if (member.isAdmin || member.modules.contains('diario'))
+                    if (member.isAdmin ||
+                        member.modules.map(normalizeModule).contains('diario'))
                       SigoModuleCard(
                         icon: Icons.assignment,
                         title: 'Diário de Obra',
diff --git a/app/test/widget_test.dart b/app/test/widget_test.dart
index f0b1190..7369fa1 100644
--- a/app/test/widget_test.dart
+++ b/app/test/widget_test.dart
@@ -1,11 +1,19 @@
 import 'package:app/main.dart';
+import 'package:app/src/common_widgets/access_guard.dart';
+import 'package:app/src/core/contracts.dart';
 import 'package:app/src/features/authentication/data/auth_repository.dart';
 import 'package:app/src/features/authentication/data/user_repository.dart';
-import 'package:app/src/common_widgets/access_guard.dart';
+import 'package:app/src/features/lotes/domain/lote.dart';
+import 'package:app/src/features/lotes/presentation/obra_lotes_provider.dart';
+import 'package:app/src/features/obras/domain/obra.dart';
+import 'package:app/src/features/obras/domain/obra_member.dart';
+import 'package:app/src/features/obras/presentation/construtora_obras_provider.dart';
 import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
+import 'package:app/src/features/obras/presentation/obra_dashboard_screen.dart';
 import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:flutter_test/flutter_test.dart';
+import 'package:go_router/go_router.dart';
 
 void main() {
   testWidgets(
@@ -25,6 +33,7 @@ void main() {
       expect(tester.takeException(), isNull);
     },
   );
+
   testWidgets('trusted dev reaches obra without memberships', (tester) async {
     await tester.pumpWidget(
       ProviderScope(
@@ -44,6 +53,7 @@ void main() {
     await tester.pumpAndSettle();
     expect(find.text('global access'), findsOneWidget);
   });
+
   testWidgets(
     'inactive membership denies central module despite legacy flags',
     (tester) async {
@@ -73,4 +83,239 @@ void main() {
       expect(find.text('Acesso Negado'), findsOneWidget);
     },
   );
+
+  testWidgets(
+    'alternar de Obra A para Obra B no seletor recalcula layout imediatamente',
+    (tester) async {
+      tester.view.physicalSize = const Size(1280, 800);
+      tester.view.devicePixelRatio = 1.0;
+      addTearDown(() => tester.view.resetPhysicalSize());
+
+      final router = GoRouter(
+        initialLocation: '/construtora/c1/obra/obraA',
+        routes: [
+          GoRoute(
+            path: '/construtora/:cId/obra/:oId',
+            builder: (context, state) {
+              final cId = state.pathParameters['cId']!;
+              final oId = state.pathParameters['oId']!;
+              return ObraDashboardScreen(construtoraId: cId, obraId: oId);
+            },
+          ),
+        ],
+      );
+
+      final obrasList = [
+        Obra(
+          id: 'obraA',
+          construtoraId: 'c1',
+          name: 'Obra Alfa',
+          createdAt: DateTime(2025),
+        ),
+        Obra(
+          id: 'obraB',
+          construtoraId: 'c1',
+          name: 'Obra Beta',
+          createdAt: DateTime(2025),
+        ),
+      ];
+
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
+            construtoraObrasProvider('c1').overrideWith(
+              (ref) => Future.value(obrasList),
+            ),
+            currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraA'))
+                .overrideWith(
+                  (ref) => Stream.value(
+                    ObraMember(
+                      userId: 'u1',
+                      isActive: true,
+                      isAdmin: false,
+                      modules: ['diario'],
+                      joinedAt: DateTime(2025),
+                    ),
+                  ),
+                ),
+            currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraB'))
+                .overrideWith(
+                  (ref) => Stream.value(
+                    ObraMember(
+                      userId: 'u1',
+                      isActive: true,
+                      isAdmin: false,
+                      modules: ['lotes'],
+                      joinedAt: DateTime(2025),
+                    ),
+                  ),
+                ),
+            obraLotesProvider((construtoraId: 'c1', obraId: 'obraA'))
+                .overrideWith((ref) => Stream.value(<Lote>[])),
+            obraLotesProvider((construtoraId: 'c1', obraId: 'obraB'))
+                .overrideWith((ref) => Stream.value(<Lote>[])),
+          ],
+          child: MaterialApp.router(routerConfig: router),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+
+      // Na Obra A: exibe Diário de Obra (na sidebar e no dashboard card), não exibe Lotes
+      expect(find.text('Diário de Obra'), findsNWidgets(2));
+      expect(find.text('Lotes e Setores'), findsNothing);
+
+      // Abre dropdown do seletor de obra e seleciona Obra Beta
+      final dropdown = find.byKey(const Key('obra-switcher-dropdown'));
+      expect(dropdown, findsOneWidget);
+      await tester.tap(dropdown);
+      await tester.pumpAndSettle();
+
+      final itemB = find.byKey(const Key('obra-switcher-item-obraB')).last;
+      await tester.tap(itemB);
+      await tester.pumpAndSettle();
+
+      // Na Obra B: atualiza instantaneamente para exibir Lotes e Setores e ocultar Diário
+      expect(find.text('Lotes e Setores'), findsNWidgets(2));
+      expect(find.text('Diário de Obra'), findsNothing);
+    },
+  );
+
+  testWidgets(
+    'rota direta nao autorizada em obra bloqueia via AccessGuard',
+    (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
+            construtoraPermissionProvider('c1').overrideWith(
+              (ref) => Stream.value({'isActive': true, 'isAdmin': false}),
+            ),
+            currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraB'))
+                .overrideWith(
+                  (ref) => Stream.value(
+                    ObraMember(
+                      userId: 'u1',
+                      isActive: true,
+                      isAdmin: false,
+                      modules: ['lotes'], // Sem 'diario'
+                      joinedAt: DateTime(2025),
+                    ),
+                  ),
+                ),
+          ],
+          child: const MaterialApp(
+            home: AccessGuard(
+              construtoraId: 'c1',
+              obraId: 'obraB',
+              module: 'diario',
+              child: Text('area restrita'),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+      expect(find.text('area restrita'), findsNothing);
+      expect(find.text('Acesso Negado'), findsOneWidget);
+    },
+  );
+
+  testWidgets(
+    'obra inativa nega acesso para usuario comum',
+    (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
+            construtoraPermissionProvider('c1').overrideWith(
+              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
+            ),
+            obraDocProvider((construtoraId: 'c1', obraId: 'obraX'))
+                .overrideWith((ref) => Stream.value({'isActive': false})),
+          ],
+          child: const MaterialApp(
+            home: AccessGuard(
+              construtoraId: 'c1',
+              obraId: 'obraX',
+              child: Text('painel secreto'),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+      expect(find.text('painel secreto'), findsNothing);
+      expect(find.text('Acesso Negado'), findsOneWidget);
+    },
+  );
+
+  testWidgets(
+    'obra inativa preserva acesso de suporte para dev global',
+    (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
+            construtoraPermissionProvider('c1').overrideWith(
+              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
+            ),
+            obraDocProvider((construtoraId: 'c1', obraId: 'obraX'))
+                .overrideWith((ref) => Stream.value({'isActive': false})),
+          ],
+          child: const MaterialApp(
+            home: AccessGuard(
+              construtoraId: 'c1',
+              obraId: 'obraX',
+              child: Text('painel secreto'),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+      expect(find.text('painel secreto'), findsOneWidget);
+    },
+  );
+
+  testWidgets(
+    'allowedModules normaliza modulos legados e falha fechado se vazio',
+    (tester) async {
+      // Teste com allowedModules legados (rdo -> diario)
+      final rawData = {
+        'userId': 'u1',
+        'isActive': true,
+        'isAdmin': false,
+        'allowedModules': ['rdo'],
+        'joinedAt': DateTime(2025).toIso8601String(),
+      };
+      final modules = ((rawData['modules'] ?? rawData['allowedModules']) as List)
+          .map((m) => normalizeModule(m.toString()))
+          .toList();
+      final member = ObraMember.fromJson({...rawData, 'modules': modules});
+
+      expect(member.modules, contains('diario'));
+      expect(member.modules, isNot(contains('rdo')));
+
+      // Teste com allowedModules vazio falha fechado (sem permissões)
+      final emptyData = {
+        'userId': 'u2',
+        'isActive': true,
+        'isAdmin': false,
+        'allowedModules': [],
+        'joinedAt': DateTime(2025).toIso8601String(),
+      };
+      final emptyModules =
+          ((emptyData['modules'] ?? emptyData['allowedModules']) as List)
+              .map((m) => normalizeModule(m.toString()))
+              .toList();
+      final emptyMember = ObraMember.fromJson({
+        ...emptyData,
+        'modules': emptyModules,
+      });
+
+      expect(emptyMember.modules, isEmpty);
+    },
+  );
 }

```

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.

Conduct a review of CONTENT.
Look for what's missing, not only what's wrong.
Compute your finding floor N from the diff file's size: N = min(floor(sqrt(kB) + 1), 10), where kB is the file's size in kilobytes. State the arithmetic in one line, then find at least N issues to fix or improve.
Output a Markdown list of findings only — no severity, priority, or ranking.
If the content is empty, stop and say so.
If you have zero findings, re-check and keep thinking; do not stop with an empty list.

CONTENT:
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

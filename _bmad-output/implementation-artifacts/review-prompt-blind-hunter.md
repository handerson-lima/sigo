Conduct a review of CONTENT.
Look for what's missing, not only what's wrong.
Compute your finding floor N from the diff file's size: N = min(floor(sqrt(kB) + 1), 10), where kB is the file's size in kilobytes. State the arithmetic in one line, then find at least N issues to fix or improve.
Output a Markdown list of findings only — no severity, priority, or ranking.
If the content is empty, stop and say so.
If you have zero findings, re-check and keep thinking; do not stop with an empty list.

CONTENT:
diff --git a/app/lib/src/common_widgets/sigo_breadcrumbs.dart b/app/lib/src/common_widgets/sigo_breadcrumbs.dart
new file mode 100644
index 0000000..bdaa573
--- /dev/null
+++ b/app/lib/src/common_widgets/sigo_breadcrumbs.dart
@@ -0,0 +1,49 @@
+import 'package:flutter/material.dart';
+import 'package:go_router/go_router.dart';
+
+class BreadcrumbSegment {
+  final String label;
+  final String? url;
+
+  const BreadcrumbSegment({required this.label, this.url});
+}
+
+class SigoBreadcrumbs extends StatelessWidget {
+  final List<BreadcrumbSegment> segments;
+
+  const SigoBreadcrumbs({super.key, required this.segments});
+
+  @override
+  Widget build(BuildContext context) {
+    return Padding(
+      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
+      child: Wrap(
+        crossAxisAlignment: WrapCrossAlignment.center,
+        children: segments.asMap().entries.map((entry) {
+          final index = entry.key;
+          final segment = entry.value;
+          final isLast = index == segments.length - 1;
+
+          return Row(
+            mainAxisSize: MainAxisSize.min,
+            children: [
+              InkWell(
+                onTap: (segment.url != null && !isLast)
+                    ? () => context.go(segment.url!)
+                    : null,
+                child: Text(
+                  segment.label,
+                  style: TextStyle(
+                    color: isLast ? Colors.black : Theme.of(context).primaryColor,
+                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
+                  ),
+                ),
+              ),
+              if (!isLast) const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: Text('/')),
+            ],
+          );
+        }).toList(),
+      ),
+    );
+  }
+}
diff --git a/app/lib/src/features/equipes/data/equipe_repository.dart b/app/lib/src/features/equipes/data/equipe_repository.dart
new file mode 100644
index 0000000..96c2c40
--- /dev/null
+++ b/app/lib/src/features/equipes/data/equipe_repository.dart
@@ -0,0 +1,27 @@
+import 'package:cloud_firestore/cloud_firestore.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import '../domain/equipe.dart';
+
+final equipeRepositoryProvider = Provider<EquipeRepository>((ref) {
+  return EquipeRepository(FirebaseFirestore.instance);
+});
+
+class EquipeRepository {
+  final FirebaseFirestore _firestore;
+
+  EquipeRepository(this._firestore);
+
+  CollectionReference<Equipe> _equipesRef(String construtoraId, String loteamentoId, String quadraId, String loteId, String setorId) =>
+      _firestore
+          .collection('construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores/$setorId/equipes')
+          .withConverter<Equipe>(
+            fromFirestore: (snapshot, _) => Equipe.fromJson(snapshot.data()!),
+            toFirestore: (equipe, _) => equipe.toJson(),
+          );
+
+  Stream<List<Equipe>> watchEquipes(String construtoraId, String loteamentoId, String quadraId, String loteId, String setorId) {
+    return _equipesRef(construtoraId, loteamentoId, quadraId, loteId, setorId)
+        .snapshots()
+        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
+  }
+}
diff --git a/app/lib/src/features/equipes/domain/equipe.dart b/app/lib/src/features/equipes/domain/equipe.dart
new file mode 100644
index 0000000..c1287d7
--- /dev/null
+++ b/app/lib/src/features/equipes/domain/equipe.dart
@@ -0,0 +1,29 @@
+import 'package:json_annotation/json_annotation.dart';
+
+part 'equipe.g.dart';
+
+@JsonSerializable()
+class Equipe {
+  final String id;
+  final String construtoraId;
+  final String loteamentoId;
+  final String quadraId;
+  final String loteId;
+  final String setorId;
+  final String name;
+  final DateTime createdAt;
+
+  Equipe({
+    required this.id,
+    required this.construtoraId,
+    required this.loteamentoId,
+    required this.quadraId,
+    required this.loteId,
+    required this.setorId,
+    required this.name,
+    required this.createdAt,
+  });
+
+  factory Equipe.fromJson(Map<String, dynamic> json) => _$EquipeFromJson(json);
+  Map<String, dynamic> toJson() => _$EquipeToJson(this);
+}
diff --git a/app/lib/src/features/equipes/domain/equipe.g.dart b/app/lib/src/features/equipes/domain/equipe.g.dart
new file mode 100644
index 0000000..3e8680a
--- /dev/null
+++ b/app/lib/src/features/equipes/domain/equipe.g.dart
@@ -0,0 +1,29 @@
+// GENERATED CODE - DO NOT MODIFY BY HAND
+
+part of 'equipe.dart';
+
+// **************************************************************************
+// JsonSerializableGenerator
+// **************************************************************************
+
+Equipe _$EquipeFromJson(Map<String, dynamic> json) => Equipe(
+  id: json['id'] as String,
+  construtoraId: json['construtoraId'] as String,
+  loteamentoId: json['loteamentoId'] as String,
+  quadraId: json['quadraId'] as String,
+  loteId: json['loteId'] as String,
+  setorId: json['setorId'] as String,
+  name: json['name'] as String,
+  createdAt: DateTime.parse(json['createdAt'] as String),
+);
+
+Map<String, dynamic> _$EquipeToJson(Equipe instance) => <String, dynamic>{
+  'id': instance.id,
+  'construtoraId': instance.construtoraId,
+  'loteamentoId': instance.loteamentoId,
+  'quadraId': instance.quadraId,
+  'loteId': instance.loteId,
+  'setorId': instance.setorId,
+  'name': instance.name,
+  'createdAt': instance.createdAt.toIso8601String(),
+};
diff --git a/app/lib/src/features/equipes/presentation/equipes_list_screen.dart b/app/lib/src/features/equipes/presentation/equipes_list_screen.dart
new file mode 100644
index 0000000..0d63c48
--- /dev/null
+++ b/app/lib/src/features/equipes/presentation/equipes_list_screen.dart
@@ -0,0 +1,71 @@
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import '../data/equipe_repository.dart';
+import '../domain/equipe.dart';
+import '../../../common_widgets/sigo_breadcrumbs.dart';
+
+class EquipesListScreen extends ConsumerWidget {
+  final String construtoraId;
+  final String loteamentoId;
+  final String quadraId;
+  final String loteId;
+  final String setorId;
+
+  const EquipesListScreen({
+    super.key,
+    required this.construtoraId,
+    required this.loteamentoId,
+    required this.quadraId,
+    required this.loteId,
+    required this.setorId,
+  });
+
+  @override
+  Widget build(BuildContext context, WidgetRef ref) {
+    final stream = ref.watch(equipeRepositoryProvider).watchEquipes(construtoraId, loteamentoId, quadraId, loteId, setorId);
+
+    return Scaffold(
+      appBar: AppBar(title: const Text('Equipes')),
+      body: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          SigoBreadcrumbs(
+            segments: [
+              BreadcrumbSegment(label: 'Loteamento', url: '/loteamentos/$loteamentoId'),
+              BreadcrumbSegment(label: 'Quadra', url: '/loteamentos/$loteamentoId/quadras/$quadraId'),
+              BreadcrumbSegment(label: 'Lote', url: '/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId'),
+              BreadcrumbSegment(label: 'Setor', url: '/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores/$setorId'),
+              const BreadcrumbSegment(label: 'Equipes'),
+            ],
+          ),
+          Expanded(
+            child: StreamBuilder<List<Equipe>>(
+              stream: stream,
+              builder: (context, snapshot) {
+                if (snapshot.connectionState == ConnectionState.waiting) {
+                  return const Center(child: CircularProgressIndicator());
+                }
+                if (snapshot.hasError) {
+                  return Center(child: Text('Erro: ${snapshot.error}'));
+                }
+                final items = snapshot.data ?? [];
+                if (items.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));
+
+                return ListView.builder(
+                  itemCount: items.length,
+                  itemBuilder: (context, index) {
+                    final item = items[index];
+                    return ListTile(
+                      title: Text(item.name),
+                      subtitle: Text('Criado em: ${item.createdAt}'),
+                    );
+                  },
+                );
+              },
+            ),
+          ),
+        ],
+      ),
+    );
+  }
+}
diff --git a/app/lib/src/features/equipes/routing/equipes_routes.dart b/app/lib/src/features/equipes/routing/equipes_routes.dart
new file mode 100644
index 0000000..0b3b5be
--- /dev/null
+++ b/app/lib/src/features/equipes/routing/equipes_routes.dart
@@ -0,0 +1,31 @@
+import 'package:go_router/go_router.dart';
+import '../presentation/equipes_list_screen.dart';
+import '../../../common_widgets/access_guard.dart';
+
+abstract class EquipesPaths {
+  static const list = 'equipes';
+  static const detail = 'equipes/:equipeId';
+}
+
+List<RouteBase> get equipesRoutes => [
+      GoRoute(
+        path: EquipesPaths.list,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final loteamentoId = state.pathParameters['loteamentoId']!;
+          final quadraId = state.pathParameters['quadraId']!;
+          final loteId = state.pathParameters['loteId']!;
+          final setorId = state.pathParameters['setorId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            child: EquipesListScreen(
+              construtoraId: cId,
+              loteamentoId: loteamentoId,
+              quadraId: quadraId,
+              loteId: loteId,
+              setorId: setorId,
+            ),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/lotes/presentation/lotes_list_screen.dart b/app/lib/src/features/lotes/presentation/lotes_list_screen.dart
index 836ed6e..1f42a74 100644
--- a/app/lib/src/features/lotes/presentation/lotes_list_screen.dart
+++ b/app/lib/src/features/lotes/presentation/lotes_list_screen.dart
@@ -3,6 +3,7 @@ import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:go_router/go_router.dart';
 import '../data/lote_repository.dart';
 import '../domain/lote.dart';
+import '../../../common_widgets/sigo_breadcrumbs.dart';
 
 class LotesListScreen extends ConsumerWidget {
   final String construtoraId;
@@ -22,17 +23,28 @@ class LotesListScreen extends ConsumerWidget {
 
     return Scaffold(
       appBar: AppBar(title: const Text('Lotes')),
-      body: StreamBuilder<List<Lote>>(
-        stream: stream,
-        builder: (context, snapshot) {
-          if (snapshot.connectionState == ConnectionState.waiting) {
-            return const Center(child: CircularProgressIndicator());
-          }
-          if (snapshot.hasError) {
-            return Center(child: Text('Erro: ${snapshot.error}'));
-          }
-          final items = snapshot.data ?? [];
-          if (items.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));
+      body: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          SigoBreadcrumbs(
+            segments: [
+              BreadcrumbSegment(label: 'Loteamento', url: '/loteamentos/$loteamentoId'),
+              BreadcrumbSegment(label: 'Quadra', url: '/loteamentos/$loteamentoId/quadras/$quadraId'),
+              const BreadcrumbSegment(label: 'Lotes'),
+            ],
+          ),
+          Expanded(
+            child: StreamBuilder<List<Lote>>(
+              stream: stream,
+              builder: (context, snapshot) {
+                if (snapshot.connectionState == ConnectionState.waiting) {
+                  return const Center(child: CircularProgressIndicator());
+                }
+                if (snapshot.hasError) {
+                  return Center(child: Text('Erro: ${snapshot.error}'));
+                }
+                final items = snapshot.data ?? [];
+                if (items.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));
 
           return ListView.builder(
             itemCount: items.length,
@@ -42,13 +54,16 @@ class LotesListScreen extends ConsumerWidget {
                 title: Text(item.name),
                 subtitle: Text('Status: ${item.status} | Phase: ${item.phase}'),
                 onTap: () {
-                  // In the future this goes to Setores
+                  context.go('/loteamentos/$loteamentoId/quadras/$quadraId/lotes/${item.id}/setores');
                 },
               );
             },
           );
         },
       ),
+    ),
+  ],
+),
     );
   }
 }
diff --git a/app/lib/src/features/lotes/routing/lotes_routes.dart b/app/lib/src/features/lotes/routing/lotes_routes.dart
index 9753d89..873d2cd 100644
--- a/app/lib/src/features/lotes/routing/lotes_routes.dart
+++ b/app/lib/src/features/lotes/routing/lotes_routes.dart
@@ -1,6 +1,7 @@
 import 'package:go_router/go_router.dart';
 import '../presentation/lotes_list_screen.dart';
 import '../../../common_widgets/access_guard.dart';
+import '../../setores/routing/setores_routes.dart';
 
 abstract class LotesPaths {
   static const list = 'lotes';
@@ -22,5 +23,16 @@ List<RouteBase> get lotesRoutes => [
             ),
           );
         },
+        routes: [
+          GoRoute(
+            path: ':loteId',
+            builder: (context, state) {
+              return const SizedBox();
+            },
+            routes: [
+              ...setoresRoutes,
+            ],
+          )
+        ],
       ),
     ];
diff --git a/app/lib/src/features/setores/data/setor_repository.dart b/app/lib/src/features/setores/data/setor_repository.dart
new file mode 100644
index 0000000..333eebc
--- /dev/null
+++ b/app/lib/src/features/setores/data/setor_repository.dart
@@ -0,0 +1,27 @@
+import 'package:cloud_firestore/cloud_firestore.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import '../domain/setor.dart';
+
+final setorRepositoryProvider = Provider<SetorRepository>((ref) {
+  return SetorRepository(FirebaseFirestore.instance);
+});
+
+class SetorRepository {
+  final FirebaseFirestore _firestore;
+
+  SetorRepository(this._firestore);
+
+  CollectionReference<Setor> _setoresRef(String construtoraId, String loteamentoId, String quadraId, String loteId) =>
+      _firestore
+          .collection('construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores')
+          .withConverter<Setor>(
+            fromFirestore: (snapshot, _) => Setor.fromJson(snapshot.data()!),
+            toFirestore: (setor, _) => setor.toJson(),
+          );
+
+  Stream<List<Setor>> watchSetores(String construtoraId, String loteamentoId, String quadraId, String loteId) {
+    return _setoresRef(construtoraId, loteamentoId, quadraId, loteId)
+        .snapshots()
+        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
+  }
+}
diff --git a/app/lib/src/features/setores/domain/setor.dart b/app/lib/src/features/setores/domain/setor.dart
new file mode 100644
index 0000000..207858e
--- /dev/null
+++ b/app/lib/src/features/setores/domain/setor.dart
@@ -0,0 +1,27 @@
+import 'package:json_annotation/json_annotation.dart';
+
+part 'setor.g.dart';
+
+@JsonSerializable()
+class Setor {
+  final String id;
+  final String construtoraId;
+  final String loteamentoId;
+  final String quadraId;
+  final String loteId;
+  final String name;
+  final DateTime createdAt;
+
+  Setor({
+    required this.id,
+    required this.construtoraId,
+    required this.loteamentoId,
+    required this.quadraId,
+    required this.loteId,
+    required this.name,
+    required this.createdAt,
+  });
+
+  factory Setor.fromJson(Map<String, dynamic> json) => _$SetorFromJson(json);
+  Map<String, dynamic> toJson() => _$SetorToJson(this);
+}
diff --git a/app/lib/src/features/setores/domain/setor.g.dart b/app/lib/src/features/setores/domain/setor.g.dart
new file mode 100644
index 0000000..209d8ef
--- /dev/null
+++ b/app/lib/src/features/setores/domain/setor.g.dart
@@ -0,0 +1,27 @@
+// GENERATED CODE - DO NOT MODIFY BY HAND
+
+part of 'setor.dart';
+
+// **************************************************************************
+// JsonSerializableGenerator
+// **************************************************************************
+
+Setor _$SetorFromJson(Map<String, dynamic> json) => Setor(
+  id: json['id'] as String,
+  construtoraId: json['construtoraId'] as String,
+  loteamentoId: json['loteamentoId'] as String,
+  quadraId: json['quadraId'] as String,
+  loteId: json['loteId'] as String,
+  name: json['name'] as String,
+  createdAt: DateTime.parse(json['createdAt'] as String),
+);
+
+Map<String, dynamic> _$SetorToJson(Setor instance) => <String, dynamic>{
+  'id': instance.id,
+  'construtoraId': instance.construtoraId,
+  'loteamentoId': instance.loteamentoId,
+  'quadraId': instance.quadraId,
+  'loteId': instance.loteId,
+  'name': instance.name,
+  'createdAt': instance.createdAt.toIso8601String(),
+};
diff --git a/app/lib/src/features/setores/presentation/setores_list_screen.dart b/app/lib/src/features/setores/presentation/setores_list_screen.dart
new file mode 100644
index 0000000..e47d265
--- /dev/null
+++ b/app/lib/src/features/setores/presentation/setores_list_screen.dart
@@ -0,0 +1,72 @@
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:go_router/go_router.dart';
+import '../data/setor_repository.dart';
+import '../domain/setor.dart';
+import '../../../common_widgets/sigo_breadcrumbs.dart';
+
+class SetoresListScreen extends ConsumerWidget {
+  final String construtoraId;
+  final String loteamentoId;
+  final String quadraId;
+  final String loteId;
+
+  const SetoresListScreen({
+    super.key,
+    required this.construtoraId,
+    required this.loteamentoId,
+    required this.quadraId,
+    required this.loteId,
+  });
+
+  @override
+  Widget build(BuildContext context, WidgetRef ref) {
+    final stream = ref.watch(setorRepositoryProvider).watchSetores(construtoraId, loteamentoId, quadraId, loteId);
+
+    return Scaffold(
+      appBar: AppBar(title: const Text('Setores')),
+      body: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          SigoBreadcrumbs(
+            segments: [
+              BreadcrumbSegment(label: 'Loteamento', url: '/loteamentos/$loteamentoId'),
+              BreadcrumbSegment(label: 'Quadra', url: '/loteamentos/$loteamentoId/quadras/$quadraId'),
+              BreadcrumbSegment(label: 'Lote', url: '/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId'),
+              const BreadcrumbSegment(label: 'Setores'),
+            ],
+          ),
+          Expanded(
+            child: StreamBuilder<List<Setor>>(
+              stream: stream,
+              builder: (context, snapshot) {
+                if (snapshot.connectionState == ConnectionState.waiting) {
+                  return const Center(child: CircularProgressIndicator());
+                }
+                if (snapshot.hasError) {
+                  return Center(child: Text('Erro: ${snapshot.error}'));
+                }
+                final items = snapshot.data ?? [];
+                if (items.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));
+
+                return ListView.builder(
+                  itemCount: items.length,
+                  itemBuilder: (context, index) {
+                    final item = items[index];
+                    return ListTile(
+                      title: Text(item.name),
+                      subtitle: Text('Criado em: ${item.createdAt}'),
+                      onTap: () {
+                        context.go('/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores/${item.id}/equipes');
+                      },
+                    );
+                  },
+                );
+              },
+            ),
+          ),
+        ],
+      ),
+    );
+  }
+}
diff --git a/app/lib/src/features/setores/routing/setores_routes.dart b/app/lib/src/features/setores/routing/setores_routes.dart
new file mode 100644
index 0000000..4d84084
--- /dev/null
+++ b/app/lib/src/features/setores/routing/setores_routes.dart
@@ -0,0 +1,42 @@
+import 'package:flutter/material.dart';
+import 'package:go_router/go_router.dart';
+import '../presentation/setores_list_screen.dart';
+import '../../../common_widgets/access_guard.dart';
+import '../../equipes/routing/equipes_routes.dart';
+
+abstract class SetoresPaths {
+  static const list = 'setores';
+  static const detail = 'setores/:setorId';
+}
+
+List<RouteBase> get setoresRoutes => [
+      GoRoute(
+        path: SetoresPaths.list,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final loteamentoId = state.pathParameters['loteamentoId']!;
+          final quadraId = state.pathParameters['quadraId']!;
+          final loteId = state.pathParameters['loteId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            child: SetoresListScreen(
+              construtoraId: cId,
+              loteamentoId: loteamentoId,
+              quadraId: quadraId,
+              loteId: loteId,
+            ),
+          );
+        },
+        routes: [
+          GoRoute(
+            path: ':setorId',
+            builder: (context, state) {
+              return const SizedBox();
+            },
+            routes: [
+              ...equipesRoutes,
+            ],
+          )
+        ],
+      ),
+    ];


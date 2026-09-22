Conduct a review of CONTENT.
Look for what's missing, not only what's wrong.
Compute your finding floor N from the diff file's size: N = min(floor(sqrt(kB) + 1), 10), where kB is the file's size in kilobytes. State the arithmetic in one line, then find at least N issues to fix or improve.
Output a Markdown list of findings only — no severity, priority, or ranking.
If the content is empty, stop and say so.
If you have zero findings, re-check and keep thinking; do not stop with an empty list.

CONTENT:
```diff
diff --git a/_bmad-output/implementation-artifacts/sprint-status.yaml b/_bmad-output/implementation-artifacts/sprint-status.yaml
index 3942235..339cdf9 100644
--- a/_bmad-output/implementation-artifacts/sprint-status.yaml
+++ b/_bmad-output/implementation-artifacts/sprint-status.yaml
@@ -114,8 +114,8 @@ development_status:
   8-3-detalhe-do-membro: done
   epic-8-retrospective: done
 
-  epic-9: backlog
-  9-1-atribuir-operario-a-obra: backlog
+  epic-9: in-progress
+  9-1-atribuir-operario-a-obra: in-progress
   9-2-atribuir-admin-erros-e-offline: backlog
   epic-9-retrospective: optional
 
diff --git a/app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart b/app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart
index d93b83d..6587dfb 100644
--- a/app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart
+++ b/app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart
@@ -6,6 +6,7 @@ import '../../obras/domain/obra_member.dart';
 import '../domain/construtora_member.dart';
 import '../domain/membro.dart';
 import 'membros_providers.dart';
+import 'widgets/atribuir_obra_dialog.dart';
 import 'widgets/obra_vinculo_row.dart';
 import 'widgets/role_chip.dart';
 
@@ -165,39 +166,42 @@ class MemberDetalheSheet extends ConsumerWidget {
               ),
             ),
             const SizedBox(height: 4),
-            Semantics(
-              label: 'Disponível em breve',
-              child: Column(
-                mainAxisSize: MainAxisSize.min,
-                crossAxisAlignment: CrossAxisAlignment.stretch,
-                children: [
-                  Text(
-                    'Disponível em breve',
-                    style: theme.textTheme.bodySmall?.copyWith(
-                      color: theme.colorScheme.onSurfaceVariant,
+            Column(
+              mainAxisSize: MainAxisSize.min,
+              crossAxisAlignment: CrossAxisAlignment.stretch,
+              children: [
+                Wrap(
+                  spacing: 8,
+                  runSpacing: 8,
+                  children: [
+                    FilledButton.tonal(
+                      onPressed: vinculo?.isActive == true
+                          ? () => AtribuirObraDialog.show(
+                                context: context,
+                                construtoraId: construtoraId,
+                                membro: membro,
+                              )
+                          : null,
+                      child: const Text('Atribuir à obra'),
                     ),
+                    OutlinedButton(
+                      onPressed: null,
+                      child: const Text('Trocar cargo'),
+                    ),
+                    OutlinedButton(
+                      onPressed: null,
+                      child: const Text('Desativar'),
+                    ),
+                  ],
+                ),
+                const SizedBox(height: 8),
+                Text(
+                  'Disponível em breve',
+                  style: theme.textTheme.bodySmall?.copyWith(
+                    color: theme.colorScheme.onSurfaceVariant,
                   ),
-                  const SizedBox(height: 8),
-                  Wrap(
-                    spacing: 8,
-                    runSpacing: 8,
-                    children: [
-                      FilledButton.tonal(
-                        onPressed: null,
-                        child: const Text('Atribuir à obra'),
-                      ),
-                      OutlinedButton(
-                        onPressed: null,
-                        child: const Text('Trocar cargo'),
-                      ),
-                      OutlinedButton(
-                        onPressed: null,
-                        child: const Text('Desativar'),
-                      ),
-                    ],
-                  ),
-                ],
-              ),
+                ),
+              ],
             ),
           ],
         ),
diff --git a/app/lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart b/app/lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart
new file mode 100644
index 0000000..3af3ce9
--- /dev/null
+++ b/app/lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart
@@ -0,0 +1,424 @@
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+
+import '../../../obras/data/obra_members_repository.dart';
+import '../../../obras/domain/obra.dart';
+import '../../domain/membro.dart';
+import '../membros_providers.dart';
+
+/// Diálogo de atribuição de operário a uma obra (Epic 9.1 / UX-DR4).
+class AtribuirObraDialog extends ConsumerStatefulWidget {
+  final String construtoraId;
+  final Membro membro;
+
+  const AtribuirObraDialog({
+    super.key,
+    required this.construtoraId,
+    required this.membro,
+  });
+
+  static Future<void> show({
+    required BuildContext context,
+    required String construtoraId,
+    required Membro membro,
+  }) {
+    return showDialog<void>(
+      context: context,
+      builder: (context) => AtribuirObraDialog(
+        construtoraId: construtoraId,
+        membro: membro,
+      ),
+    );
+  }
+
+  @override
+  ConsumerState<AtribuirObraDialog> createState() => _AtribuirObraDialogState();
+}
+
+class _AtribuirObraDialogState extends ConsumerState<AtribuirObraDialog> {
+  String? _selectedObraId;
+  bool _isSubmitting = false;
+  String? _errorMessage;
+
+  final Map<String, bool> _modules = {
+    'diario': true,
+    'lotes': false,
+    'estoque': false,
+  };
+
+  static const Map<String, String> _moduleLabels = {
+    'diario': 'Diário de Obras',
+    'lotes': 'Lotes',
+    'estoque': 'Estoque',
+  };
+
+  static const Map<String, String> _moduleSummaryLabels = {
+    'diario': 'Diário',
+    'lotes': 'Lotes',
+    'estoque': 'Estoque',
+  };
+
+  String get _identificadorMembro {
+    final email = widget.membro.email.trim();
+    return email.isNotEmpty ? email : 'UID: ${widget.membro.uid}';
+  }
+
+  String _gerarResumo(List<Obra> obras) {
+    if (_selectedObraId == null) {
+      return 'Selecione uma obra para ver o resumo da atribuição.';
+    }
+    final obra = obras.firstWhere(
+      (o) => o.id == _selectedObraId,
+      orElse: () => Obra(
+        id: _selectedObraId!,
+        construtoraId: widget.construtoraId,
+        name: 'Obra',
+        createdAt: DateTime.now(),
+      ),
+    );
+    final obraNome = obra.name.trim().isNotEmpty ? obra.name : 'Obra ${obra.id}';
+
+    final selecionados = _modules.entries
+        .where((e) => e.value)
+        .map((e) => _moduleSummaryLabels[e.key] ?? e.key)
+        .toList();
+
+    final modulosTexto =
+        selecionados.isEmpty ? 'nenhum módulo' : selecionados.join(', ');
+
+    return '$_identificadorMembro será Operário em $obraNome com acesso a $modulosTexto';
+  }
+
+  Future<void> _confirmar(String obraNome) async {
+    if (_selectedObraId == null || _isSubmitting) return;
+
+    setState(() {
+      _isSubmitting = true;
+      _errorMessage = null;
+    });
+
+    final selectedModules = _modules.entries
+        .where((e) => e.value)
+        .map((e) => e.key)
+        .toList();
+
+    try {
+      await ref.read(obraMembersRepositoryProvider).setMembership(
+            construtoraId: widget.construtoraId,
+            obraId: _selectedObraId!,
+            userId: widget.membro.uid,
+            role: 'operario',
+            modules: selectedModules,
+            isActive: true,
+          );
+
+      // Invalidação completa dos providers de membros para refletir o novo vínculo
+      final cid = widget.construtoraId;
+      final uid = widget.membro.uid;
+      final oid = _selectedObraId!;
+
+      ref.invalidate(membrosProvider(cid));
+      ref.invalidate(contagemObrasPorMembroProvider(cid));
+      ref.invalidate(contagemObrasMetaProvider(cid));
+      ref.invalidate(memberDetalheProvider((construtoraId: cid, uid: uid)));
+      ref.invalidate(obrasVinculadasProvider((construtoraId: cid, uid: uid)));
+      ref.invalidate(obraMembersProvider((construtoraId: cid, obraId: oid)));
+
+      if (mounted) {
+        Navigator.of(context).pop();
+        ScaffoldMessenger.of(context).showSnackBar(
+          SnackBar(
+            content: Text('Atribuído a $obraNome como Operário.'),
+          ),
+        );
+      }
+    } catch (e) {
+      if (mounted) {
+        setState(() {
+          _isSubmitting = false;
+          _errorMessage = e.toString().replaceFirst('Exception: ', '');
+        });
+      }
+    }
+  }
+
+  @override
+  Widget build(BuildContext context) {
+    final theme = Theme.of(context);
+    final obrasAsync = ref.watch(obrasAtivasProvider(widget.construtoraId));
+    final key = (construtoraId: widget.construtoraId, uid: widget.membro.uid);
+    final obrasVinculadas = ref.watch(obrasVinculadasProvider(key));
+
+    final idsJaVinculados = obrasVinculadas.map((e) => e.obra.id).toSet();
+
+    return Dialog(
+      shape: RoundedRectangleBorder(
+        borderRadius: BorderRadius.circular(16),
+      ),
+      child: ConstrainedBox(
+        constraints: BoxConstraints(
+          maxWidth: 480,
+          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
+        ),
+        child: SingleChildScrollView(
+          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
+          child: obrasAsync.when(
+            loading: () => const Padding(
+              padding: EdgeInsets.symmetric(vertical: 32),
+              child: Center(
+                child: SizedBox(
+                  width: 32,
+                  height: 32,
+                  child: CircularProgressIndicator(strokeWidth: 2),
+                ),
+              ),
+            ),
+            error: (err, _) => Column(
+              mainAxisSize: MainAxisSize.min,
+              crossAxisAlignment: CrossAxisAlignment.stretch,
+              children: [
+                Text(
+                  'Erro ao carregar obras.',
+                  style: theme.textTheme.titleMedium,
+                ),
+                const SizedBox(height: 16),
+                Align(
+                  alignment: Alignment.centerRight,
+                  child: TextButton(
+                    onPressed: () => Navigator.of(context).pop(),
+                    child: const Text('Fechar'),
+                  ),
+                ),
+              ],
+            ),
+            data: (todasObrasAtivas) {
+              final obrasDisponiveis = todasObrasAtivas
+                  .where((o) => !idsJaVinculados.contains(o.id))
+                  .toList();
+
+              final obraSelecionadaObj = _selectedObraId == null
+                  ? null
+                  : todasObrasAtivas.cast<Obra?>().firstWhere(
+                        (o) => o?.id == _selectedObraId,
+                        orElse: () => null,
+                      );
+
+              final obraSelecionadaNome =
+                  (obraSelecionadaObj?.name.trim().isNotEmpty == true)
+                      ? obraSelecionadaObj!.name
+                      : (_selectedObraId != null ? 'Obra $_selectedObraId' : 'Obra');
+              final temObras = obrasDisponiveis.isNotEmpty;
+
+              return Column(
+                mainAxisSize: MainAxisSize.min,
+                crossAxisAlignment: CrossAxisAlignment.stretch,
+                children: [
+                  Row(
+                    children: [
+                      Expanded(
+                        child: Text(
+                          'Atribuir à obra',
+                          style: theme.textTheme.titleLarge?.copyWith(
+                            fontWeight: FontWeight.bold,
+                          ),
+                        ),
+                      ),
+                      IconButton(
+                        icon: const Icon(Icons.close),
+                        tooltip: 'Fechar',
+                        onPressed: () => Navigator.of(context).pop(),
+                      ),
+                    ],
+                  ),
+                  const SizedBox(height: 4),
+                  Text(
+                    'Membro: $_identificadorMembro',
+                    style: theme.textTheme.bodyMedium?.copyWith(
+                      color: theme.colorScheme.onSurfaceVariant,
+                    ),
+                  ),
+                  const SizedBox(height: 12),
+                  Text(
+                    'Obra',
+                    style: theme.textTheme.labelLarge?.copyWith(
+                      fontWeight: FontWeight.w600,
+                    ),
+                  ),
+                  const SizedBox(height: 4),
+                  if (!temObras)
+                    InputDecorator(
+                      decoration: const InputDecoration(
+                        border: OutlineInputBorder(),
+                        contentPadding:
+                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
+                      ),
+                      child: Text(
+                        'Nenhuma obra ativa',
+                        style: theme.textTheme.bodyMedium?.copyWith(
+                          color: theme.colorScheme.onSurfaceVariant,
+                        ),
+                      ),
+                    )
+                  else
+                    DropdownButtonFormField<String>(
+                      initialValue: _selectedObraId,
+                      decoration: const InputDecoration(
+                        border: OutlineInputBorder(),
+                        contentPadding:
+                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
+                        hintText: 'Selecione a obra',
+                      ),
+                      items: obrasDisponiveis.map((obra) {
+                        final label = obra.name.trim().isNotEmpty
+                            ? obra.name
+                            : 'Obra ${obra.id}';
+                        return DropdownMenuItem<String>(
+                          value: obra.id,
+                          child: Text(
+                            label,
+                            overflow: TextOverflow.ellipsis,
+                          ),
+                        );
+                      }).toList(),
+                      onChanged: _isSubmitting
+                          ? null
+                          : (val) {
+                              setState(() {
+                                _selectedObraId = val;
+                              });
+                            },
+                    ),
+                  const SizedBox(height: 12),
+                  Text(
+                    'Papel na obra',
+                    style: theme.textTheme.labelLarge?.copyWith(
+                      fontWeight: FontWeight.w600,
+                    ),
+                  ),
+                  const SizedBox(height: 4),
+                  InputDecorator(
+                    decoration: const InputDecoration(
+                      border: OutlineInputBorder(),
+                      contentPadding:
+                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
+                    ),
+                    child: Row(
+                      children: [
+                        const Icon(Icons.engineering, size: 20),
+                        const SizedBox(width: 8),
+                        Text(
+                          'Operário',
+                          style: theme.textTheme.bodyMedium?.copyWith(
+                            fontWeight: FontWeight.w500,
+                          ),
+                        ),
+                      ],
+                    ),
+                  ),
+                  const SizedBox(height: 12),
+                  Text(
+                    'Módulos de acesso',
+                    style: theme.textTheme.labelLarge?.copyWith(
+                      fontWeight: FontWeight.w600,
+                    ),
+                  ),
+                  ..._modules.keys.map((modKey) {
+                    final label = _moduleLabels[modKey] ?? modKey;
+                    final isChecked = _modules[modKey] ?? false;
+                    return CheckboxListTile(
+                      dense: true,
+                      visualDensity: VisualDensity.compact,
+                      contentPadding: EdgeInsets.zero,
+                      title: Text(label),
+                      value: isChecked,
+                      onChanged: _isSubmitting
+                          ? null
+                          : (bool? val) {
+                              setState(() {
+                                _modules[modKey] = val ?? false;
+                              });
+                            },
+                    );
+                  }),
+                  const SizedBox(height: 8),
+                  Container(
+                    padding: const EdgeInsets.all(10),
+                    decoration: BoxDecoration(
+                      color: theme.colorScheme.surfaceContainerHighest
+                          .withValues(alpha: 0.5),
+                      borderRadius: BorderRadius.circular(8),
+                      border: Border.all(
+                        color: theme.colorScheme.outlineVariant,
+                      ),
+                    ),
+                    child: Column(
+                      crossAxisAlignment: CrossAxisAlignment.start,
+                      children: [
+                        Text(
+                          'Resumo da atribuição',
+                          style: theme.textTheme.labelMedium?.copyWith(
+                            fontWeight: FontWeight.bold,
+                            color: theme.colorScheme.primary,
+                          ),
+                        ),
+                        const SizedBox(height: 2),
+                        Text(
+                          _gerarResumo(todasObrasAtivas),
+                          style: theme.textTheme.bodySmall?.copyWith(
+                            color: theme.colorScheme.onSurface,
+                          ),
+                        ),
+                      ],
+                    ),
+                  ),
+                  if (_errorMessage != null) ...[
+                    const SizedBox(height: 8),
+                    Text(
+                      _errorMessage!,
+                      style: theme.textTheme.bodySmall?.copyWith(
+                        color: theme.colorScheme.error,
+                        fontWeight: FontWeight.w600,
+                      ),
+                    ),
+                  ],
+                  const SizedBox(height: 16),
+                  Wrap(
+                    alignment: WrapAlignment.end,
+                    crossAxisAlignment: WrapCrossAlignment.center,
+                    spacing: 12,
+                    runSpacing: 8,
+                    children: [
+                      TextButton(
+                        onPressed: _isSubmitting
+                            ? null
+                            : () => Navigator.of(context).pop(),
+                        child: const Text('Cancelar'),
+                      ),
+                      FilledButton(
+                        onPressed: (_selectedObraId != null &&
+                                temObras &&
+                                !_isSubmitting)
+                            ? () => _confirmar(obraSelecionadaNome)
+                            : null,
+                        child: _isSubmitting
+                            ? const SizedBox(
+                                width: 18,
+                                height: 18,
+                                child: CircularProgressIndicator(
+                                  strokeWidth: 2,
+                                  color: Colors.white,
+                                ),
+                              )
+                            : const Text('Confirmar atribuição'),
+                      ),
+                    ],
+                  ),
+                ],
+              );
+            },
+          ),
+        ),
+      ),
+    );
+  }
+}
diff --git a/app/lib/src/features/obras/data/obra_members_repository.dart b/app/lib/src/features/obras/data/obra_members_repository.dart
new file mode 100644
index 0000000..b68c3ab
--- /dev/null
+++ b/app/lib/src/features/obras/data/obra_members_repository.dart
@@ -0,0 +1,42 @@
+import 'package:cloud_functions/cloud_functions.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+
+/// Repositório responsável pela gestão de membros de obra via Cloud Functions autorizadas.
+class ObraMembersRepository {
+  final FirebaseFunctions _functions;
+
+  ObraMembersRepository(this._functions);
+
+  /// Chama a Cloud Function autoritativa `setMembership` para atribuir ou atualizar
+  /// papel e módulos de um membro em uma obra específica.
+  Future<void> setMembership({
+    required String construtoraId,
+    required String obraId,
+    required String userId,
+    required String role,
+    required List<String> modules,
+    bool isActive = true,
+  }) async {
+    try {
+      final callable = _functions.httpsCallable('setMembership');
+      await callable.call({
+        'construtoraId': construtoraId,
+        'obraId': obraId,
+        'userId': userId,
+        'role': role,
+        'modules': modules,
+        'isActive': isActive,
+      });
+    } on FirebaseFunctionsException catch (e) {
+      throw Exception(e.message ?? 'Erro ao chamar setMembership');
+    } catch (e) {
+      throw Exception('Erro desconhecido: $e');
+    }
+  }
+}
+
+final obraMembersRepositoryProvider = Provider<ObraMembersRepository>((ref) {
+  return ObraMembersRepository(
+    FirebaseFunctions.instance,
+  );
+});
diff --git a/app/test/features/construtoras/membros_test.dart b/app/test/features/construtoras/membros_test.dart
index 2e15543..3c1f751 100644
--- a/app/test/features/construtoras/membros_test.dart
+++ b/app/test/features/construtoras/membros_test.dart
@@ -8,12 +8,42 @@ import 'package:app/src/features/construtoras/presentation/membros_screen.dart';
 import 'package:app/src/features/construtoras/presentation/widgets/obra_vinculo_row.dart';
 import 'package:app/src/features/obras/domain/obra.dart';
 import 'package:app/src/features/obras/domain/obra_member.dart';
+import 'package:app/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart';
+import 'package:app/src/features/obras/data/obra_members_repository.dart';
 import 'package:cloud_firestore/cloud_firestore.dart';
 import 'package:flutter/material.dart';
 import 'package:flutter/services.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:flutter_test/flutter_test.dart';
 
+class FakeObraMembersRepository implements ObraMembersRepository {
+  final List<Map<String, dynamic>> chamadas = [];
+  bool deveFalhar = false;
+  String mensagemErro = 'Erro simulado';
+
+  @override
+  Future<void> setMembership({
+    required String construtoraId,
+    required String obraId,
+    required String userId,
+    required String role,
+    required List<String> modules,
+    bool isActive = true,
+  }) async {
+    if (deveFalhar) {
+      throw Exception(mensagemErro);
+    }
+    chamadas.add({
+      'construtoraId': construtoraId,
+      'obraId': obraId,
+      'userId': userId,
+      'role': role,
+      'modules': modules,
+      'isActive': isActive,
+    });
+  }
+}
+
 ObraMember _om(String uid, {bool isActive = true, bool isAdmin = false}) =>
     ObraMember(
       userId: uid,
@@ -30,6 +60,21 @@ Obra _obra(String id, {bool isActive = true}) => Obra(
       isActive: isActive,
     );
 
+ConstrutoraMember _cm(
+  String uid, {
+  bool isActive = true,
+  bool isOwner = false,
+  bool isAdmin = false,
+  DateTime? joinedAt,
+}) =>
+    ConstrutoraMember(
+      userId: uid,
+      isActive: isActive,
+      isOwner: isOwner,
+      isAdmin: isAdmin,
+      joinedAt: joinedAt ?? DateTime(2026, 1, 15),
+    );
+
 void main() {
   group('8.1 agregação uid→N', () {
     test('soma obras por uid ignorando inativos', () {
@@ -1237,7 +1282,7 @@ void main() {
       final atribuir = tester.widget<FilledButton>(
         find.widgetWithText(FilledButton, 'Atribuir à obra'),
       );
-      expect(atribuir.onPressed, isNull);
+      expect(atribuir.onPressed, isNotNull);
     });
 
     testWidgets('8.3 sem obras mostra microcopy estática sem CTA',
@@ -1255,9 +1300,12 @@ void main() {
       );
       expect(find.byType(ObraVinculoRow), findsNothing);
       expect(find.byType(ObraVinculoVazio), findsOneWidget);
-      final ctaAcionavel = tester
-          .widgetList<FilledButton>(find.byType(FilledButton))
-          .where((b) => b.onPressed != null);
+      final ctaAcionavel = tester.widgetList<FilledButton>(
+        find.descendant(
+          of: find.byType(ObraVinculoVazio),
+          matching: find.byType(FilledButton),
+        ),
+      );
       expect(ctaAcionavel, isEmpty);
     });
 
@@ -1690,4 +1738,274 @@ void main() {
       expect(leituras, greaterThan(1));
     });
   });
+
+  group('9.1 atribuir operário à obra', () {
+    late FakeObraMembersRepository fakeObraMembersRepo;
+
+    setUp(() {
+      fakeObraMembersRepo = FakeObraMembersRepository();
+    });
+
+    final membros91 = [
+      Membro(uid: 'u1', email: 'ana@obra.com', isAdmin: false, role: 'operario'),
+      Membro(uid: 'u2', email: 'inativo@obra.com', isAdmin: false, role: 'operario'),
+    ];
+
+    base91({
+      List<Membro>? membros,
+      List<Obra>? obras,
+      Map<String, List<ObraMember>>? porObra,
+      Future<ConstrutoraMember?> Function()? vinculoFuture,
+      String uid = 'u1',
+    }) {
+      return [
+        obraMembersRepositoryProvider.overrideWithValue(fakeObraMembersRepo),
+        membrosProvider('c-1').overrideWith(
+          (ref) => Stream.value(membros ?? membros91),
+        ),
+        pendingRequestsProvider('c-1').overrideWith(
+          (ref) => Stream.value(const []),
+        ),
+        obrasDaConstrutoraProvider('c-1').overrideWith(
+          (ref) => Stream.value(obras ?? [_obra('o1'), _obra('o2')]),
+        ),
+        for (final entry in (porObra ??
+                {
+                  'o1': [_om('u1')],
+                  'o2': <ObraMember>[],
+                })
+            .entries)
+          obraMembersProvider((construtoraId: 'c-1', obraId: entry.key))
+              .overrideWith((ref) => Stream.value(entry.value)),
+        memberDetalheProvider((construtoraId: 'c-1', uid: uid)).overrideWith(
+          (ref) =>
+              vinculoFuture?.call() ??
+              Future<ConstrutoraMember?>.value(
+                _cm(uid, isActive: uid != 'u2'),
+              ),
+        ),
+      ];
+    }
+
+    testWidgets('9.1 HAPPY_PATH: abre dialog, seleciona obra, resumo ao vivo, confirma e chama setMembership',
+        (tester) async {
+      await tester.pumpWidget(ProviderScope(
+        overrides: base91(),
+        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
+      ));
+      await tester.pumpAndSettle();
+
+      await tester.tap(find.text('ana@obra.com'));
+      await tester.pumpAndSettle();
+
+      await tester.tap(find.widgetWithText(FilledButton, 'Atribuir à obra'));
+      await tester.pumpAndSettle();
+
+      expect(find.byType(AtribuirObraDialog), findsOneWidget);
+      expect(find.text('Atribuir à obra'), findsWidgets);
+      expect(find.text('Membro: ana@obra.com'), findsOneWidget);
+      expect(find.text('Operário'), findsWidgets);
+
+      final chkDiario = tester.widget<CheckboxListTile>(
+        find.widgetWithText(CheckboxListTile, 'Diário de Obras'),
+      );
+      expect(chkDiario.value, isTrue);
+
+      expect(find.text('Selecione a obra'), findsOneWidget);
+      final confirmarBtnInicial = tester.widget<FilledButton>(
+        find.widgetWithText(FilledButton, 'Confirmar atribuição'),
+      );
+      expect(confirmarBtnInicial.onPressed, isNull);
+
+      expect(
+        find.text('Selecione uma obra para ver o resumo da atribuição.'),
+        findsOneWidget,
+      );
+
+      await tester.tap(find.byType(DropdownButtonFormField<String>));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('Obra o2').last);
+      await tester.pumpAndSettle();
+
+      expect(
+        find.text('ana@obra.com será Operário em Obra o2 com acesso a Diário'),
+        findsOneWidget,
+      );
+
+      final confirmarBtnHabilitado = tester.widget<FilledButton>(
+        find.widgetWithText(FilledButton, 'Confirmar atribuição'),
+      );
+      expect(confirmarBtnHabilitado.onPressed, isNotNull);
+      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar atribuição'));
+      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar atribuição'));
+      await tester.pumpAndSettle();
+
+      expect(fakeObraMembersRepo.chamadas.length, 1);
+      expect(fakeObraMembersRepo.chamadas.first, {
+        'construtoraId': 'c-1',
+        'obraId': 'o2',
+        'userId': 'u1',
+        'role': 'operario',
+        'modules': ['diario'],
+        'isActive': true,
+      });
+
+      expect(find.byType(AtribuirObraDialog), findsNothing);
+      expect(find.text('Atribuído a Obra o2 como Operário.'), findsOneWidget);
+    });
+
+    testWidgets('9.1 resumo dinâmico atualiza ao marcar módulos adicionais',
+        (tester) async {
+      await tester.pumpWidget(ProviderScope(
+        overrides: base91(),
+        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
+      ));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('ana@obra.com'));
+      await tester.pumpAndSettle();
+      await tester.tap(find.widgetWithText(FilledButton, 'Atribuir à obra'));
+      await tester.pumpAndSettle();
+
+      await tester.tap(find.byType(DropdownButtonFormField<String>));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('Obra o2').last);
+      await tester.pumpAndSettle();
+
+      await tester.tap(find.widgetWithText(CheckboxListTile, 'Lotes'));
+      await tester.pumpAndSettle();
+
+      expect(
+        find.text('ana@obra.com será Operário em Obra o2 com acesso a Diário, Lotes'),
+        findsOneWidget,
+      );
+
+      await tester.tap(find.widgetWithText(CheckboxListTile, 'Estoque'));
+      await tester.pumpAndSettle();
+
+      expect(
+        find.text('ana@obra.com será Operário em Obra o2 com acesso a Diário, Lotes, Estoque'),
+        findsOneWidget,
+      );
+
+      await tester.tap(find.widgetWithText(CheckboxListTile, 'Diário de Obras'));
+      await tester.pumpAndSettle();
+
+      expect(
+        find.text('ana@obra.com será Operário em Obra o2 com acesso a Lotes, Estoque'),
+        findsOneWidget,
+      );
+    });
+
+    testWidgets('9.1 nenhuma obra ativa exibe mensagem e desabilita botão',
+        (tester) async {
+      await tester.pumpWidget(ProviderScope(
+        overrides: base91(
+          obras: [_obra('o1')],
+          porObra: {'o1': [_om('u1')]},
+        ),
+        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
+      ));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('ana@obra.com'));
+      await tester.pumpAndSettle();
+      await tester.tap(find.widgetWithText(FilledButton, 'Atribuir à obra'));
+      await tester.pumpAndSettle();
+
+      expect(find.text('Nenhuma obra ativa'), findsOneWidget);
+      final btn = tester.widget<FilledButton>(
+        find.widgetWithText(FilledButton, 'Confirmar atribuição'),
+      );
+      expect(btn.onPressed, isNull);
+    });
+
+    testWidgets('9.1 membro inativo na construtora tem Atribuir à obra desabilitado',
+        (tester) async {
+      await tester.pumpWidget(ProviderScope(
+        overrides: base91(uid: 'u2'),
+        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
+      ));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('inativo@obra.com'));
+      await tester.pumpAndSettle();
+
+      final atribuirBtn = tester.widget<FilledButton>(
+        find.widgetWithText(FilledButton, 'Atribuir à obra'),
+      );
+      expect(atribuirBtn.onPressed, isNull);
+      expect(find.text('Ative na construtora primeiro'), findsOneWidget);
+    });
+
+    testWidgets('9.1 cancelar fecha o diálogo sem chamar repositório',
+        (tester) async {
+      await tester.pumpWidget(ProviderScope(
+        overrides: base91(),
+        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
+      ));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('ana@obra.com'));
+      await tester.pumpAndSettle();
+      await tester.tap(find.widgetWithText(FilledButton, 'Atribuir à obra'));
+      await tester.pumpAndSettle();
+
+      await tester.ensureVisible(find.text('Cancelar'));
+      await tester.tap(find.text('Cancelar'));
+      await tester.pumpAndSettle();
+
+      expect(find.byType(AtribuirObraDialog), findsNothing);
+      expect(fakeObraMembersRepo.chamadas, isEmpty);
+    });
+
+    testWidgets('9.1 erro na mutação exibe mensagem de erro no diálogo',
+        (tester) async {
+      fakeObraMembersRepo.deveFalhar = true;
+      fakeObraMembersRepo.mensagemErro = 'Sem permissão para gerir vínculo';
+
+      await tester.pumpWidget(ProviderScope(
+        overrides: base91(),
+        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
+      ));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('ana@obra.com'));
+      await tester.pumpAndSettle();
+      await tester.tap(find.widgetWithText(FilledButton, 'Atribuir à obra'));
+      await tester.pumpAndSettle();
+
+      await tester.tap(find.byType(DropdownButtonFormField<String>));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('Obra o2').last);
+      await tester.pumpAndSettle();
+
+      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar atribuição'));
+      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar atribuição'));
+      await tester.pumpAndSettle();
+
+      expect(find.byType(AtribuirObraDialog), findsOneWidget);
+      await tester.ensureVisible(find.text('Sem permissão para gerir vínculo'));
+      expect(find.text('Sem permissão para gerir vínculo'), findsOneWidget);
+    });
+
+    testWidgets('9.1 textScale 1.3 sem overflow no diálogo de atribuição',
+        (tester) async {
+      await tester.pumpWidget(
+        MediaQuery(
+          data: const MediaQueryData(
+            size: Size(390, 844),
+            textScaler: TextScaler.linear(1.3),
+          ),
+          child: ProviderScope(
+            overrides: base91(),
+            child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
+          ),
+        ),
+      );
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('ana@obra.com'));
+      await tester.pumpAndSettle();
+      await tester.tap(find.widgetWithText(FilledButton, 'Atribuir à obra'));
+      await tester.pumpAndSettle();
+
+      expect(tester.takeException(), isNull);
+      expect(find.byType(AtribuirObraDialog), findsOneWidget);
+    });
+  });
 }

```

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.

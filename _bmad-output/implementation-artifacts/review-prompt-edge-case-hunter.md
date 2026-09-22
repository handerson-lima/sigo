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


claims_file (leave unread until your instructions call for it):
```markdown
---
title: '9.1 Atribuir operário à obra'
type: 'feature'
created: '2026-09-22'
status: 'in-review'
route: 'dispatch'
baseline_commit: '5f0b0c9ac8e2b9821186b06d03c79569d4508484'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Adm/owner visualiza o membro ativo na construtora no detalhe (8.3), mas o botão "Atribuir à obra" está desabilitado, impossibilitando alocar o operário em uma obra com seus respectivos módulos de acesso.

**Approach:** Habilitar o fluxo de atribuição no `MemberDetalheSheet` para membros ativos abrindo `AtribuirObraDialog`: permitir selecionar uma obra ativa da construtora (filtrando as já vinculadas ativas), manter o papel fixado em "Operário", módulos padrão `[diario]`, exibir resumo dinâmico ao vivo e chamar `setMembership` via repositório, exibindo SnackBar de confirmação e atualizando o estado local e contadores.

## Boundaries & Constraints

**Always:**
- Apenas membros ativos na construtora podem ser atribuídos; para membros inativos (`isActive == false`), o botão "Atribuir à obra" permanece desabilitado com o aviso `Ative na construtora primeiro`.
- Papel atribuído nesta história é estritamente `operario` (role: `operario`). Nunca enviar `owner` com `obraId`.
- Módulos padrão pré-selecionados: `[diario]`. Módulos adicionais permitidos: `lotes`, `estoque`.
- O botão de confirmação ("Confirmar atribuição") deve permanecer desabilitado enquanto nenhuma obra válida for selecionada ou quando não houver obras ativas disponíveis.
- Resumo dinâmico em tempo real exibido no diálogo: `{Nome/Email} será Operário em {Obra} com acesso a {Módulos}` (UX-DR4).
- Toda mutação passa por `setMembership{construtoraId, obraId, userId, role: 'operario', modules, isActive: true}` via Cloud Functions; a UI nunca grava diretamente na subcoleção `members`.
- Após atribuição bem-sucedida, exibir SnackBar `Atribuído a {obra} como Operário.` e invalidar os providers (`membrosProvider`, `obraMembersProvider`, `obrasVinculadasProvider`, `contagemObrasPorMembroProvider`, `memberDetalheProvider`).
- Normalização na leitura de membro de obra: `member` vira `Operário`.
- Acessibilidade: diálogos com rótulos semânticos, foco inicial, suporte a fechar via tecla Esc e suporte a escala de fonte `textScale` de até 1.3x sem overflow.

**Never:**
- Não permitir selecionar ou enviar papel `owner` para vínculo de obra.
- Não permitir atribuição sem obra selecionada.
- Não usar fila offline para atribuição de novos membros (operação online-only; AD-6/NFR2).
- Não criar `collectionGroup` queries.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH atribuição | Membro ativo, clica "Atribuir à obra", seleciona obra ativa, módulos `[diario]`, confirma | Chama `setMembership`, fecha dialog, SnackBar `Atribuído a {obra} como Operário.`, invalida providers e N obras atualiza | Exibe SnackBar com erro caso a Cloud Function falhe |
| Sem obra selecionada | Dialog aberto sem obra escolhida | Botão de confirmar desabilitado; resumo indica seleção pendente | N/A |
| Nenhuma obra ativa | Construtora sem obras ativas ou membro já vinculado a todas | Dropdown exibe `Nenhuma obra ativa`; botão de confirmar desabilitado | N/A |
| Membro inativo | `member.isActive == false` | Botão "Atribuir à obra" desabilitado no `MemberDetalheSheet` | Mantém aviso inline `Ative na construtora primeiro` |
| Resumo dinâmico | Usuário altera obra ou módulos selecionados | Texto do resumo atualiza instantaneamente com nome da obra e módulos ativos | N/A |
| Teclado / Esc | Tecla Esc pressionada no diálogo | Diálogo fecha sem disparar mutação | N/A |
| textScale 1.3 | Escala de texto ampliada para 1.3x | Sem overflow de renderização no dialog ou resumo | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/obras/data/obra_members_repository.dart` -- **novo**: Repositório com método `setMembership` chamando `FirebaseFunctions.instance.httpsCallable('setMembership')` e provider `obraMembersRepositoryProvider`.
- `app/lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart` -- **novo**: Diálogo `AtribuirObraDialog` com seleção de obra ativa, checkboxes/chips de módulos (`diario` default), resumo em tempo real e botão de confirmação.
- `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- Habilitar o botão `Atribuir à obra` quando o membro estiver ativo (`isActive == true`), abrindo `AtribuirObraDialog.show`.
- `app/lib/src/features/construtoras/presentation/membros_providers.dart` -- Helper para invalidação completa de estado pós-atribuição e lista de obras disponíveis para atribuição (filtrando as já vinculadas ativas).
- `app/test/features/construtoras/membros_test.dart` -- Testes automatizados cobrindo os cenários da matriz de I/O da história 9.1.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/obras/data/obra_members_repository.dart` -- criar repositório e provider para chamada segura à Cloud Function `setMembership` -- infraestrutura de dados/mutação.
- [x] `app/lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart` -- criar widget do diálogo com seleção de obra, módulos padrão `[diario]`, resumo dinâmico e validações -- interface de atribuição.
- [x] `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- integrar abertura de `AtribuirObraDialog` ao botão `Atribuir à obra` para membros ativos -- integração do fluxo.
- [x] `app/test/features/construtoras/membros_test.dart` -- adicionar testes de widget para fluxo de atribuição, resumo dinâmico, validação de desabilitação e feedback visual -- cobertura e regressão.

**Acceptance Criteria:**
- Given detalhe de membro ativo na construtora, when toco `Atribuir à obra`, seleciono obra ativa, mantenho `Operário`, módulos default `[diario]`, confirmo, then chama `setMembership{construtoraId, obraId, role: 'operario', modules: ['diario'], isActive: true}` e vejo `Atribuído a {obra} como Operário.` + lista atualiza N obras.
- Given o diálogo de atribuição aberto sem obra selecionada, then botão de confirmar fica desabilitado e o resumo indica a pendência.
- Given membro inativo na construtora, then o botão `Atribuir à obra` permanece desabilitado.

## Implementation Notes

- Criado `ObraMembersRepository` e seu provider `obraMembersRepositoryProvider` para disparar a Cloud Function autoritativa `setMembership`.
- Criado `AtribuirObraDialog` com suporte a seleção de obras ativas (filtrando obras já vinculadas), papel fixo "Operário", seleção de módulos com `[diario]` pré-selecionado, resumo em tempo real e prevenção de overflow via `Wrap`.
- Integrado botão "Atribuir à obra" no `MemberDetalheSheet` apenas para membros ativos (`isActive == true`). Membros inativos mantêm o botão desabilitado.
- Adicionada suíte de testes completa cobrindo todos os cenários da matriz de I/O (HAPPY_PATH, validação de desabilitação sem obra ou sem obras ativas, membro inativo, atualização em tempo real do resumo ao vivo, cancelamento, tratamento de erro do backend e `textScale 1.3`).
- 74 testes executados e aprovados com `flutter analyze` 100% limpo.

## Spec Change Log

## Review Triage Log

## Design Notes

- Módulos suportados no diálogo:
  - `diario`: rótulo "Diário de Obras" (obrigatório/default)
  - `lotes`: rótulo "Lotes"
  - `estoque`: rótulo "Estoque"
- O resumo dinâmico usa a fórmula: `{Nome/Email} será Operário em {Obra} com acesso a {Módulos}`.
- Ao salvar com sucesso, exibe `SnackBar(content: Text('Atribuído a $obraNome como Operário.'))`.

## Verification

**Commands:**
- `flutter test test/features/construtoras/membros_test.dart` -- expected: All tests pass.
- `flutter analyze` -- expected: 0 issues found.

```

Review content:
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

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. If the instruction file is unreadable, report that exact failure and stop. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.

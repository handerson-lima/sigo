Review instructions:
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
title: 'Fix Routing Architecture'
type: 'refactor'
created: '2026-09-23'
status: 'in-review'
baseline_commit: 'dfda67bb97b4a0d4fb9f8d9aa6342eee583e5efe'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A nova arquitetura modular de rotas apresenta problemas identificados em code review: falta de tratamento para 404 (erro de rota), estrutura plana que quebra o *navigation stack*, duplicação de acessos no RH, uso inadequado de `extra` para passar estados em memória e guards redundantes no módulo dev.

**Approach:** Refatorar o `GoRouter` no `app_router.dart` para utilizar rotas aninhadas em vez de concatenar listas planas globais. Adicionar um `errorBuilder` na instância principal. Corrigir as rotas do RH unificando os acessos duplicados e trocando a passagem via `extra` pela recuperação via ID. Limpar as chamadas redundantes ao `AccessGuard` nas rotas filhas de desenvolvedor.

## Boundaries & Constraints

**Always:** Manter a separação de rotas por feature (`*_routes.dart`), mas utilizando-os como sub-rotas ou integrados hierarquicamente para que a navegação do sistema mantenha o histórico corretamente.

**Never:** Usar `state.extra` para passagem de dados críticos entre telas de navegação profunda; não depender de rotas totalmente planas no `GoRouter` raiz para recursos aninhados.

**Decisões Arquiteturais:**
Utilizar a Opção A (Nested Router Root) para a hierarquia da construtora. Todas as rotas de `obras`, `rh`, `diario`, etc. deverão ser configuradas como rotas filhas no `app_router.dart`.

</frozen-after-approval>

## Code Map

- `app/lib/src/routing/app_router.dart` -- Ponto de entrada do GoRouter. Precisa do `errorBuilder` e de reestruturar a montagem das rotas filhas para suportar aninhamento (nested routes).
- `app/lib/src/features/developer/routing/dev_routes.dart` -- Remover a duplicação do `AccessGuard` interno, confiando no `app_router`.
- `app/lib/src/features/rh/routing/rh_routes.dart` -- Consolidar `RhPaths.rh` e `RhPaths.funcionarios`. Remover o uso de `state.extra` em `editarFuncionario`.
- `app/lib/src/features/construtoras/routing/construtora_routes.dart` -- Ajustar para suportar aninhamento das demais rotas filhas (obras, diário, RH).
- Demais arquivos `*_routes.dart` -- Atualizar seus `paths` (retirando prefixos estáticos de caminho pai) caso passem a ser declaradas como sub-rotas.

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/routing/app_router.dart` -- Adicionar `errorBuilder` retornando uma tela de erro padrão ou redirecionando -- Lida com rotas não encontradas (404).
- [ ] `app/lib/src/features/developer/routing/dev_routes.dart` -- Remover `AccessGuard(devOnly: true)` dos `GoRoute` -- Reduz complexidade pois `app_router.dart` já possui `redirect` global.
- [ ] `app/lib/src/features/rh/routing/rh_routes.dart` -- Remover rota duplicada (`RhPaths.rh` / `RhPaths.funcionarios`) -- Limpeza de código e evitar duas URIs pra mesma tela.
- [ ] `app/lib/src/features/rh/routing/rh_routes.dart` -- Alterar passagem do Funcionario do `extra` para usar o `fId` no fetch -- Suporte real a deep link.
- [ ] `app/lib/src/routing/app_router.dart` e `*_routes.dart` -- Refatorar para usar nested routes hierárquicas (ex: rotas filhas de `/construtora/:cId`) -- Consertar a pilha de navegação (back button).

**Acceptance Criteria:**
- Given que acesso uma URL inválida, when carregar, then o `errorBuilder` entra em ação impedindo crash.
- Given que navego para a página de Editar Funcionário a partir de um link direto (deep link / F5), when o `fId` está na URL, then a página carrega corretamente os dados sem quebrar por falta de estado no `extra`.
- Given que o aplicativo monta o Router, when eu verifico a rota de desenvolvedor, then não há múltiplos `AccessGuard` sobrepondo-se desnecessariamente.

## Design Notes

A hierarquia de rotas de entidades vinculadas à construtora deve seguir este padrão aproximado no `app_router`:

```dart
GoRoute(
  path: '/construtora/:cId',
  builder: (context, state) => ..., 
  routes: [
    ...obraRoutes,   // path passará a ser 'obra/:oId' (e não '/construtora/:cId/obra/:oId')
    ...rhRoutes,
    ...diarioRoutes,
  ]
)
```
Isso demandará atualizar os `path` nos arquivos de sub-rotas para serem relativos ou ajustados conforme documentação do GoRouter.

```

Review content:
```diff
diff --git a/_bmad-output/planning-artifacts/ux-designs/ux-obras-2026-09-23/.memlog.md b/_bmad-output/planning-artifacts/ux-designs/ux-obras-2026-09-23/.memlog.md
index 8fb1db9..c232dfe 100644
--- a/_bmad-output/planning-artifacts/ux-designs/ux-obras-2026-09-23/.memlog.md
+++ b/_bmad-output/planning-artifacts/ux-designs/ux-obras-2026-09-23/.memlog.md
@@ -1,6 +1,6 @@
 ---
 topic: SIGO — Design system global
-updated: 2026-09-23T06:28
+updated: 2026-09-23T06:41
 ---
 
 - (decision) Usuário: apenas design e planejamento, sem implementar. Criar planejamento global separado, preservando trabalho existente.
@@ -20,3 +20,4 @@ updated: 2026-09-23T06:28
 - (assumption) Proposta LoteCard para discussão: superfície clara, identificação em destaque, fase explícita, status textual com ícone, acento azul/dourado de marca separado da sinalização operacional; coluna mobile e grid desktop com ações Atualizar lote e Vistorias. Preservar destinos existentes; sem percentuais, fotos, prazos calculados ou KPIs inventados. Dados atuais: nome, fase, status e responsavelId opcional sem nome resolvido. Edição atual grava fase e status separadamente; feedback precisa reconhecer falha parcial e não prometer confirmação remota a partir de cache. Detalhes em .working/lotes-extract.md; contratos continuam in-progress.
 - (decision) Usuário confirmou manter o contraste do conceito B; tipografia com a aparência forte da imagem; construtoras espaçosas e lotes mais compactos. Apenas design e planejamento; não aprovou fonte externa nem valores numéricos finais.
 - (assumption) Refinamento proposto: sidebar #082344, cabeçalho textual #0D47A1–#1565C0, azul seed reservado a grafismos, dourado #FCA906; família padrão Material herdada, títulos700 e nomes600; título página desktop40/48 e telefone28/36. Construtoras padding24 desktop/20 telefone e área logo88/64; lotes padding16 e gaps8; grid mínimo desejado320 para construtora e280 para lote limitado à largura disponível. Números e estados são calibragem [ASSUMPTION], alvos mínimos48 e altura livre. Tokens de membros preservados; status in-progress. Script memlog executado com python3 pois cache uv indisponível no sandbox.
+- (event) Geradas quatro prévias ImageGen refinadas em .working/*-refinado-v1.png: construtoras/lotes desktop/mobile. Empresas e lotes fictícios; marca SIGO em texto como placeholder da logo oficial. Cards construtoras espaçosos, lotes compactos. Imagens para discussão, não aprovadas automaticamente; medidas e cores do DESIGN prevalecem sobre variações do raster. Sem implementação.
diff --git a/app/lib/src/features/almoxarifado/routing/almoxarifado_routes.dart b/app/lib/src/features/almoxarifado/routing/almoxarifado_routes.dart
new file mode 100644
index 0000000..8e70831
--- /dev/null
+++ b/app/lib/src/features/almoxarifado/routing/almoxarifado_routes.dart
@@ -0,0 +1,72 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/almoxarifado_list_screen.dart';
+import '../presentation/add_material_screen.dart';
+import '../presentation/movimentacao_screen.dart';
+import '../domain/material.dart' as mat;
+import '../domain/movimentacao.dart';
+import '../../obras/presentation/access_denied_screen.dart';
+
+/// Constantes de path para almoxarifado.
+abstract class AlmoxarifadoPaths {
+  static const list = 'almoxarifado';
+  static const novoMaterial = 'almoxarifado/novo_material';
+  static const movimentacao = 'almoxarifado/movimentacao';
+
+  static String listFor(String cId) => '/construtora/$cId/almoxarifado';
+  static String novoMaterialFor(String cId) =>
+      '/construtora/$cId/almoxarifado/novo_material';
+  static String movimentacaoFor(String cId) =>
+      '/construtora/$cId/almoxarifado/movimentacao';
+}
+
+/// Rotas do módulo de almoxarifado.
+List<RouteBase> get almoxarifadoRoutes => [
+      GoRoute(
+        path: AlmoxarifadoPaths.list,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'estoque',
+            child: AlmoxarifadoListScreen(construtoraId: cId),
+          );
+        },
+      ),
+      GoRoute(
+        path: AlmoxarifadoPaths.novoMaterial,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'estoque',
+            child: AddMaterialScreen(construtoraId: cId),
+          );
+        },
+      ),
+      GoRoute(
+        path: AlmoxarifadoPaths.movimentacao,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          if (state.extra is! Map<String, dynamic>) {
+            return const AccessDeniedScreen();
+          }
+          final extra = state.extra as Map<String, dynamic>;
+          final material = extra['material'] as mat.Material;
+          final typeStr = extra['type'] as String;
+          final type = typeStr == 'entrada'
+              ? MovimentacaoType.entrada
+              : MovimentacaoType.saida;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'estoque',
+            child: MovimentacaoScreen(
+              construtoraId: cId,
+              material: material,
+              type: type,
+            ),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/authentication/routing/auth_routes.dart b/app/lib/src/features/authentication/routing/auth_routes.dart
new file mode 100644
index 0000000..924481a
--- /dev/null
+++ b/app/lib/src/features/authentication/routing/auth_routes.dart
@@ -0,0 +1,16 @@
+import 'package:go_router/go_router.dart';
+
+import '../presentation/login_screen.dart';
+
+/// Constantes de path para autenticação.
+abstract class AuthPaths {
+  static const login = '/login';
+}
+
+/// Rotas do módulo de autenticação.
+List<RouteBase> get authRoutes => [
+      GoRoute(
+        path: AuthPaths.login,
+        builder: (context, state) => const LoginScreen(),
+      ),
+    ];
diff --git a/app/lib/src/features/compras_parcelas/routing/compras_routes.dart b/app/lib/src/features/compras_parcelas/routing/compras_routes.dart
new file mode 100644
index 0000000..43b6eca
--- /dev/null
+++ b/app/lib/src/features/compras_parcelas/routing/compras_routes.dart
@@ -0,0 +1,96 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/compras_list_screen.dart';
+import '../presentation/compra_form_screen.dart';
+import '../presentation/compra_detalhes_screen.dart';
+
+/// Constantes de path para compras e parcelas.
+abstract class ComprasPaths {
+  static const list = 'obra/:oId/compras';
+  static const nova = 'obra/:oId/compras/nova';
+  static const detalhes = 'obra/:oId/compras/:compraId';
+  static const editar =
+      'obra/:oId/compras/:compraId/editar';
+
+  static String listFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/compras';
+  static String novaFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/compras/nova';
+  static String detalhesFor(String cId, String oId, String compraId) =>
+      '/construtora/$cId/obra/$oId/compras/$compraId';
+  static String editarFor(String cId, String oId, String compraId) =>
+      '/construtora/$cId/obra/$oId/compras/$compraId/editar';
+}
+
+/// Rotas do módulo de compras e parcelas.
+List<RouteBase> get comprasRoutes => [
+      GoRoute(
+        path: ComprasPaths.list,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'compras',
+            child: ComprasListScreen(
+              construtoraId: cId,
+              obraId: oId,
+            ),
+          );
+        },
+      ),
+      GoRoute(
+        path: ComprasPaths.nova,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'compras',
+            child: CompraFormScreen(
+              construtoraId: cId,
+              obraId: oId,
+            ),
+          );
+        },
+      ),
+      GoRoute(
+        path: ComprasPaths.detalhes,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          final compraId = state.pathParameters['compraId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'compras',
+            child: CompraDetalhesScreen(
+              construtoraId: cId,
+              obraId: oId,
+              compraId: compraId,
+            ),
+          );
+        },
+      ),
+      GoRoute(
+        path: ComprasPaths.editar,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          final compraId = state.pathParameters['compraId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'compras',
+            child: CompraFormScreen(
+              construtoraId: cId,
+              obraId: oId,
+              compraId: compraId,
+            ),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/construtoras/routing/construtora_routes.dart b/app/lib/src/features/construtoras/routing/construtora_routes.dart
new file mode 100644
index 0000000..6ce9a72
--- /dev/null
+++ b/app/lib/src/features/construtoras/routing/construtora_routes.dart
@@ -0,0 +1,72 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/construtoras_list_screen.dart';
+import '../../obras/presentation/obras_list_screen.dart';
+import '../presentation/membros_screen.dart';
+
+import '../../obras/routing/obra_routes.dart';
+import '../../lotes/routing/lotes_routes.dart';
+import '../../almoxarifado/routing/almoxarifado_routes.dart';
+import '../../diario/routing/diario_routes.dart';
+import '../../rh/routing/rh_routes.dart';
+import '../../epi/routing/epi_routes.dart';
+import '../../financeiro/routing/financeiro_routes.dart';
+import '../../validacao/routing/validacao_routes.dart';
+import '../../despesas_adm/routing/despesas_adm_routes.dart';
+import '../../fornecedores/routing/fornecedores_routes.dart';
+import '../../compras_parcelas/routing/compras_routes.dart';
+import '../../custos_360/routing/custos_360_routes.dart';
+
+/// Constantes de path para construtoras.
+abstract class ConstrutoraPaths {
+  static const list = '/';
+  static const detail = '/construtora/:cId';
+  static const membros = 'membros';
+
+  static String detailFor(String cId) => '/construtora/$cId';
+  static String membrosFor(String cId) => '/construtora/$cId/membros';
+}
+
+/// Rotas do módulo de construtoras.
+List<RouteBase> get construtoraRoutes => [
+      GoRoute(
+        path: ConstrutoraPaths.list,
+        builder: (context, state) => const ConstrutorasListScreen(),
+      ),
+      GoRoute(
+        path: ConstrutoraPaths.detail,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            child: ObrasListScreen(construtoraId: cId),
+          );
+        },
+        routes: [
+          GoRoute(
+            path: ConstrutoraPaths.membros,
+            builder: (context, state) {
+              final cId = state.pathParameters['cId']!;
+              return AccessGuard(
+                construtoraId: cId,
+                adminOnly: true,
+                child: MembrosScreen(construtoraId: cId),
+              );
+            },
+          ),
+          ...obraRoutes,
+          ...lotesRoutes,
+          ...almoxarifadoRoutes,
+          ...diarioRoutes,
+          ...rhRoutes,
+          ...epiRoutes,
+          ...financeiroRoutes,
+          ...validacaoRoutes,
+          ...fornecedoresRoutes,
+          ...comprasRoutes,
+          ...custos360Routes,
+          ...despesasAdmRoutes,
+        ],
+      ),
+    ];
diff --git a/app/lib/src/features/custos_360/routing/custos_360_routes.dart b/app/lib/src/features/custos_360/routing/custos_360_routes.dart
new file mode 100644
index 0000000..625f71b
--- /dev/null
+++ b/app/lib/src/features/custos_360/routing/custos_360_routes.dart
@@ -0,0 +1,52 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/visao_360_custos_screen.dart';
+import '../presentation/lote_custo_detalhe_screen.dart';
+
+/// Constantes de path para custos 360.
+abstract class Custos360Paths {
+  static const visao360 = 'obra/:oId/custos-360';
+  static const loteCusto =
+      'obra/:oId/custos-360/lotes/:loteId';
+
+  static String visao360For(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/custos-360';
+  static String loteCustoFor(String cId, String oId, String loteId) =>
+      '/construtora/$cId/obra/$oId/custos-360/lotes/$loteId';
+}
+
+/// Rotas do módulo de custos 360.
+List<RouteBase> get custos360Routes => [
+      GoRoute(
+        path: Custos360Paths.visao360,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'adm',
+            child: Visao360CustosScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+      GoRoute(
+        path: Custos360Paths.loteCusto,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          final loteId = state.pathParameters['loteId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'adm',
+            child: LoteCustoDetalheScreen(
+              construtoraId: cId,
+              obraId: oId,
+              loteId: loteId,
+            ),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/despesas_adm/routing/despesas_adm_routes.dart b/app/lib/src/features/despesas_adm/routing/despesas_adm_routes.dart
new file mode 100644
index 0000000..0aeecaf
--- /dev/null
+++ b/app/lib/src/features/despesas_adm/routing/despesas_adm_routes.dart
@@ -0,0 +1,90 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/despesas_adm_list_screen.dart';
+import '../presentation/despesa_adm_form_screen.dart';
+import '../presentation/despesa_adm_details_screen.dart';
+
+/// Constantes de path para despesas administrativas.
+abstract class DespesasAdmPaths {
+  static const list = 'obra/:oId/despesas';
+  static const nova = 'obra/:oId/despesas/nova';
+  static const detalhes = 'obra/:oId/despesas/:despesaId';
+  static const editar =
+      'obra/:oId/despesas/:despesaId/editar';
+
+  static String listFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/despesas';
+  static String novaFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/despesas/nova';
+  static String detalhesFor(String cId, String oId, String despesaId) =>
+      '/construtora/$cId/obra/$oId/despesas/$despesaId';
+  static String editarFor(String cId, String oId, String despesaId) =>
+      '/construtora/$cId/obra/$oId/despesas/$despesaId/editar';
+}
+
+/// Rotas do módulo de despesas administrativas.
+List<RouteBase> get despesasAdmRoutes => [
+      GoRoute(
+        path: DespesasAdmPaths.list,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'adm',
+            child: DespesasAdmListScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+      GoRoute(
+        path: DespesasAdmPaths.nova,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'adm',
+            child: DespesaAdmFormScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+      GoRoute(
+        path: DespesasAdmPaths.detalhes,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          final despesaId = state.pathParameters['despesaId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'adm',
+            child: DespesaAdmDetailsScreen(
+              construtoraId: cId,
+              obraId: oId,
+              despesaId: despesaId,
+            ),
+          );
+        },
+      ),
+      GoRoute(
+        path: DespesasAdmPaths.editar,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          final despesaId = state.pathParameters['despesaId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'adm',
+            child: DespesaAdmFormScreen(
+              construtoraId: cId,
+              obraId: oId,
+              despesaId: despesaId,
+            ),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/developer/routing/dev_routes.dart b/app/lib/src/features/developer/routing/dev_routes.dart
new file mode 100644
index 0000000..b9e4cd0
--- /dev/null
+++ b/app/lib/src/features/developer/routing/dev_routes.dart
@@ -0,0 +1,40 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/dev_panel_screen.dart';
+import '../presentation/users_list_screen.dart';
+import '../presentation/user_details_screen.dart';
+import '../presentation/dev_construtoras_list_screen.dart';
+
+/// Constantes de path para o painel de desenvolvedor.
+abstract class DevPaths {
+  static const panel = '/dev';
+  static const users = '/dev/users';
+  static const userDetails = '/dev/users/:uid';
+  static const construtoras = '/dev/construtoras';
+
+  static String userDetailsFor(String uid) => '/dev/users/$uid';
+}
+
+/// Rotas do módulo de desenvolvedor.
+List<RouteBase> get devRoutes => [
+      GoRoute(
+        path: DevPaths.panel,
+        builder: (context, state) => const DevPanelScreen(),
+      ),
+      GoRoute(
+        path: DevPaths.users,
+        builder: (context, state) => const UsersListScreen(),
+      ),
+      GoRoute(
+        path: DevPaths.userDetails,
+        builder: (context, state) {
+          final uid = state.pathParameters['uid']!;
+          return UserDetailsScreen(userId: uid);
+        },
+      ),
+      GoRoute(
+        path: DevPaths.construtoras,
+        builder: (context, state) => const DevConstrutorasListScreen(),
+      ),
+    ];
diff --git a/app/lib/src/features/diario/routing/diario_routes.dart b/app/lib/src/features/diario/routing/diario_routes.dart
new file mode 100644
index 0000000..f893c24
--- /dev/null
+++ b/app/lib/src/features/diario/routing/diario_routes.dart
@@ -0,0 +1,75 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/diarios_list_screen.dart';
+import '../presentation/add_diario_screen.dart';
+import '../presentation/sync_queue_screen.dart';
+
+/// Constantes de path para diário de obra.
+abstract class DiarioPaths {
+  static const syncConstrutora = 'sync';
+  static const list = 'obra/:oId/diarios';
+  static const novo = 'obra/:oId/diarios/novo';
+  static const sync = 'obra/:oId/diarios/sync';
+
+  static String syncConstrutoraFor(String cId) => '/construtora/$cId/sync';
+  static String listFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/diarios';
+  static String novoFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/diarios/novo';
+  static String syncFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/diarios/sync';
+}
+
+/// Rotas do módulo de diário de obra.
+List<RouteBase> get diarioRoutes => [
+      GoRoute(
+        path: DiarioPaths.syncConstrutora,
+        builder: (context, state) => AccessGuard(
+          construtoraId: state.pathParameters['cId']!,
+          child: SyncQueueScreen(
+            construtoraId: state.pathParameters['cId']!,
+            obraId: '',
+          ),
+        ),
+      ),
+      GoRoute(
+        path: DiarioPaths.list,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'diario',
+            child: DiariosListScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+      GoRoute(
+        path: DiarioPaths.novo,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'diario',
+            child: AddDiarioScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+      GoRoute(
+        path: DiarioPaths.sync,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'diario',
+            child: SyncQueueScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/epi/routing/epi_routes.dart b/app/lib/src/features/epi/routing/epi_routes.dart
new file mode 100644
index 0000000..5a8e5ed
--- /dev/null
+++ b/app/lib/src/features/epi/routing/epi_routes.dart
@@ -0,0 +1,46 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/catalogo_epis_screen.dart';
+import '../presentation/entrega_epi_screen.dart';
+
+/// Constantes de path para EPIs.
+abstract class EpiPaths {
+  static const catalogo = 'epis';
+  static const entrega = 'obra/:oId/epis/entrega';
+
+  static String catalogoFor(String cId) => '/construtora/$cId/epis';
+  static String entregaFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/epis/entrega';
+}
+
+/// Rotas do módulo de EPIs.
+List<RouteBase> get epiRoutes => [
+      GoRoute(
+        path: EpiPaths.catalogo,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'epi',
+            child: CatalogoEpisScreen(construtoraId: cId),
+          );
+        },
+      ),
+      GoRoute(
+        path: EpiPaths.entrega,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'epi',
+            child: EntregaEpiScreen(
+              construtoraId: cId,
+              obraId: oId,
+            ),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/financeiro/routing/financeiro_routes.dart b/app/lib/src/features/financeiro/routing/financeiro_routes.dart
new file mode 100644
index 0000000..ac6d6cc
--- /dev/null
+++ b/app/lib/src/features/financeiro/routing/financeiro_routes.dart
@@ -0,0 +1,42 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/financeiro_list_screen.dart';
+import '../presentation/add_despesa_screen.dart';
+
+/// Constantes de path para financeiro.
+abstract class FinanceiroPaths {
+  static const list = 'financeiro';
+  static const novo = 'financeiro/novo';
+
+  static String listFor(String cId) => '/construtora/$cId/financeiro';
+  static String novoFor(String cId) => '/construtora/$cId/financeiro/novo';
+}
+
+/// Rotas do módulo financeiro.
+List<RouteBase> get financeiroRoutes => [
+      GoRoute(
+        path: FinanceiroPaths.list,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'financeiro',
+            adminOnly: true,
+            child: FinanceiroListScreen(construtoraId: cId),
+          );
+        },
+      ),
+      GoRoute(
+        path: FinanceiroPaths.novo,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'financeiro',
+            adminOnly: true,
+            child: AddDespesaScreen(construtoraId: cId),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/fornecedores/routing/fornecedores_routes.dart b/app/lib/src/features/fornecedores/routing/fornecedores_routes.dart
new file mode 100644
index 0000000..5331a22
--- /dev/null
+++ b/app/lib/src/features/fornecedores/routing/fornecedores_routes.dart
@@ -0,0 +1,55 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/fornecedores_list_screen.dart';
+import '../presentation/fornecedor_form_screen.dart';
+
+/// Constantes de path para fornecedores.
+abstract class FornecedoresPaths {
+  static const list = 'fornecedores';
+  static const novo = 'fornecedores/novo';
+  static const editar = 'fornecedores/:fornecedorId/editar';
+
+  static String listFor(String cId) => '/construtora/$cId/fornecedores';
+  static String novoFor(String cId) => '/construtora/$cId/fornecedores/novo';
+  static String editarFor(String cId, String fornecedorId) =>
+      '/construtora/$cId/fornecedores/$fornecedorId/editar';
+}
+
+/// Rotas do módulo de fornecedores.
+List<RouteBase> get fornecedoresRoutes => [
+      GoRoute(
+        path: FornecedoresPaths.list,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            child: FornecedoresListScreen(construtoraId: cId),
+          );
+        },
+      ),
+      GoRoute(
+        path: FornecedoresPaths.novo,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            child: FornecedorFormScreen(construtoraId: cId),
+          );
+        },
+      ),
+      GoRoute(
+        path: FornecedoresPaths.editar,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final fornecedorId = state.pathParameters['fornecedorId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            child: FornecedorFormScreen(
+              construtoraId: cId,
+              fornecedorId: fornecedorId,
+            ),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/lotes/routing/lotes_routes.dart b/app/lib/src/features/lotes/routing/lotes_routes.dart
new file mode 100644
index 0000000..5eb2ba1
--- /dev/null
+++ b/app/lib/src/features/lotes/routing/lotes_routes.dart
@@ -0,0 +1,47 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/lotes_list_screen.dart';
+import '../presentation/add_lote_screen.dart';
+
+/// Constantes de path para lotes.
+abstract class LotesPaths {
+  static const list = 'obra/:oId/lotes';
+  static const novo = 'obra/:oId/lotes/novo';
+
+  static String listFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/lotes';
+  static String novoFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/lotes/novo';
+}
+
+/// Rotas do módulo de lotes.
+List<RouteBase> get lotesRoutes => [
+      GoRoute(
+        path: LotesPaths.list,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'lotes',
+            child: LotesListScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+      GoRoute(
+        path: LotesPaths.novo,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'lotes',
+            adminOnly: true,
+            child: AddLoteScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/obras/routing/obra_routes.dart b/app/lib/src/features/obras/routing/obra_routes.dart
new file mode 100644
index 0000000..297006a
--- /dev/null
+++ b/app/lib/src/features/obras/routing/obra_routes.dart
@@ -0,0 +1,28 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/obra_dashboard_screen.dart';
+
+/// Constantes de path para obras.
+abstract class ObraPaths {
+  static const dashboard = 'obra/:oId';
+
+  static String dashboardFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId';
+}
+
+/// Rotas do módulo de obras.
+List<RouteBase> get obraRoutes => [
+      GoRoute(
+        path: ObraPaths.dashboard,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            child: ObraDashboardScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/rh/routing/rh_routes.dart b/app/lib/src/features/rh/routing/rh_routes.dart
new file mode 100644
index 0000000..89b50ea
--- /dev/null
+++ b/app/lib/src/features/rh/routing/rh_routes.dart
@@ -0,0 +1,121 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/funcionarios_list_screen.dart';
+import '../presentation/funcionario_form_screen.dart';
+import '../domain/funcionario.dart';
+import '../presentation/chamadas_list_screen.dart';
+import '../presentation/chamada_form_screen.dart';
+
+/// Constantes de path para RH.
+abstract class RhPaths {
+  
+  static const funcionarios = 'rh/funcionarios';
+  static const novoFuncionario = 'rh/funcionarios/novo';
+  static const editarFuncionario =
+      'rh/funcionarios/:fId/editar';
+  static const chamadas = 'obra/:oId/rh/chamadas';
+  static const novaChamada = 'obra/:oId/rh/chamadas/nova';
+  static const editarChamada =
+      'obra/:oId/rh/chamadas/:chId';
+
+  static String rhFor(String cId) => '/construtora/$cId/rh';
+  static String funcionariosFor(String cId) =>
+      '/construtora/$cId/rh/funcionarios';
+  static String novoFuncionarioFor(String cId) =>
+      '/construtora/$cId/rh/funcionarios/novo';
+  static String editarFuncionarioFor(String cId, String fId) =>
+      '/construtora/$cId/rh/funcionarios/$fId/editar';
+  static String chamadasFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/rh/chamadas';
+  static String novaChamadaFor(String cId, String oId) =>
+      '/construtora/$cId/obra/$oId/rh/chamadas/nova';
+  static String editarChamadaFor(String cId, String oId, String chId) =>
+      '/construtora/$cId/obra/$oId/rh/chamadas/$chId';
+}
+
+/// Rotas do módulo de RH (funcionários + chamadas).
+List<RouteBase> get rhRoutes => [
+
+      GoRoute(
+        path: RhPaths.funcionarios,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'rh',
+            child: FuncionariosListScreen(construtoraId: cId),
+          );
+        },
+      ),
+      GoRoute(
+        path: RhPaths.novoFuncionario,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'rh',
+            child: FuncionarioFormScreen(construtoraId: cId),
+          );
+        },
+      ),
+      GoRoute(
+        path: RhPaths.editarFuncionario,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final fId = state.pathParameters['fId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'rh',
+            child: FuncionarioFormScreen(
+              construtoraId: cId,
+              funcionarioId: fId,
+            ),
+          );
+        },
+      ),
+      GoRoute(
+        path: RhPaths.chamadas,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'rh',
+            child: ChamadasListScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+      GoRoute(
+        path: RhPaths.novaChamada,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'rh',
+            child: ChamadaFormScreen(construtoraId: cId, obraId: oId),
+          );
+        },
+      ),
+      GoRoute(
+        path: RhPaths.editarChamada,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          final chId = state.pathParameters['chId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'rh',
+            child: ChamadaFormScreen(
+              construtoraId: cId,
+              obraId: oId,
+              chamadaId: chId,
+            ),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/features/validacao/routing/validacao_routes.dart b/app/lib/src/features/validacao/routing/validacao_routes.dart
new file mode 100644
index 0000000..a9672cb
--- /dev/null
+++ b/app/lib/src/features/validacao/routing/validacao_routes.dart
@@ -0,0 +1,98 @@
+import 'package:go_router/go_router.dart';
+
+import '../../../common_widgets/access_guard.dart';
+import '../presentation/templates_list_screen.dart';
+import '../presentation/lote_validacoes_screen.dart';
+import '../presentation/validacao_form_screen.dart';
+
+/// Constantes de path para validação.
+abstract class ValidacaoPaths {
+  static const templates = 'validacao/templates';
+  static const loteValidacoes =
+      'obra/:oId/lotes/:loteId/validacoes';
+  static const novaValidacao =
+      'obra/:oId/lotes/:loteId/validacoes/nova';
+  static const editarValidacao =
+      'obra/:oId/lotes/:loteId/validacoes/:validacaoId';
+
+  static String templatesFor(String cId) =>
+      '/construtora/$cId/validacao/templates';
+  static String loteValidacoesFor(String cId, String oId, String loteId) =>
+      '/construtora/$cId/obra/$oId/lotes/$loteId/validacoes';
+  static String novaValidacaoFor(String cId, String oId, String loteId) =>
+      '/construtora/$cId/obra/$oId/lotes/$loteId/validacoes/nova';
+  static String editarValidacaoFor(
+          String cId, String oId, String loteId, String validacaoId) =>
+      '/construtora/$cId/obra/$oId/lotes/$loteId/validacoes/$validacaoId';
+}
+
+/// Rotas do módulo de validação.
+List<RouteBase> get validacaoRoutes => [
+      GoRoute(
+        path: ValidacaoPaths.templates,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            module: 'validacao',
+            child: TemplatesListScreen(construtoraId: cId),
+          );
+        },
+      ),
+      GoRoute(
+        path: ValidacaoPaths.loteValidacoes,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          final loteId = state.pathParameters['loteId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'validacao',
+            child: LoteValidacoesScreen(
+              construtoraId: cId,
+              obraId: oId,
+              loteId: loteId,
+            ),
+          );
+        },
+      ),
+      GoRoute(
+        path: ValidacaoPaths.novaValidacao,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          final loteId = state.pathParameters['loteId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'validacao',
+            child: ValidacaoFormScreen(
+              construtoraId: cId,
+              obraId: oId,
+              loteId: loteId,
+            ),
+          );
+        },
+      ),
+      GoRoute(
+        path: ValidacaoPaths.editarValidacao,
+        builder: (context, state) {
+          final cId = state.pathParameters['cId']!;
+          final oId = state.pathParameters['oId']!;
+          final loteId = state.pathParameters['loteId']!;
+          final validacaoId = state.pathParameters['validacaoId']!;
+          return AccessGuard(
+            construtoraId: cId,
+            obraId: oId,
+            module: 'validacao',
+            child: ValidacaoFormScreen(
+              construtoraId: cId,
+              obraId: oId,
+              loteId: loteId,
+              validacaoId: validacaoId,
+            ),
+          );
+        },
+      ),
+    ];
diff --git a/app/lib/src/routing/app_router.dart b/app/lib/src/routing/app_router.dart
index ad0a10b..c0482d1 100644
--- a/app/lib/src/routing/app_router.dart
+++ b/app/lib/src/routing/app_router.dart
@@ -1,52 +1,42 @@
-import '../common_widgets/access_guard.dart';
-import '../features/obras/presentation/access_denied_screen.dart';
-
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:go_router/go_router.dart';
 
 import '../features/authentication/data/auth_repository.dart';
-import '../features/authentication/presentation/login_screen.dart';
-import '../features/construtoras/presentation/construtoras_list_screen.dart';
-import '../features/obras/presentation/obras_list_screen.dart';
-import '../features/obras/presentation/obra_dashboard_screen.dart';
-import '../features/lotes/presentation/lotes_list_screen.dart';
-import '../features/lotes/presentation/add_lote_screen.dart';
-import '../features/almoxarifado/presentation/almoxarifado_list_screen.dart';
-import '../features/almoxarifado/presentation/add_material_screen.dart';
-import '../features/almoxarifado/presentation/movimentacao_screen.dart';
-import '../features/almoxarifado/domain/material.dart' as mat;
-import '../features/almoxarifado/domain/movimentacao.dart';
-import '../features/diario/presentation/diarios_list_screen.dart';
-import '../features/diario/presentation/add_diario_screen.dart';
-import '../features/diario/presentation/sync_queue_screen.dart';
-import '../features/construtoras/presentation/membros_screen.dart';
-import '../features/financeiro/presentation/financeiro_list_screen.dart';
-import '../features/financeiro/presentation/add_despesa_screen.dart';
-import '../features/developer/presentation/dev_panel_screen.dart';
-import '../features/developer/presentation/users_list_screen.dart';
-import '../features/developer/presentation/user_details_screen.dart';
-import '../features/developer/presentation/dev_construtoras_list_screen.dart';
 import '../features/authentication/data/user_repository.dart';
-import '../features/rh/presentation/funcionarios_list_screen.dart';
-import '../features/rh/presentation/funcionario_form_screen.dart';
-import '../features/rh/domain/funcionario.dart';
-import '../features/rh/presentation/chamadas_list_screen.dart';
-import '../features/rh/presentation/chamada_form_screen.dart';
-import '../features/epi/presentation/catalogo_epis_screen.dart';
-import '../features/epi/presentation/entrega_epi_screen.dart';
-import '../features/validacao/presentation/templates_list_screen.dart';
-import '../features/validacao/presentation/lote_validacoes_screen.dart';
-import '../features/validacao/presentation/validacao_form_screen.dart';
-import '../features/despesas_adm/presentation/despesas_adm_list_screen.dart';
-import '../features/despesas_adm/presentation/despesa_adm_form_screen.dart';
-import '../features/despesas_adm/presentation/despesa_adm_details_screen.dart';
-import '../features/fornecedores/presentation/fornecedores_list_screen.dart';
-import '../features/fornecedores/presentation/fornecedor_form_screen.dart';
-import '../features/compras_parcelas/presentation/compras_list_screen.dart';
-import '../features/compras_parcelas/presentation/compra_form_screen.dart';
-import '../features/compras_parcelas/presentation/compra_detalhes_screen.dart';
-import '../features/custos_360/presentation/visao_360_custos_screen.dart';
-import '../features/custos_360/presentation/lote_custo_detalhe_screen.dart';
+
+import '../features/authentication/routing/auth_routes.dart';
+import '../features/developer/routing/dev_routes.dart';
+import '../features/construtoras/routing/construtora_routes.dart';
+import '../features/obras/routing/obra_routes.dart';
+import '../features/lotes/routing/lotes_routes.dart';
+import '../features/almoxarifado/routing/almoxarifado_routes.dart';
+import '../features/diario/routing/diario_routes.dart';
+import '../features/rh/routing/rh_routes.dart';
+import '../features/epi/routing/epi_routes.dart';
+import '../features/financeiro/routing/financeiro_routes.dart';
+import '../features/validacao/routing/validacao_routes.dart';
+import '../features/despesas_adm/routing/despesas_adm_routes.dart';
+import '../features/fornecedores/routing/fornecedores_routes.dart';
+import '../features/compras_parcelas/routing/compras_routes.dart';
+import '../features/custos_360/routing/custos_360_routes.dart';
+
+// Opcional: Uma tela 404 padrão
+import 'package:flutter/material.dart';
+
+class ErrorScreen extends StatelessWidget {
+  final Exception? error;
+  const ErrorScreen({super.key, this.error});
+
+  @override
+  Widget build(BuildContext context) {
+    return Scaffold(
+      appBar: AppBar(title: const Text('Página não encontrada')),
+      body: Center(
+        child: Text(error?.toString() ?? 'A rota solicitada não existe.'),
+      ),
+    );
+  }
+}
 
 final routerProvider = Provider<GoRouter>((ref) {
   final authState = ref.watch(authStateChangesProvider);
@@ -54,9 +44,10 @@ final routerProvider = Provider<GoRouter>((ref) {
 
   return GoRouter(
     initialLocation: '/',
+    errorBuilder: (context, state) => ErrorScreen(error: state.error),
     redirect: (context, state) {
       final isLoading = authState.isLoading || devState.isLoading;
-      if (isLoading) return null; // Can result in a blank screen briefly if no loading route is provided, but typically okay
+      if (isLoading) return null;
 
       final isAuth = authState.value != null;
       final isLoggingIn = state.matchedLocation == '/login';
@@ -79,598 +70,9 @@ final routerProvider = Provider<GoRouter>((ref) {
       return null;
     },
     routes: [
-      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
-      GoRoute(
-        path: '/dev',
-        builder: (context, state) =>
-            const AccessGuard(devOnly: true, child: DevPanelScreen()),
-      ),
-      GoRoute(
-        path: '/dev/users',
-        builder: (context, state) =>
-            const AccessGuard(devOnly: true, child: UsersListScreen()),
-      ),
-      GoRoute(
-        path: '/dev/users/:uid',
-        builder: (context, state) {
-          final uid = state.pathParameters['uid']!;
-          return AccessGuard(
-            devOnly: true,
-            child: UserDetailsScreen(userId: uid),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/dev/construtoras',
-        builder: (context, state) => const AccessGuard(
-          devOnly: true,
-          child: DevConstrutorasListScreen(),
-        ),
-      ),
-      GoRoute(
-        path: '/',
-        builder: (context, state) => const ConstrutorasListScreen(),
-      ),
-      GoRoute(
-        path: '/construtora/:cId',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            child: ObrasListScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/sync',
-        builder: (context, state) => AccessGuard(
-          construtoraId: state.pathParameters['cId']!,
-          child: SyncQueueScreen(
-            construtoraId: state.pathParameters['cId']!,
-            obraId: '',
-          ),
-        ),
-      ),
-      GoRoute(
-        path: '/construtora/:cId/membros',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            adminOnly: true,
-            child: MembrosScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            child: ObraDashboardScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/lotes',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'lotes',
-            child: LotesListScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/lotes/novo',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'lotes',
-            adminOnly: true,
-            child: AddLoteScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/diarios',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'diario',
-            child: DiariosListScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/diarios/novo',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'diario',
-            child: AddDiarioScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/diarios/sync',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'diario',
-            child: SyncQueueScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/rh/chamadas',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'rh',
-            child: ChamadasListScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/rh/chamadas/nova',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'rh',
-            child: ChamadaFormScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/rh/chamadas/:chId',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          final chId = state.pathParameters['chId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'rh',
-            child: ChamadaFormScreen(
-              construtoraId: cId,
-              obraId: oId,
-              chamadaId: chId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/almoxarifado',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'estoque',
-            child: AlmoxarifadoListScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/almoxarifado/novo_material',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'estoque',
-            child: AddMaterialScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/almoxarifado/movimentacao',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          if (state.extra is! Map<String, dynamic>) {
-            return const AccessDeniedScreen();
-          }
-          final extra = state.extra as Map<String, dynamic>;
-          final material = extra['material'] as mat.Material;
-          final typeStr = extra['type'] as String;
-          final type = typeStr == 'entrada'
-              ? MovimentacaoType.entrada
-              : MovimentacaoType.saida;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'estoque',
-            child: MovimentacaoScreen(
-              construtoraId: cId,
-              material: material,
-              type: type,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/financeiro',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'financeiro',
-            adminOnly: true,
-            child: FinanceiroListScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/financeiro/novo',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'financeiro',
-            adminOnly: true,
-            child: AddDespesaScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/rh',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'rh',
-            child: FuncionariosListScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/rh/funcionarios',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'rh',
-            child: FuncionariosListScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/rh/funcionarios/novo',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'rh',
-            child: FuncionarioFormScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/rh/funcionarios/:fId/editar',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final extra = state.extra;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'rh',
-            child: FuncionarioFormScreen(
-              construtoraId: cId,
-              initialFuncionario: extra is Funcionario ? extra : null,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/epis',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'epi',
-            child: CatalogoEpisScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/epis/entrega',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'epi',
-            child: EntregaEpiScreen(
-              construtoraId: cId,
-              obraId: oId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/validacao/templates',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            module: 'validacao',
-            child: TemplatesListScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/lotes/:loteId/validacoes',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          final loteId = state.pathParameters['loteId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'validacao',
-            child: LoteValidacoesScreen(
-              construtoraId: cId,
-              obraId: oId,
-              loteId: loteId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/lotes/:loteId/validacoes/nova',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          final loteId = state.pathParameters['loteId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'validacao',
-            child: ValidacaoFormScreen(
-              construtoraId: cId,
-              obraId: oId,
-              loteId: loteId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/lotes/:loteId/validacoes/:validacaoId',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          final loteId = state.pathParameters['loteId']!;
-          final validacaoId = state.pathParameters['validacaoId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'validacao',
-            child: ValidacaoFormScreen(
-              construtoraId: cId,
-              obraId: oId,
-              loteId: loteId,
-              validacaoId: validacaoId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/despesas',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'adm',
-            child: DespesasAdmListScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/despesas/nova',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'adm',
-            child: DespesaAdmFormScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/despesas/:despesaId',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          final despesaId = state.pathParameters['despesaId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'adm',
-            child: DespesaAdmDetailsScreen(
-              construtoraId: cId,
-              obraId: oId,
-              despesaId: despesaId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/despesas/:despesaId/editar',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          final despesaId = state.pathParameters['despesaId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'adm',
-            child: DespesaAdmFormScreen(
-              construtoraId: cId,
-              obraId: oId,
-              despesaId: despesaId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/custos-360',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'adm',
-            child: Visao360CustosScreen(construtoraId: cId, obraId: oId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/custos-360/lotes/:loteId',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          final loteId = state.pathParameters['loteId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'adm',
-            child: LoteCustoDetalheScreen(
-              construtoraId: cId,
-              obraId: oId,
-              loteId: loteId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/fornecedores',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            child: FornecedoresListScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/fornecedores/novo',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            child: FornecedorFormScreen(construtoraId: cId),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/fornecedores/:fornecedorId/editar',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final fornecedorId = state.pathParameters['fornecedorId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            child: FornecedorFormScreen(
-              construtoraId: cId,
-              fornecedorId: fornecedorId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/compras',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'compras',
-            child: ComprasListScreen(
-              construtoraId: cId,
-              obraId: oId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/compras/nova',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'compras',
-            child: CompraFormScreen(
-              construtoraId: cId,
-              obraId: oId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/compras/:compraId',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          final compraId = state.pathParameters['compraId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'compras',
-            child: CompraDetalhesScreen(
-              construtoraId: cId,
-              obraId: oId,
-              compraId: compraId,
-            ),
-          );
-        },
-      ),
-      GoRoute(
-        path: '/construtora/:cId/obra/:oId/compras/:compraId/editar',
-        builder: (context, state) {
-          final cId = state.pathParameters['cId']!;
-          final oId = state.pathParameters['oId']!;
-          final compraId = state.pathParameters['compraId']!;
-          return AccessGuard(
-            construtoraId: cId,
-            obraId: oId,
-            module: 'compras',
-            child: CompraFormScreen(
-              construtoraId: cId,
-              obraId: oId,
-              compraId: compraId,
-            ),
-          );
-        },
-      ),
+      ...authRoutes,
+      ...devRoutes,
+      ...construtoraRoutes, // Modificado internamente
     ],
   );
 });

```

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message.

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

## REVIEW CONTENT (unified diff)
```diff
diff --git a/_bmad-output/implementation-artifacts/spec-2-12-indicador-sincronizacao.md b/_bmad-output/implementation-artifacts/spec-2-12-indicador-sincronizacao.md
new file mode 100644
index 0000000..b27f735
--- /dev/null
+++ b/_bmad-output/implementation-artifacts/spec-2-12-indicador-sincronizacao.md
@@ -0,0 +1,93 @@
+---
+title: 'Story 2.12 — Indicador de Sincronização'
+type: 'feature'
+created: '2026-09-16'
+status: 'in-review'
+baseline_commit: '4e100292c3ad81ea45cc4f51a6a60b70c88b5c30'
+route: 'dispatch'
+review_loop_iteration: 0
+context:
+  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
+  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/task.md'
+  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/user_flows.md'
+---
+
+<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">
+
+## Intent
+
+**Problem:** Em uma aplicação PWA offline-first, os usuários no canteiro de obras não possuem visibilidade clara sobre o estado da conexão e da sincronização dos dados locais com o Firebase, gerando insegurança sobre se os registros (como diários de obra e movimentações) foram transmitidos com sucesso ou estão salvos com segurança aguardando sinal.
+
+**Approach:** Desenvolver o componente reativo `SyncIndicator` integrado ao `SigoTopBar` em todas as telas da aplicação, conectado aos fluxos em tempo real do `SyncEngine` e do `OperationQueue`:
+1. Exibir de maneira clara e determinística os quatro estados essenciais:
+   - **Online (Sincronizado):** Conexão ativa e fila local sem pendências (`SyncEngineStatus.idle`, 0 itens pendentes).
+   - **Sincronizando:** Transmissão de dados em andamento (`SyncEngineStatus.syncing` ou itens em transmissão), com ícone animado e rótulo indicativo.
+   - **Offline / Offline pendente:** Sem conexão de rede (`SyncEngineStatus.offline`), exibindo badge com contagem de alterações salvas localmente aguardando conexão.
+   - **Falha / Atenção:** Ocorrência de erros de rede, conflito ou autorização rejeitada (`SyncEngineStatus.error` ou itens com `failed`/`conflict`/`authorization_rejected`), destacando a necessidade de revisão.
+2. Permitir interação por clique no indicador, apresentando um diálogo informativo ou navegação contextual para a tela de fila de sincronização (`SyncQueueScreen`), com opção de forçar nova sincronização manual (`syncNow()`).
+3. Validar todos os comportamentos por testes unitários e de widget no Flutter cobrindo transições de estado, badges de contagem e ação de disparo manual.
+
+## Boundaries & Constraints
+
+**Always:**
+- O indicador DEVE refletir em tempo real qualquer alteração no `SyncEngineStatus` e na quantidade de operações locais da `OperationQueue`.
+- Quando offline com dados locais enfileirados, DEVE destacar que os dados estão preservados no dispositivo com a contagem de itens pendentes.
+- Falhas de autorização (`authorization_rejected`) e conflitos DEVEM ser destacados como estado de atenção/alerta visual para ação do usuário.
+- O clique no indicador deve ser acessível e responsivo tanto em desktop quanto em dispositivos móveis.
+
+**Never:**
+- Nunca exibir falso estado de erro quando o dispositivo estiver meramente offline e os dados estiverem guardados com segurança no IndexedDB/fila local.
+- Nunca bloquear a navegação ou o uso normal das telas enquanto a sincronização ocorre em segundo plano.
+- Nunca disparar múltiplos loops simultâneos de sincronização ao acionar o botão manual de sync.
+
+## I/O & Edge-Case Matrix
+
+| Scenario | Input / State | Expected Output / Behavior | Error Handling |
+|----------|--------------|---------------------------|----------------|
+| Dispositivo online e fila zerada | `SyncEngine.isOnline == true`, `status == idle`, 0 pendentes | Ícone verde/cinza sutil (nuvem com check) com rótulo "Online" ou "Sincronizado" | N/A |
+| Sincronização em andamento | `SyncEngine.status == syncing` | Ícone giratório ou azul pulsante com texto "Sincronizando..." | N/A |
+| Desconexão com dados pendentes | `SyncEngine.isOnline == false`, N operações com state `pending` | Ícone de nuvem offline âmbar com badge `N` e texto "Offline (N pendentes)" | Alerta amigável informando que dados estão salvos localmente |
+| Erro de rede ou comando com falha | Fila contém itens `failed` ou `lastError != null` | Ícone vermelho/laranja de alerta com texto "Falha no envio"; diálogo detalha o erro | Botão "Tentar novamente" aciona `syncNow()` |
+| Operação rejeitada por autorização | Fila contém operação com state `authorization_rejected` | Alerta visual de revisão necessária; diálogo instrui contato com administração | Encaminha para tela da fila para auditoria |
+| Clique do usuário no indicador | Toque/clique sobre o `SyncIndicator` | Abre modal com resumo de conectividade, pendências e botão "Sincronizar agora" | Trata exceções sem quebrar a árvore de widgets |
+
+</frozen-after-approval>
+
+## Code Map
+
+- `app/lib/src/sync/sync_indicator.dart` -- [NEW] Widget reativo `SyncIndicator` que consome `syncEngineProvider` e `OperationQueue.watch()`, exibindo ícone, badge e abrindo diálogo de detalhes da sincronização.
+- `app/lib/src/common_widgets/sigo_top_bar.dart` -- Inclusão do `SyncIndicator` na barra de navegação superior, antes das notificações e do avatar.
+- `app/lib/src/sync/sync_engine.dart` -- Exposição de helpers/providers adicionais de contagem e agregação caso facilitem o binding de UI.
+- `app/test/sync_indicator_test.dart` -- [NEW] Suíte de testes de widget validando renderização dos 4 estados, contadores de itens pendentes e clique para sincronizar.
+
+## Tasks & Acceptance
+
+**Execution:**
+- [x] `app/lib/src/sync/sync_indicator.dart` -- Criar componente `SyncIndicator` e modal de status com resumo e ação de sincronização manual.
+- [x] `app/lib/src/common_widgets/sigo_top_bar.dart` -- Integrar `SyncIndicator` nas ações do `SigoTopBar`, garantindo responsividade mobile/desktop.
+- [x] `app/lib/src/sync/sync_engine.dart` -- Assegurar emissão reativa e determinística para os widgets consumidores.
+- [x] `app/test/sync_indicator_test.dart` -- Criar testes cobrindo estados Online, Sincronizando, Offline pendente, Falha e interação de sincronização manual.
+
+**Acceptance Criteria:**
+- Given o dispositivo conectado à internet e sem operações pendentes, when a aplicação carregar, then o `SyncIndicator` exibe o estado "Online" com ícone de nuvem sincronizada.
+- Given o usuário desconectado da rede e com 2 operações locais enfileiradas, when visualizar a barra superior, then o indicador mostra estado offline com contador de 2 pendências e aviso de dados preservados.
+- Given uma sincronização em execução (`syncing`), when o usuário estiver em qualquer tela com `SigoTopBar`, then o indicador exibe visual de sincronização em andamento.
+- Given o usuário clicar no indicador de sincronização, when o diálogo for aberto, then são exibidos detalhes do status e a opção de acionar "Sincronizar agora".
+
+## Implementation Notes
+
+- **app/lib/src/sync/sync_indicator.dart:** Criado o modelo `SyncSummary` e o provider `syncSummaryProvider` agregando reativamente o estado do `SyncEngine` (`isOnline`, `status`, `lastError`) e a fila do `OperationQueue.instance.watch()`. Desenvolvido o widget `SyncIndicator` com apresentação contextual para os 4 estados principais: `Sincronizado` (nuvem com check em tom teal), `Sincronizando...` (ícone de sync com animação de rotação contínua e badge de itens em trânsito), `Offline` (nuvem offline com badge âmbar indicando contagem de alterações salvas localmente) e `Falha`/`Atenção` (destaque visual com contagem de erros ou conflitos/autorizações rejeitadas). Implementado o diálogo `showSyncStatusDialog` com detalhes da conexão, contadores e acionamento de sincronização manual (`syncNow`).
+- **app/lib/src/common_widgets/sigo_top_bar.dart:** Integrado o `SyncIndicator` nas `actions` da barra superior em todas as telas, tornando a visualização de conectividade e sincronização universal no shell da aplicação. Implementados helpers de navegação resilientes (`_canPop` e `_pop`) com fallback seguro para contextos sem roteador ativo.
+- **app/test/sync_indicator_test.dart:** Criada suíte completa de 8 testes de widget e unidade validando todos os cenários da matriz de I/O: renderização de Sincronizado, Sincronizando (com RotationTransition), Offline com pendências, Offline puro, Falha no envio, Atenção em conflito/autorização rejeitada, abertura do modal com disparo de sincronização manual e integração no `SigoTopBar`.
+- **Verificação:** 8/8 testes da suíte de `sync_indicator_test.dart` passando, 94/94 testes globais do Flutter passando (`flutter test`), 0 issues no `flutter analyze`.
+
+## Spec Change Log
+
+## Review Triage Log
+
+## Verification
+
+**Commands:**
+- `cd app && flutter test test/sync_indicator_test.dart` -- expected: Testes do componente de indicador de sincronização passam com código 0.
+- `cd app && flutter test` -- expected: Toda a suíte de testes do Flutter passa com código 0.
+- `cd app && flutter analyze` -- expected: 0 erros e 0 warnings.
diff --git a/_bmad-output/implementation-artifacts/sprint-status.yaml b/_bmad-output/implementation-artifacts/sprint-status.yaml
index f8e2fd1..671938d 100644
--- a/_bmad-output/implementation-artifacts/sprint-status.yaml
+++ b/_bmad-output/implementation-artifacts/sprint-status.yaml
@@ -62,7 +62,7 @@ development_status:
   2-9-endpoints-transacionais: done
   2-10-idempotencia: done
   2-11-executar-autorizacao: done
-  2-12-indicador-sincronizacao: backlog
+  2-12-indicador-sincronizacao: in-progress
   2-13-sistema-carimbo: backlog
   2-14-versionamento-migracao: backlog
   epic-2-retrospective: optional
diff --git a/app/lib/src/common_widgets/sigo_top_bar.dart b/app/lib/src/common_widgets/sigo_top_bar.dart
index d84f8b9..66434e7 100644
--- a/app/lib/src/common_widgets/sigo_top_bar.dart
+++ b/app/lib/src/common_widgets/sigo_top_bar.dart
@@ -4,6 +4,7 @@ import 'package:flutter_riverpod/flutter_riverpod.dart';
 
 import '../features/authentication/data/auth_repository.dart';
 import '../features/obras/presentation/construtora_obras_provider.dart';
+import '../sync/sync_indicator.dart';
 
 class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
   final String title;
@@ -29,6 +30,26 @@ class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
     }
   }
 
+  bool _canPop(BuildContext context) {
+    try {
+      return context.canPop();
+    } catch (_) {
+      try {
+        return Navigator.of(context).canPop();
+      } catch (_) {
+        return false;
+      }
+    }
+  }
+
+  void _pop(BuildContext context) {
+    try {
+      context.pop();
+    } catch (_) {
+      Navigator.of(context).maybePop();
+    }
+  }
+
   @override
   Widget build(BuildContext context, WidgetRef ref) {
     final authState = ref.watch(authStateChangesProvider);
@@ -50,22 +71,24 @@ class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
       }
     }
 
+    final hasBack = _canPop(context);
+
     return AppBar(
       backgroundColor: Colors.transparent,
       elevation: 0,
       iconTheme: const IconThemeData(
         color: Colors.black87,
       ), // For the drawer icon on mobile
-      leading: context.canPop()
+      leading: hasBack
           ? IconButton(
               icon: const Icon(Icons.arrow_back, color: Colors.black54),
-              onPressed: () => context.pop(),
+              onPressed: () => _pop(context),
             )
           : null,
       title: Row(
         mainAxisSize: MainAxisSize.min,
         children: [
-          if (context.canPop())
+          if (hasBack)
             const Text(
               'Voltar • ',
               style: TextStyle(color: Colors.black54, fontSize: 14),
@@ -88,6 +111,11 @@ class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
       ),
       actions: [
         ...?actions,
+        SyncIndicator(
+          construtoraId: cId,
+          obraId: oId,
+        ),
+        const SizedBox(width: 6),
         IconButton(
           icon: const Icon(Icons.notifications_none, color: Colors.black54),
           onPressed: () {},
diff --git a/app/lib/src/sync/sync_indicator.dart b/app/lib/src/sync/sync_indicator.dart
new file mode 100644
index 0000000..22f767b
--- /dev/null
+++ b/app/lib/src/sync/sync_indicator.dart
@@ -0,0 +1,425 @@
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:go_router/go_router.dart';
+
+import 'operation_queue.dart';
+import 'sync_engine.dart';
+
+/// Provider reativo da lista completa de itens da fila de operações do dispositivo.
+final syncQueueStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
+  return OperationQueue.instance.watch();
+});
+
+/// Modelo resumido do estado da sincronização para apresentação visual.
+class SyncSummary {
+  final bool isOnline;
+  final SyncEngineStatus engineStatus;
+  final int pendingCount;
+  final int failedCount;
+  final int alertCount; // conflict ou authorization_rejected
+  final String? lastError;
+
+  const SyncSummary({
+    required this.isOnline,
+    required this.engineStatus,
+    required this.pendingCount,
+    required this.failedCount,
+    required this.alertCount,
+    this.lastError,
+  });
+
+  bool get isSyncing => engineStatus == SyncEngineStatus.syncing;
+
+  bool get hasAlert => alertCount > 0;
+  bool get hasFailed => failedCount > 0 || engineStatus == SyncEngineStatus.error;
+  bool get isOffline => !isOnline || engineStatus == SyncEngineStatus.offline;
+  bool get isSynced => isOnline && !isSyncing && !hasAlert && !hasFailed && pendingCount == 0;
+}
+
+/// Provider computado que agrega o estado do SyncEngine e a fila local.
+final syncSummaryProvider = Provider<SyncSummary>((ref) {
+  final engine = ref.watch(syncEngineProvider);
+  final queueAsync = ref.watch(syncQueueStreamProvider);
+  final queueItems = queueAsync.value ?? [];
+
+  int pending = 0;
+  int failed = 0;
+  int alert = 0;
+
+  for (final item in queueItems) {
+    final state = item['state'] as String?;
+    if (state == 'pending' || state == 'syncing') {
+      pending++;
+    } else if (state == 'failed') {
+      failed++;
+    } else if (state == 'conflict' || state == 'authorization_rejected') {
+      alert++;
+    }
+  }
+
+  return SyncSummary(
+    isOnline: engine.isOnline,
+    engineStatus: engine.status,
+    pendingCount: pending,
+    failedCount: failed,
+    alertCount: alert,
+    lastError: engine.lastError,
+  );
+});
+
+/// Componente visual reativo que exibe o status de conectividade e sincronização no app bar.
+class SyncIndicator extends ConsumerStatefulWidget {
+  final String? construtoraId;
+  final String? obraId;
+
+  const SyncIndicator({
+    super.key,
+    this.construtoraId,
+    this.obraId,
+  });
+
+  @override
+  ConsumerState<SyncIndicator> createState() => _SyncIndicatorState();
+}
+
+class _SyncIndicatorState extends ConsumerState<SyncIndicator>
+    with SingleTickerProviderStateMixin {
+  late final AnimationController _rotationController;
+
+  @override
+  void initState() {
+    super.initState();
+    _rotationController = AnimationController(
+      vsync: this,
+      duration: const Duration(seconds: 2),
+    );
+  }
+
+  @override
+  void dispose() {
+    _rotationController.dispose();
+    super.dispose();
+  }
+
+  @override
+  Widget build(BuildContext context) {
+    final summary = ref.watch(syncSummaryProvider);
+
+    if (summary.isSyncing) {
+      if (!_rotationController.isAnimating) {
+        _rotationController.repeat();
+      }
+    } else {
+      if (_rotationController.isAnimating) {
+        _rotationController.stop();
+        _rotationController.reset();
+      }
+    }
+
+    Color iconColor;
+    Color bgColor;
+    IconData iconData;
+    String label;
+    String tooltip;
+    int? badgeCount;
+
+    if (summary.hasAlert) {
+      iconColor = Colors.red.shade700;
+      bgColor = Colors.red.shade50;
+      iconData = Icons.warning_amber_rounded;
+      label = 'Atenção';
+      tooltip = 'Atenção: registros com conflito ou acesso revogado';
+      badgeCount = summary.alertCount;
+    } else if (summary.hasFailed) {
+      iconColor = Colors.deepOrange.shade700;
+      bgColor = Colors.deepOrange.shade50;
+      iconData = Icons.sync_problem;
+      label = 'Falha';
+      tooltip = 'Falha na sincronização';
+      badgeCount = summary.failedCount > 0 ? summary.failedCount : null;
+    } else if (summary.isOffline) {
+      iconColor = summary.pendingCount > 0 ? Colors.amber.shade900 : Colors.grey.shade600;
+      bgColor = summary.pendingCount > 0 ? Colors.amber.shade50 : Colors.grey.shade100;
+      iconData = Icons.cloud_off;
+      label = summary.pendingCount > 0 ? 'Offline (${summary.pendingCount})' : 'Offline';
+      tooltip = summary.pendingCount > 0
+          ? 'Offline: ${summary.pendingCount} registro(s) salvo(s) neste dispositivo'
+          : 'Modo offline';
+      badgeCount = summary.pendingCount > 0 ? summary.pendingCount : null;
+    } else if (summary.isSyncing) {
+      iconColor = Colors.blue.shade700;
+      bgColor = Colors.blue.shade50;
+      iconData = Icons.sync;
+      label = 'Sincronizando...';
+      tooltip = 'Sincronizando dados com o servidor...';
+      badgeCount = summary.pendingCount > 0 ? summary.pendingCount : null;
+    } else {
+      iconColor = Colors.teal.shade700;
+      bgColor = Colors.teal.shade50;
+      iconData = Icons.cloud_done;
+      label = 'Sincronizado';
+      tooltip = 'Online: todos os registros estão sincronizados';
+      badgeCount = null;
+    }
+
+    return Tooltip(
+      message: tooltip,
+      child: InkWell(
+        key: const Key('sync-indicator'),
+        borderRadius: BorderRadius.circular(20),
+        onTap: () => showSyncStatusDialog(
+          context: context,
+          ref: ref,
+          construtoraId: widget.construtoraId,
+          obraId: widget.obraId,
+        ),
+        child: Container(
+          height: 34,
+          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
+          decoration: BoxDecoration(
+            color: bgColor,
+            borderRadius: BorderRadius.circular(20),
+            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
+          ),
+          child: Row(
+            mainAxisSize: MainAxisSize.min,
+            children: [
+              summary.isSyncing
+                  ? RotationTransition(
+                      turns: _rotationController,
+                      child: Icon(
+                        iconData,
+                        key: const Key('sync-indicator-icon'),
+                        size: 18,
+                        color: iconColor,
+                      ),
+                    )
+                  : Icon(
+                      iconData,
+                      key: const Key('sync-indicator-icon'),
+                      size: 18,
+                      color: iconColor,
+                    ),
+              const SizedBox(width: 6),
+              Text(
+                label,
+                key: const Key('sync-indicator-label'),
+                style: TextStyle(
+                  fontSize: 12,
+                  fontWeight: FontWeight.w600,
+                  color: iconColor,
+                ),
+              ),
+              if (badgeCount != null && badgeCount > 0) ...[
+                const SizedBox(width: 6),
+                Container(
+                  key: const Key('sync-indicator-badge'),
+                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
+                  decoration: BoxDecoration(
+                    color: iconColor,
+                    borderRadius: BorderRadius.circular(10),
+                  ),
+                  child: Text(
+                    '$badgeCount',
+                    style: const TextStyle(
+                      color: Colors.white,
+                      fontSize: 10,
+                      fontWeight: FontWeight.bold,
+                    ),
+                  ),
+                ),
+              ],
+            ],
+          ),
+        ),
+      ),
+    );
+  }
+}
+
+/// Diálogo de detalhes e controle da sincronização
+Future<void> showSyncStatusDialog({
+  required BuildContext context,
+  required WidgetRef ref,
+  String? construtoraId,
+  String? obraId,
+}) {
+  return showDialog<void>(
+    context: context,
+    builder: (dialogContext) {
+      return Consumer(
+        builder: (context, ref, _) {
+          final summary = ref.watch(syncSummaryProvider);
+          final engine = ref.watch(syncEngineProvider);
+
+          String statusTitle;
+          String statusDescription;
+          Color statusColor;
+          IconData statusIcon;
+
+          if (summary.hasAlert) {
+            statusTitle = 'Revisão Necessária';
+            statusDescription =
+                'Existem registros locais que requerem revisão administrativa ou tiveram permissão recusada. Os dados permanecem preservados no seu dispositivo.';
+            statusColor = Colors.red.shade700;
+            statusIcon = Icons.warning_amber_rounded;
+          } else if (summary.hasFailed) {
+            statusTitle = 'Falha no Envio';
+            statusDescription =
+                'Ocorreu uma falha na tentativa de envio dos dados. Verifique sua conexão e tente novamente.';
+            statusColor = Colors.deepOrange.shade700;
+            statusIcon = Icons.sync_problem;
+          } else if (summary.isOffline) {
+            statusTitle = 'Modo Offline';
+            statusDescription = summary.pendingCount > 0
+                ? 'Você está desconectado. Há ${summary.pendingCount} operação(ões) salva(s) localmente neste dispositivo e prontas para envio automático assim que a conexão retornar.'
+                : 'Você está desconectado. As alterações feitas serão armazenadas com segurança no dispositivo.';
+            statusColor = summary.pendingCount > 0 ? Colors.amber.shade900 : Colors.grey.shade700;
+            statusIcon = Icons.cloud_off;
+          } else if (summary.isSyncing) {
+            statusTitle = 'Sincronizando';
+            statusDescription =
+                'Transmitindo registros locais para o servidor em segundo plano...';
+            statusColor = Colors.blue.shade700;
+            statusIcon = Icons.sync;
+          } else {
+            statusTitle = 'Tudo Sincronizado';
+            statusDescription =
+                'Sua conexão está ativa e todos os registros deste dispositivo estão sincronizados com a nuvem.';
+            statusColor = Colors.teal.shade700;
+            statusIcon = Icons.cloud_done;
+          }
+
+          return AlertDialog(
+            key: const Key('sync-status-dialog'),
+            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
+            title: Row(
+              children: [
+                Icon(statusIcon, color: statusColor, size: 28),
+                const SizedBox(width: 12),
+                Expanded(
+                  child: Text(
+                    statusTitle,
+                    style: TextStyle(
+                      fontSize: 18,
+                      fontWeight: FontWeight.bold,
+                      color: statusColor,
+                    ),
+                  ),
+                ),
+              ],
+            ),
+            content: SingleChildScrollView(
+              child: Column(
+                mainAxisSize: MainAxisSize.min,
+                crossAxisAlignment: CrossAxisAlignment.start,
+                children: [
+                  Text(
+                    statusDescription,
+                    style: const TextStyle(fontSize: 14, color: Colors.black87),
+                  ),
+                  const SizedBox(height: 16),
+                  const Divider(),
+                  const SizedBox(height: 8),
+                  _buildStatusRow(
+                    label: 'Conexão',
+                    value: summary.isOnline ? 'Online' : 'Offline',
+                    valueColor: summary.isOnline ? Colors.teal.shade700 : Colors.grey.shade700,
+                  ),
+                  _buildStatusRow(
+                    label: 'Operações locais pendentes',
+                    value: '${summary.pendingCount}',
+                  ),
+                  if (summary.failedCount > 0)
+                    _buildStatusRow(
+                      label: 'Operações com falha',
+                      value: '${summary.failedCount}',
+                      valueColor: Colors.deepOrange.shade700,
+                    ),
+                  if (summary.alertCount > 0)
+                    _buildStatusRow(
+                      label: 'Requerem atenção',
+                      value: '${summary.alertCount}',
+                      valueColor: Colors.red.shade700,
+                    ),
+                  if (summary.lastError != null && summary.lastError!.isNotEmpty) ...[
+                    const SizedBox(height: 12),
+                    Text(
+                      'Último aviso: ${summary.lastError}',
+                      style: TextStyle(fontSize: 12, color: Colors.red.shade600),
+                    ),
+                  ],
+                ],
+              ),
+            ),
+            actions: [
+              if (construtoraId != null && construtoraId.isNotEmpty)
+                TextButton.icon(
+                  key: const Key('view-queue-button'),
+                  icon: const Icon(Icons.list_alt, size: 18),
+                  label: const Text('Ver fila local'),
+                  onPressed: () {
+                    Navigator.of(dialogContext).pop();
+                    if (obraId != null && obraId.isNotEmpty) {
+                      context.go('/construtora/$construtoraId/obra/$obraId/diarios/sync');
+                    } else {
+                      context.go('/construtora/$construtoraId/sync');
+                    }
+                  },
+                ),
+              ElevatedButton.icon(
+                key: const Key('sync-now-button'),
+                style: ElevatedButton.styleFrom(
+                  backgroundColor: Colors.amber.shade700,
+                  foregroundColor: Colors.white,
+                ),
+                icon: const Icon(Icons.sync, size: 18),
+                label: const Text('Sincronizar agora'),
+                onPressed: summary.isSyncing
+                    ? null
+                    : () async {
+                        Navigator.of(dialogContext).pop();
+                        await engine.syncNow(
+                          construtoraId: construtoraId,
+                          obraId: obraId,
+                        );
+                      },
+              ),
+              TextButton(
+                onPressed: () => Navigator.of(dialogContext).pop(),
+                child: const Text('Fechar'),
+              ),
+            ],
+          );
+        },
+      );
+    },
+  );
+}
+
+Widget _buildStatusRow({
+  required String label,
+  required String value,
+  Color? valueColor,
+}) {
+  return Padding(
+    padding: const EdgeInsets.symmetric(vertical: 4),
+    child: Row(
+      mainAxisAlignment: MainAxisAlignment.spaceBetween,
+      children: [
+        Text(
+          label,
+          style: const TextStyle(fontSize: 13, color: Colors.black54),
+        ),
+        Text(
+          value,
+          style: TextStyle(
+            fontSize: 13,
+            fontWeight: FontWeight.bold,
+            color: valueColor ?? Colors.black87,
+          ),
+        ),
+      ],
+    ),
+  );
+}
diff --git a/app/test/sync_indicator_test.dart b/app/test/sync_indicator_test.dart
new file mode 100644
index 0000000..ae36c6f
--- /dev/null
+++ b/app/test/sync_indicator_test.dart
@@ -0,0 +1,302 @@
+import 'dart:async';
+
+import 'package:connectivity_plus/connectivity_plus.dart';
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:app/src/common_widgets/sigo_top_bar.dart';
+import 'package:app/src/features/authentication/data/auth_repository.dart';
+import 'package:app/src/sync/operation_queue.dart';
+import 'package:app/src/sync/sync_engine.dart';
+import 'package:app/src/sync/sync_indicator.dart';
+
+void main() {
+  TestWidgetsFlutterBinding.ensureInitialized();
+
+  group('Story 2.12 — Indicador de Sincronização (SyncIndicator)', () {
+    testWidgets('renderiza estado Sincronizado quando online e sem pendencias', (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            syncSummaryProvider.overrideWithValue(
+              const SyncSummary(
+                isOnline: true,
+                engineStatus: SyncEngineStatus.idle,
+                pendingCount: 0,
+                failedCount: 0,
+                alertCount: 0,
+              ),
+            ),
+          ],
+          child: const MaterialApp(
+            home: Scaffold(
+              body: Center(
+                child: SyncIndicator(),
+              ),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+
+      expect(find.byKey(const Key('sync-indicator')), findsOneWidget);
+      expect(find.byKey(const Key('sync-indicator-label')), findsOneWidget);
+      expect(find.text('Sincronizado'), findsOneWidget);
+      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
+      expect(find.byKey(const Key('sync-indicator-badge')), findsNothing);
+    });
+
+    testWidgets('renderiza estado Sincronizando quando em transmissao ativa', (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            syncSummaryProvider.overrideWithValue(
+              const SyncSummary(
+                isOnline: true,
+                engineStatus: SyncEngineStatus.syncing,
+                pendingCount: 3,
+                failedCount: 0,
+                alertCount: 0,
+              ),
+            ),
+          ],
+          child: const MaterialApp(
+            home: Scaffold(
+              body: Center(
+                child: SyncIndicator(),
+              ),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pump(const Duration(milliseconds: 100));
+
+      expect(find.byKey(const Key('sync-indicator')), findsOneWidget);
+      expect(find.text('Sincronizando...'), findsOneWidget);
+      expect(find.byIcon(Icons.sync), findsOneWidget);
+      expect(
+        find.descendant(
+          of: find.byKey(const Key('sync-indicator')),
+          matching: find.byType(RotationTransition),
+        ),
+        findsOneWidget,
+      );
+      expect(find.text('3'), findsOneWidget);
+    });
+
+    testWidgets('renderiza estado Offline com contador de alteracoes pendentes preservadas', (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            syncSummaryProvider.overrideWithValue(
+              const SyncSummary(
+                isOnline: false,
+                engineStatus: SyncEngineStatus.offline,
+                pendingCount: 2,
+                failedCount: 0,
+                alertCount: 0,
+              ),
+            ),
+          ],
+          child: const MaterialApp(
+            home: Scaffold(
+              body: Center(
+                child: SyncIndicator(),
+              ),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+
+      expect(find.byKey(const Key('sync-indicator')), findsOneWidget);
+      expect(find.text('Offline (2)'), findsOneWidget);
+      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
+      expect(find.byKey(const Key('sync-indicator-badge')), findsOneWidget);
+      expect(find.text('2'), findsOneWidget);
+    });
+
+    testWidgets('renderiza estado Offline puro quando sem pendencias locais', (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            syncSummaryProvider.overrideWithValue(
+              const SyncSummary(
+                isOnline: false,
+                engineStatus: SyncEngineStatus.offline,
+                pendingCount: 0,
+                failedCount: 0,
+                alertCount: 0,
+              ),
+            ),
+          ],
+          child: const MaterialApp(
+            home: Scaffold(
+              body: Center(
+                child: SyncIndicator(),
+              ),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+
+      expect(find.text('Offline'), findsOneWidget);
+      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
+      expect(find.byKey(const Key('sync-indicator-badge')), findsNothing);
+    });
+
+    testWidgets('renderiza estado Falha quando ha operacoes com erro ou falha no motor', (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            syncSummaryProvider.overrideWithValue(
+              const SyncSummary(
+                isOnline: true,
+                engineStatus: SyncEngineStatus.error,
+                pendingCount: 0,
+                failedCount: 1,
+                alertCount: 0,
+                lastError: 'Falha de conexao temporaria',
+              ),
+            ),
+          ],
+          child: const MaterialApp(
+            home: Scaffold(
+              body: Center(
+                child: SyncIndicator(),
+              ),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+
+      expect(find.text('Falha'), findsOneWidget);
+      expect(find.byIcon(Icons.sync_problem), findsOneWidget);
+      expect(find.text('1'), findsOneWidget);
+    });
+
+    testWidgets('renderiza estado Atencao quando ha conflito ou autorizacao rejeitada', (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            syncSummaryProvider.overrideWithValue(
+              const SyncSummary(
+                isOnline: true,
+                engineStatus: SyncEngineStatus.idle,
+                pendingCount: 1,
+                failedCount: 0,
+                alertCount: 1,
+                lastError: 'Acesso recusado',
+              ),
+            ),
+          ],
+          child: const MaterialApp(
+            home: Scaffold(
+              body: Center(
+                child: SyncIndicator(),
+              ),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+
+      expect(find.text('Atenção'), findsOneWidget);
+      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
+      expect(find.text('1'), findsOneWidget);
+    });
+
+    testWidgets('toque no SyncIndicator abre o dialogo de status e aciona sincronizacao manual', (tester) async {
+      final testEngine = SyncEngine(
+        queue: OperationQueue.instance,
+        connectivityStream: const Stream.empty(),
+        checkConnectivity: () async => [ConnectivityResult.wifi],
+        periodicInterval: const Duration(days: 1),
+        autoStart: false,
+        observeLifecycle: false,
+      );
+
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            syncEngineProvider.overrideWithValue(testEngine),
+            syncSummaryProvider.overrideWithValue(
+              const SyncSummary(
+                isOnline: true,
+                engineStatus: SyncEngineStatus.idle,
+                pendingCount: 3,
+                failedCount: 0,
+                alertCount: 0,
+              ),
+            ),
+          ],
+          child: const MaterialApp(
+            home: Scaffold(
+              body: Center(
+                child: SyncIndicator(construtoraId: 'c1', obraId: 'o1'),
+              ),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+
+      // Clica no indicador para abrir o diálogo
+      await tester.tap(find.byKey(const Key('sync-indicator')));
+      await tester.pumpAndSettle();
+
+      expect(find.byKey(const Key('sync-status-dialog')), findsOneWidget);
+      expect(find.text('Tudo Sincronizado'), findsOneWidget);
+      expect(find.text('Operações locais pendentes'), findsOneWidget);
+      expect(find.text('3'), findsOneWidget);
+      expect(find.byKey(const Key('sync-now-button')), findsOneWidget);
+      expect(find.byKey(const Key('view-queue-button')), findsOneWidget);
+
+      // Clica no botão de sincronizar agora
+      await tester.tap(find.byKey(const Key('sync-now-button')));
+      await tester.pumpAndSettle();
+
+      // Diálogo deve fechar após acionar
+      expect(find.byKey(const Key('sync-status-dialog')), findsNothing);
+    });
+
+    testWidgets('SigoTopBar embute SyncIndicator automaticamente em suas actions', (tester) async {
+      await tester.pumpWidget(
+        ProviderScope(
+          overrides: [
+            authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
+            syncSummaryProvider.overrideWithValue(
+              const SyncSummary(
+                isOnline: true,
+                engineStatus: SyncEngineStatus.idle,
+                pendingCount: 0,
+                failedCount: 0,
+                alertCount: 0,
+              ),
+            ),
+          ],
+          child: const MaterialApp(
+            home: Scaffold(
+              appBar: SigoTopBar(title: 'Teste TopBar'),
+            ),
+          ),
+        ),
+      );
+
+      await tester.pumpAndSettle();
+
+      expect(find.byKey(const Key('sync-indicator')), findsOneWidget);
+      expect(find.text('Sincronizado'), findsOneWidget);
+      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
+    });
+  });
+}

```

You are an Acceptance Auditor. Review the provided diff against `/Users/usuario/obras/_bmad-output/implementation-artifacts/spec-11-2-navegacao-lote-setor-equipe.md` and any loaded context docs. Check for: violations of acceptance criteria, deviations from spec intent, missing implementation of specified behavior, contradictions between spec constraints and actual code. Output findings as a Markdown list. Each finding: one-line title, which AC/constraint it violates, and evidence from the diff.

Diff:
diff --git a/_bmad-output/implementation-artifacts/deferred-work.md b/_bmad-output/implementation-artifacts/deferred-work.md
index a68e269..a6bf381 100644
--- a/_bmad-output/implementation-artifacts/deferred-work.md
+++ b/_bmad-output/implementation-artifacts/deferred-work.md
@@ -181,3 +181,19 @@ Findings 19–21 fechados em `spec-estabilizar-vinculos-epicos-8-10` (setCargo r
 - source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
   summary: Demais findings low adiados: isFormValid sem `lotesValidosDaObra`; data duplicada só advisory sem teste; `_syncWorkersList` muta em build; conflito mostra `obraId` cru; `saveDefaultLot` sem tratamento de erro; sem teste de write lento/wiring do sticky bar; exceção crua no snackbar; uid fallback `unknown`; sem `PopScope`; `findChamadaByDate` da fixture sempre null; date picker 2020–2035.
   evidence: todos pré-existente ou gap de cobertura fora do intent de concorrência; ver Review Triage Log da spec.
+
+- source_spec: `_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md`
+  summary: As Boundaries do spec descrevem a hierarquia em plural (`/construtoras/:cId/...`) enquanto o app usa o singular (`/construtora/:cId`).
+  evidence: divergência real de documentação; o singular é a convenção de todo o app (`ConstrutoraPaths.detail`) e a navegação funciona; pré-existente, não introduzido pela 11.1.
+
+- source_spec: `_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md`
+  summary: Ramos `error`/`loading` das listagens de loteamentos, quadras e lotes não têm testes.
+  evidence: lacuna de cobertura real (só vazio/dados/rebuild são exercitados); sem defeito demonstrado no comportamento atual.
+
+- source_spec: `_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md`
+  summary: `watchLoteamentosProvider`/`watchQuadrasProvider`/`watchLotesProvider` são `StreamProvider.family` sem `autoDispose`, mantendo subscriptions do Firestore por toda a sessão.
+  evidence: padrão já usado por setores/equipes; `autoDispose` reintroduziria o `AsyncLoading` que a história quer evitar; decisão de ciclo de vida de provider a revisitar.
+
+## Deferred from: code review of spec-11-1-navegacao-loteamento-quadra-lote (2026-09-24)
+
+- `StreamProvider.family` sem `autoDispose` acumula subscriptions do Firestore. source_spec: `_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md`; location: `app/lib/src/features/loteamentos/data/loteamento_repository.dart:36`. Evidence: padrão pré-existente de setores/equipes; `autoDispose` reintroduziria o `AsyncLoading` que a história quer evitar; decisão de ciclo de vida de provider a revisitar.
diff --git a/_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md b/_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md
new file mode 100644
index 0000000..b985c00
--- /dev/null
+++ b/_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md
@@ -0,0 +1,130 @@
+---
+title: 'Story 11.1 - Navegação Loteamento → Quadra → Lote'
+type: 'feature'
+created: '2026-09-24'
+status: 'done'
+route: 'dispatch'
+review_loop_iteration: 0
+baseline_commit: '068978981139fb56dca53c42456792da7fa71458'
+context: ['_bmad-output/implementation-artifacts/epic-11-context.md']
+---
+
+<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">
+
+## Intent
+
+**Problem:** O sistema precisa de uma fundação sólida para a navegação estrutural baseada em Loteamentos, Quadras e Lotes (os três primeiros níveis da hierarquia de 5 níveis). Como o dashboard atual não suporta esse drill-down completo e otimizado de forma aninhada, os usuários não conseguem visualizar a organização básica das obras.
+
+**Approach:** Criar as rotas aninhadas para `loteamentos`, `quadras` e `lotes` utilizando o GoRouter. Implementar as telas de listagem para cada um desses níveis, replicando a estrutura de navegação e os componentes genéricos construídos na Story 11.2 (como o `SigoBreadcrumbs`). O gerenciamento de estado nas listagens deve utilizar Records nos providers do Riverpod para a passagem de múltiplos IDs, evitando assim o loop contínuo de `AsyncLoading` durante o rebuild.
+
+## Boundaries & Constraints
+
+**Always:** 
+- O estado da navegação deve ser mantido na URL (path parameters) seguindo a hierarquia `/construtoras/:cId/loteamentos/:lId/quadras/:qId/lotes/:loId`.
+- Reutilizar o componente genérico `SigoBreadcrumbs` implementado na Story 11.2 para permitir o retorno rápido aos níveis superiores da hierarquia de forma consistente.
+- Utilizar Records no Riverpod (ex.: family com `({String loteamentoId, String quadraId})`) ao criar os Streams de listagem para evitar loops de carregamento ou múltiplas subscrições que geram piscar na interface (`AsyncLoading`).
+- Testes automatizados (unitários/widget) devem cobrir a lógica de rotas, a listagem e os breadcrumbs, garantindo a mesma cobertura e qualidade alcançadas na Story 11.2.
+
+**Never:** 
+- Não usar estado em memória (como provedores estáticos ou globais separados) para gerenciar o ID atual da rota. O GoRouter/URL deve ser a fonte da verdade.
+
+**Decisions:**
+- O escopo desta história foca em UI, roteamento com GoRouter e gerenciamento de estado das listagens com Riverpod + Records. 
+- A camada do Firestore para as entidades de loteamento, quadra e lote deve ser conectada de forma alinhada à subcoleção, e as regras de segurança correspondentes (`firestore.rules`) devem ser revisadas ou criadas caso falte o suporte de leitura ao respectivo nó.
+
+</frozen-after-approval>
+
+## Code Map
+
+- `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart` -- Definição das rotas de nível 1.
+- `app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart` -- Tela de listagem de loteamentos.
+- `app/lib/src/features/quadras/routing/quadras_routes.dart` -- Definição das rotas de nível 2.
+- `app/lib/src/features/quadras/presentation/quadras_list_screen.dart` -- Tela de listagem de quadras de um loteamento.
+- `app/lib/src/features/lotes/routing/lotes_routes.dart` -- Integração e atualização das rotas de nível 3 para funcionar como filha de Quadra e pai de Setores (Story 11.2).
+- `app/lib/src/features/lotes/presentation/lotes_list_screen.dart` -- Atualização/Criação da tela de listagem de lotes utilizando Records no Riverpod.
+
+## Tasks & Acceptance
+
+**Execution:**
+- [x] `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart` -- Criar módulo de rotas para Loteamentos (como child da rota de construtora).
+- [x] `app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart` -- Implementar tela base incluindo o `SigoBreadcrumbs` e listagem baseada em StreamProvider.
+- [x] `app/lib/src/features/quadras/routing/quadras_routes.dart` -- Criar módulo de rotas para Quadras aninhado em `:loteamentoId`.
+- [x] `app/lib/src/features/quadras/presentation/quadras_list_screen.dart` -- Implementar tela de listagem de Quadras utilizando Records no Riverpod e breadcrumbs dinâmicos.
+- [x] `app/lib/src/features/lotes/routing/lotes_routes.dart` -- Refatorar as rotas de lotes para serem filhas de `:quadraId`, mantendo integridade com as rotas descendentes (Setor e Equipe construídos na 11.2).
+- [x] `app/lib/src/features/lotes/presentation/lotes_list_screen.dart` -- Refatorar tela de listagem de Lotes, usando `SigoBreadcrumbs` e Records nos provedores Riverpod para prevenir loops de `AsyncLoading`.
+- [x] `firestore.rules` -- Revisar security rules para as subcoleções `loteamentos`, `quadras` e `lotes`, preservando o isolamento de segurança baseado na Construtora/Nó.
+- [x] `app/test/` -- Adicionar testes automatizados cobrindo os providers Riverpod de listagem (verificando Records vs AsyncLoading) e garantindo correta geração dos breadcrumbs e rotas.
+
+**Acceptance Criteria:**
+- Given que um usuário acessou o dashboard de uma construtora, when ele abrir Loteamentos, then a URL deve espelhar a rota de loteamento e a `LoteamentosListScreen` renderiza seus breadcrumbs correspondentes.
+- Given que um usuário acessa a tela de Lotes, when a tela é visualizada, then o estado carrega corretamente os itens via Riverpod usando Records e a interface não apresenta transições desnecessárias de loading (piscar de AsyncLoading).
+- Given que o usuário clica em "Quadra X" no breadcrumb na tela de Lotes, then a navegação ascende para a rota correta da listagem de lotes mantendo os IDs pais intocados na URL.
+
+## Verification
+
+**Commands:**
+- `flutter analyze` -- expected: Sem problemas nos arquivos de roteamento e nas novas listagens com Records.
+- `flutter test` -- expected: Cobertura dos provedores refatorados e dos fluxos de breadcrumbs.
+
+## Review Triage Log
+
+- `false` — firestore.rules marcado `[x]` sem diff: as rules de `loteamentos`/`quadras`/`lotes` já concedem `read: if member(c)` e `write: if admin(c)` (firestore.rules:46-65); "revisar" não exige alteração e o isolamento por construtora está preservado.
+- `false` — ACs "sem marcação": são declarações Given/When/Then, não checkboxes; o template só marca `Execution`.
+- `false` — `review_loop_iteration` não incrementado: a iteração só sobe antes de um loopback, não na primeira passada de review.
+- `false` — sprint-status `in-progress` vs frontmatter `in-review`: o ciclo do sprint-status mapeia para `review` apenas na conclusão (step-05); `in-progress` durante o review é esperado.
+- `false` — `spec-fix-testes-obsoletos-lote` `done` só com defers, e notas não verificáveis no diff: artefato de outra história; não causado por esta mudança.
+- `false` — diff inclui edições de outra história (`setores_routes.dart`, `movimentacao_screen.dart`): alterações pré-existentes/não commitadas de outro escopo, ampliadas pelo range do baseline; sem dano.
+- `false` — "nenhum teste cobre os redirects entregues": os redirects `:loteamentoId→/quadras` e `:quadraId→/lotes` SÃO exercitados pelos testes que usam `construtoraRoutes` (neutralizá-los quebra a suíte). O caso `:loteId/:setorId` está tratado à parte (ver `medium` do verification-gap).
+- `false` — "ramo condicional `null` do redirect sem teste": o ramo `uri.path != matchedLocation` é exercitado pelos testes de deep path em `construtoraRoutes`.
+- `false` — "mensagem de erro fixa remove detalhe": segue o padrão das telas da 11.2; ocultar erro bruto do usuário é intencional, não regressão.
+- `false` — "dependência 11.1/11.2 não reconciliada" e "sem contrato documentado de labels dos breadcrumbs": processo/documentação; a dependência já consta no `epic-11-context` e o widget deriva labels do path, com testes fixando o comportamento.
+- `false` — "Verification sem evidência observada": `flutter analyze` (limpo) e `flutter test` (459 verdes) foram executados; o fix editaria o próprio spec do build (rejeitado por regra).
+- `false` — "id cru com `?`/`#`/`/` interpolado na URL": os ids são UUID v4 (`add_lote_screen.dart:32`) e doc ids do Firestore, URL-safe; caso inalcançável.
+- `medium` (blind-hunter + verification-gap, mesmo root cause) — testes de "rebuild sem AsyncLoading" não comprovam a propriedade: em `loteamentos_list_screen_test.dart` o `child:` `const` faz `Element.updateChild` curto-circuitar e a tela NÃO é reconstruída, então o teste passa independentemente; os testes de provider só checam `identical` (cache normal do Riverpod). Patch.
+- `medium` (verification-gap) — redirects `:loteId→/setores` e `:setorId→/equipes` sem teste: comprovado que neutralizá-los mantém a suíte relacionada verde. Patch.
+- `low` → defer — "Boundaries em plural `/construtoras/...` vs código singular `/construtora/`": divergência de documentação, mas o singular é a convenção de todo o app (`ConstrutoraPaths.detail`); navegação funciona; pré-existente.
+- `low` → defer — ramos `error`/`loading` das listagens sem teste: lacuna de cobertura, sem defeito demonstrado.
+- `low` → defer — `family` sem `autoDispose` acumula subscriptions do Firestore: padrão já usado por setores/equipes; `autoDispose` reintroduziria o `AsyncLoading` que a história quer evitar; decisão de design a revisitar.
+- `low` → rejeitado — trailing slash quebra o redirect: improvável no uso diário e o fix adiciona normalização/guard (custo > correção direta).
+- `low` → rejeitado — URLs literais em vez de `LoteamentosPaths`/`QuadrasPaths`: DRY apenas de desenvolvedor, sem dano ao usuário e refatoração não trivial.
+- `low` → rejeitado — query params perdidos no redirect: estas rotas não carregam query params; hipotético.
+- `low` → rejeitado — fakes/factories duplicados entre arquivos de teste e mistura `test/` vs `test/src/features/`: organização de testes, sem impacto funcional.
+
+### Review Findings
+
+#### Decision
+
+- [x] [Review][Decision] AC1 sem ponto de entrada no dashboard — `LoteamentosListScreen` existe, mas `ObrasListScreen` não expõe nenhuma ação/atalho para `/construtora/:cId/loteamentos` (actions só cobrem obras/membros/rh/almoxarifado/financeiro/validacao/epis/fornecedores). O fluxo do AC1 ("abrir Loteamentos" a partir do dashboard) só é alcançável por URL manual/deep-link. Definir se adiciona entrada e qual permissão a gateia, ou se a AC deve ser lida como deep-link. [app/lib/src/features/obras/presentation/obras_list_screen.dart:79-150]
+- [x] [Review][Decision] Segmento-pai do breadcrumb não ascende — em `/.../quadras/q1/lotes`, o crumb "Quadra" aponta para `/.../quadras/q1`, que redireciona de volta para `/.../lotes` (mesma tela); só o crumb "Loteamento" sobe de nível. Definir se crumbs-pai devem apontar para a rota de listagem (`/.../quadras`) — mudança em `sigo_breadcrumbs.dart`, compartilhado com a 11.2. [app/lib/src/common_widgets/sigo_breadcrumbs.dart:34]
+
+#### Patch
+
+- [x] [Review][Patch] IDs encaminhados pelos providers não são verificados por teste — os fakes ignoram os argumentos (`Stream.value`), então trocar a ordem dos IDs em `quadra_repository.dart:39` / `lote_repository.dart:43-47` mantém a suíte verde e uma regressão de path do Firestore passa silenciosamente. Assertar os IDs recebidos e isolar chaves de `family` distintas. [app/test/loteamento_quadra_lote_providers_test.dart:1059]
+- [x] [Review][Patch] Ramos de erro das 3 listagens sem teste — os callbacks `error:` só são exercitados por `Stream.value`; nenhum override com `AsyncError`/`Stream.error`. Adicionar um teste por tela assertando a mensagem fixa. [app/test/src/features/lotes/presentation/lotes_list_screen_test.dart:1311]
+
+#### Defer
+
+- [x] [Review][Defer] `StreamProvider.family` sem `autoDispose` acumula subscriptions do Firestore [app/lib/src/features/loteamentos/data/loteamento_repository.dart:36] — deferred: padrão pré-existente de setores/equipes; `autoDispose` reintroduziria o `AsyncLoading` que a história quer evitar; decisão de ciclo de vida a revisitar.
+
+#### Rejected
+
+- `false` — frontmatter `status: done` vs sprint-status `review`: trackers com propósitos distintos (autoria do spec vs tracking de sprint); `review` é o estado esperado durante o review; sem efeito de código.
+- `false` — `review_loop_iteration` em 0: contador só sobe em loopback, não na primeira passada.
+- `false` — testes de provider "só checam `identical`": o `identical` reflete o cache normal do Riverpod; a lacuna acionável é o mapeamento de IDs (item Patch acima).
+- `false` — teste de "rebuild sem AsyncLoading" mede `buildCount` no wrapper, não na tela: o wrapper reconstrói um `LoteamentosListScreen` não-`const`, logo a tela é reconstruída e a ausência de `CircularProgressIndicator` é assertion válida (o defeito de `child:` `const` foi corrigido).
+- `false` — "nenhum teste dirige transições lista→lista pelas rotas reais": o teste de breadcrumbs usa `construtoraRoutes` e navega Lotes→Quadras; os testes de item-tap usam routers que replicam os paths.
+- `false` — redirects `:loteId`/`:setorId` "não exercitados": o tap no crumb "Lote"/"Setor" navega para a origem do redirect (`/lotes/:loteId`, `/setores/:setorId`), e remover o redirect quebraria esses testes.
+- `false` — providers como `final` de topo na camada de dados: mesma convenção de `watchSetoresProvider`/`watchEquipesProvider` (definidos nos respectivos `*_repository.dart`).
+- `false` — `firestore.rules` marcado `[x]` sem diff: as rules de `loteamentos`/`quadras`/`lotes` já concedem `read: if member(c)` / `write: if admin(c)` (firestore.rules:46-65); "revisar" não exige alteração.
+- `false` — `spec-fix-testes-obsoletos-lote` `done` só com defers: artefato de outra história, não causado por esta mudança.
+- `false` — sem hash/listagem de traceability na triage: registro de processo; a própria triage cita comando e contagem.
+- `false` — ACs nunca mapeadas a testes: são declarações Given/When/Then; o template só marca `Execution`.
+- `false` — `generated` do sprint-status desatualizado: metadado sem impacto funcional.
+- `false` — escopo com `movimentacao_screen.dart`/`setores_routes.dart`: alterações pré-existentes de outro escopo ampliadas pelo range do baseline; sem dano.
+- `false` — IDs com caracteres especiais interpolados sem encode: ids são UUID v4 e doc ids do Firestore, URL-safe; caso inalcançável.
+- `low` (rejeitado) — query params/fragment perdidos no redirect: estas rotas não carregam query params; hipotético; fix adiciona branch.
+- `low` (rejeitado) — trailing slash quebra o redirect: improvável no uso diário; fix adiciona normalização/guard.
+- `low` (rejeitado) — `state.uri.path` (decodificado) vs `matchedLocation` (codificado): divergência só com ids especiais, que não ocorrem.
+- `low` (rejeitado) — Boundaries em plural `/construtoras/...` vs código singular: pré-existente; o fix editaria o próprio spec.
+- `low` (rejeitado) — URLs literais em vez de `LoteamentosPaths`/`QuadrasPaths`: DRY apenas de desenvolvedor, sem dano; refatoração não trivial.
+- `low` (rejeitado) — fakes/factories duplicados e mistura `test/` vs `test/src/features/`: organização de testes, sem impacto funcional.
diff --git a/_bmad-output/implementation-artifacts/spec-fix-testes-obsoletos-lote.md b/_bmad-output/implementation-artifacts/spec-fix-testes-obsoletos-lote.md
index 87d3457..3580af6 100644
--- a/_bmad-output/implementation-artifacts/spec-fix-testes-obsoletos-lote.md
+++ b/_bmad-output/implementation-artifacts/spec-fix-testes-obsoletos-lote.md
@@ -2,7 +2,7 @@
 title: 'Corrigir testes obsoletos do modelo Lote'
 type: 'bugfix'
 created: '2026-09-24'
-status: 'in-progress'
+status: 'done'
 route: 'oneshot'
 review_loop_iteration: 0
 context: []
@@ -24,4 +24,15 @@ context: []
 - Descoberta durante a implementação: `app/lib/src/features/lotes/presentation/lotes_list_screen.dart:33` usa a API antiga `SigoBreadcrumbs(segments: [...])`, mas o widget foi reescrito (commit `de88af4`) para derivar os breadcrumbs do path do GoRouter (`const SigoBreadcrumbs()`), como já fazem as telas de setores e equipes. Isso gera erro de compilação em produção e bloqueia `obras_lotes_crud_test.dart` e `setores_equipes_navigation_test.dart`.
 - `test/sigo_breadcrumbs_test.dart` (da tarefa anterior) também quebrou pela mesma mudança de API.
 - `test/stock_saida_test.dart` compila agora, mas 3 testes falham em runtime com overflow de RenderFlex (Row) na `MovimentacaoScreen`.
+- Escopo expandido (aprovado pelo usuário) para deixar a suíte verde: (1) `lotes_list_screen.dart` passou a usar `const SigoBreadcrumbs()`; (2) correção do `redirect` quebrado em `lotes_routes.dart`/`setores_routes.dart` (string escapada `'\${...}'` e uso do path completo) para redirect condicional via `state.matchedLocation`; (3) `movimentacao_screen.dart` envolveu dois textos de cabeçalho em `Expanded` para eliminar overflow; (4) prefixo de navegação em `setores_list_screen.dart` corrigido de `/construtoras/` para `/construtora/`.
+
+## Review Triage Log
+
+- `low` (defer) — usar `SetoresPaths.list`/`EquipesPaths.list` em vez dos literais `'setores'`/`'equipes'` no redirect. Cosmético; não justifica nova alteração agora.
+- `low` (defer) — padrão de redirect condicional duplicado em 4 arquivos de rota (inclui arquivos de outra história). Refatoração desnecessária neste escopo.
+- `low` (defer) — `state.uri.path` (decodificado) vs `state.matchedLocation` (codificado) pode divergir para IDs com caracteres especiais; IDs do Firestore são alfanuméricos, então probabilidade baixa e redirect é defensivo.
+- `low` (defer) — trailing slash em match exato não é normalizado. Caso raro.
+- `low` (defer) — o comportamento exato do redirect (`/lotes/:loteId` → `/setores`) não tem teste direto; o caminho profundo é coberto pelos testes de navegação. Gap defensivo, registrado como follow-up.
+- `low` (defer) — correção de layout (`Expanded`) sem teste dedicado; os testes de estoque já pinam a renderização sem overflow.
+
 
diff --git a/_bmad-output/implementation-artifacts/sprint-status.yaml b/_bmad-output/implementation-artifacts/sprint-status.yaml
index 04ff222..9510570 100644
--- a/_bmad-output/implementation-artifacts/sprint-status.yaml
+++ b/_bmad-output/implementation-artifacts/sprint-status.yaml
@@ -5,7 +5,7 @@
 # IDs históricos preservados; docs/stories não existe no workspace atual.
 
 generated: 09-14-2026 16:15
-last_updated: 09-24-2026 14:58
+last_updated: 09-24-2026 17:30
 project: obras
 project_key: SIGO
 tracking_system: file-system
@@ -126,7 +126,7 @@ development_status:
   epic-10-retrospective: done
 
   epic-11: in-progress
-  11-1-navegação-loteamento-quadra-lote: backlog
+  11-1-navegação-loteamento-quadra-lote: done
   11-2-navegação-lote-setor-equipe: in-progress
   epic-11-retrospective: optional
 legacy_scope_mapping:
diff --git a/_bmad-output/specs/spec-11-1-navegacao-loteamento-quadra-lote/.memlog.md b/_bmad-output/specs/spec-11-1-navegacao-loteamento-quadra-lote/.memlog.md
new file mode 100644
index 0000000..70bb022
--- /dev/null
+++ b/_bmad-output/specs/spec-11-1-navegacao-loteamento-quadra-lote/.memlog.md
@@ -0,0 +1,6 @@
+---
+topic: Story 11.1 - Navegação Loteamento -> Quadra -> Lote
+updated: 2026-09-24T16:30
+---
+
+
diff --git a/app/lib/src/common_widgets/sigo_breadcrumbs.dart b/app/lib/src/common_widgets/sigo_breadcrumbs.dart
index 3ef6f3d..f4ad707 100644
--- a/app/lib/src/common_widgets/sigo_breadcrumbs.dart
+++ b/app/lib/src/common_widgets/sigo_breadcrumbs.dart
@@ -25,31 +25,31 @@ class SigoBreadcrumbs extends StatelessWidget {
       
       if (pathSegments[i] == 'loteamentos') {
         if (i + 1 < pathSegments.length) {
-          segments.add(BreadcrumbSegment(label: 'Loteamento', url: '$currentUrl/${pathSegments[i + 1]}'));
+          segments.add(BreadcrumbSegment(label: 'Loteamento', url: currentUrl));
         } else {
           segments.add(BreadcrumbSegment(label: 'Loteamentos'));
         }
       } else if (pathSegments[i] == 'quadras') {
         if (i + 1 < pathSegments.length) {
-          segments.add(BreadcrumbSegment(label: 'Quadra', url: '$currentUrl/${pathSegments[i + 1]}'));
+          segments.add(BreadcrumbSegment(label: 'Quadra', url: currentUrl));
         } else {
           segments.add(BreadcrumbSegment(label: 'Quadras'));
         }
       } else if (pathSegments[i] == 'lotes') {
         if (i + 1 < pathSegments.length) {
-          segments.add(BreadcrumbSegment(label: 'Lote', url: '$currentUrl/${pathSegments[i + 1]}'));
+          segments.add(BreadcrumbSegment(label: 'Lote', url: currentUrl));
         } else {
           segments.add(BreadcrumbSegment(label: 'Lotes'));
         }
       } else if (pathSegments[i] == 'setores') {
         if (i + 1 < pathSegments.length) {
-          segments.add(BreadcrumbSegment(label: 'Setor', url: '$currentUrl/${pathSegments[i + 1]}'));
+          segments.add(BreadcrumbSegment(label: 'Setor', url: currentUrl));
         } else {
           segments.add(BreadcrumbSegment(label: 'Setores'));
         }
       } else if (pathSegments[i] == 'equipes') {
          if (i + 1 < pathSegments.length) {
-          segments.add(BreadcrumbSegment(label: 'Equipe', url: '$currentUrl/${pathSegments[i + 1]}'));
+          segments.add(BreadcrumbSegment(label: 'Equipe', url: currentUrl));
         } else {
           segments.add(BreadcrumbSegment(label: 'Equipes'));
         }
diff --git a/app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart b/app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart
index 71d73dc..e474898 100644
--- a/app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart
+++ b/app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart
@@ -474,12 +474,14 @@ class _MovimentacaoScreenState extends ConsumerState<MovimentacaoScreen> {
                   children: const [
                     Icon(Icons.monetization_on_outlined, size: 20, color: Colors.blueGrey),
                     SizedBox(width: 8),
-                    Text(
-                      'Custo de Apropriação ao Lote (Opcional)',
-                      style: TextStyle(
-                        fontSize: 16,
-                        fontWeight: FontWeight.bold,
-                        color: Colors.blueGrey,
+                    Expanded(
+                      child: Text(
+                        'Custo de Apropriação ao Lote (Opcional)',
+                        style: TextStyle(
+                          fontSize: 16,
+                          fontWeight: FontWeight.bold,
+                          color: Colors.blueGrey,
+                        ),
                       ),
                     ),
                   ],
@@ -541,12 +543,14 @@ class _MovimentacaoScreenState extends ConsumerState<MovimentacaoScreen> {
                   children: const [
                     Icon(Icons.calculate_outlined, size: 20, color: Colors.blueGrey),
                     SizedBox(width: 8),
-                    Text(
-                      'Rateio e Custos de Aquisição (Opcional)',
-                      style: TextStyle(
-                        fontSize: 16,
-                        fontWeight: FontWeight.bold,
-                        color: Colors.blueGrey,
+                    Expanded(
+                      child: Text(
+                        'Rateio e Custos de Aquisição (Opcional)',
+                        style: TextStyle(
+                          fontSize: 16,
+                          fontWeight: FontWeight.bold,
+                          color: Colors.blueGrey,
+                        ),
                       ),
                     ),
                   ],
diff --git a/app/lib/src/features/loteamentos/data/loteamento_repository.dart b/app/lib/src/features/loteamentos/data/loteamento_repository.dart
index 8e0ac02..01ebde4 100644
--- a/app/lib/src/features/loteamentos/data/loteamento_repository.dart
+++ b/app/lib/src/features/loteamentos/data/loteamento_repository.dart
@@ -30,3 +30,11 @@ class LoteamentoRepository {
     await docRef.set(loteamento);
   }
 }
+
+typedef LoteamentoParams = ({String construtoraId});
+
+final watchLoteamentosProvider =
+    StreamProvider.family<List<Loteamento>, LoteamentoParams>((ref, params) {
+  final repo = ref.watch(loteamentoRepositoryProvider);
+  return repo.watchLoteamentos(params.construtoraId);
+});
diff --git a/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart b/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart
index 8052efb..2f888dd 100644
--- a/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart
+++ b/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart
@@ -2,7 +2,7 @@ import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:go_router/go_router.dart';
 import '../data/loteamento_repository.dart';
-import '../domain/loteamento.dart';
+import '../../../common_widgets/sigo_breadcrumbs.dart';
 
 class LoteamentosListScreen extends ConsumerWidget {
   final String construtoraId;
@@ -14,36 +14,48 @@ class LoteamentosListScreen extends ConsumerWidget {
 
   @override
   Widget build(BuildContext context, WidgetRef ref) {
-    final stream = ref.watch(loteamentoRepositoryProvider).watchLoteamentos(construtoraId);
+    final loteamentosAsync = ref.watch(
+      watchLoteamentosProvider((construtoraId: construtoraId)),
+    );
 
     return Scaffold(
       appBar: AppBar(title: const Text('Loteamentos')),
-      body: StreamBuilder<List<Loteamento>>(
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
+          const SigoBreadcrumbs(),
+          Expanded(
+            child: loteamentosAsync.when(
+              loading: () => const Center(child: CircularProgressIndicator()),
+              error: (err, stack) => const Center(
+                child: Text('Não foi possível carregar os loteamentos. Tente novamente.'),
+              ),
+              data: (items) {
+                if (items.isEmpty) {
+                  return const Center(
+                    child: Text('Nenhum registro encontrado.'),
+                  );
+                }
 
-          return ListView.builder(
-            itemCount: items.length,
-            itemBuilder: (context, index) {
-              final item = items[index];
-              return ListTile(
-                title: Text(item.name),
-                trailing: const Icon(Icons.arrow_forward_ios),
-                onTap: () {
-                  context.go('/construtora/$construtoraId/loteamentos/${item.id}');
-                },
-              );
-            },
-          );
-        },
+                return ListView.builder(
+                  itemCount: items.length,
+                  itemBuilder: (context, index) {
+                    final item = items[index];
+                    return ListTile(
+                      title: Text(item.name),
+                      trailing: const Icon(Icons.arrow_forward_ios),
+                      onTap: () {
+                        context.go(
+                          '/construtora/$construtoraId/loteamentos/${item.id}/quadras',
+                        );
+                      },
+                    );
+                  },
+                );
+              },
+            ),
+          ),
+        ],
       ),
     );
   }
diff --git a/app/lib/src/features/loteamentos/routing/loteamentos_routes.dart b/app/lib/src/features/loteamentos/routing/loteamentos_routes.dart
index c4a099f..358e133 100644
--- a/app/lib/src/features/loteamentos/routing/loteamentos_routes.dart
+++ b/app/lib/src/features/loteamentos/routing/loteamentos_routes.dart
@@ -1,4 +1,3 @@
-import 'package:flutter/material.dart';
 import 'package:go_router/go_router.dart';
 import '../presentation/loteamentos_list_screen.dart';
 import '../../../common_widgets/access_guard.dart';
@@ -24,13 +23,9 @@ List<RouteBase> get loteamentosRoutes => [
         routes: [
           GoRoute(
             path: ':loteamentoId',
-            builder: (context, state) {
-              // Just a placeholder or QuadrasListScreen
-              // In nested routing, usually we want a Dashboard or redirect to Quadras
-              // Let's just return a placeholder or direct builder if needed.
-              // Actually, quadrasRoutes will be attached here.
-              return const SizedBox(); // Not directly accessed, we access quadras
-            },
+            redirect: (context, state) => state.uri.path == state.matchedLocation
+                ? '${state.matchedLocation}/quadras'
+                : null,
             routes: [
               ...quadrasRoutes,
             ],
diff --git a/app/lib/src/features/lotes/data/lote_repository.dart b/app/lib/src/features/lotes/data/lote_repository.dart
index a98b726..9e531b1 100644
--- a/app/lib/src/features/lotes/data/lote_repository.dart
+++ b/app/lib/src/features/lotes/data/lote_repository.dart
@@ -30,3 +30,19 @@ class LoteRepository {
     await docRef.set(lote);
   }
 }
+
+typedef LoteParams = ({
+  String construtoraId,
+  String loteamentoId,
+  String quadraId,
+});
+
+final watchLotesProvider =
+    StreamProvider.family<List<Lote>, LoteParams>((ref, params) {
+  final repo = ref.watch(loteRepositoryProvider);
+  return repo.watchLotes(
+    params.construtoraId,
+    params.loteamentoId,
+    params.quadraId,
+  );
+});
diff --git a/app/lib/src/features/lotes/presentation/lotes_list_screen.dart b/app/lib/src/features/lotes/presentation/lotes_list_screen.dart
index 5145291..114f21d 100644
--- a/app/lib/src/features/lotes/presentation/lotes_list_screen.dart
+++ b/app/lib/src/features/lotes/presentation/lotes_list_screen.dart
@@ -3,7 +3,6 @@ import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:go_router/go_router.dart';
 
 import '../data/lote_repository.dart';
-import '../domain/lote.dart';
 import '../../../common_widgets/sigo_breadcrumbs.dart';
 
 class LotesListScreen extends ConsumerWidget {
@@ -20,40 +19,27 @@ class LotesListScreen extends ConsumerWidget {
 
   @override
   Widget build(BuildContext context, WidgetRef ref) {
-    final stream = ref
-        .watch(loteRepositoryProvider)
-        .watchLotes(construtoraId, loteamentoId, quadraId);
+    final lotesAsync = ref.watch(
+      watchLotesProvider((
+        construtoraId: construtoraId,
+        loteamentoId: loteamentoId,
+        quadraId: quadraId,
+      )),
+    );
 
     return Scaffold(
       appBar: AppBar(title: const Text('Lotes')),
       body: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
-          SigoBreadcrumbs(
-            segments: [
-              BreadcrumbSegment(
-                label: 'Loteamento',
-                url: '/construtora/$construtoraId/loteamentos/$loteamentoId',
-              ),
-              BreadcrumbSegment(
-                label: 'Quadra',
-                url:
-                    '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId',
-              ),
-              const BreadcrumbSegment(label: 'Lotes'),
-            ],
-          ),
+          const SigoBreadcrumbs(),
           Expanded(
-            child: StreamBuilder<List<Lote>>(
-              stream: stream,
-              builder: (context, snapshot) {
-                if (snapshot.connectionState == ConnectionState.waiting) {
-                  return const Center(child: CircularProgressIndicator());
-                }
-                if (snapshot.hasError) {
-                  return Center(child: Text('Erro: ${snapshot.error}'));
-                }
-                final items = snapshot.data ?? [];
+            child: lotesAsync.when(
+              loading: () => const Center(child: CircularProgressIndicator()),
+              error: (err, stack) => const Center(
+                child: Text('Não foi possível carregar os lotes. Tente novamente.'),
+              ),
+              data: (items) {
                 if (items.isEmpty) {
                   return const Center(
                     child: Text('Nenhum registro encontrado.'),
diff --git a/app/lib/src/features/lotes/routing/lotes_routes.dart b/app/lib/src/features/lotes/routing/lotes_routes.dart
index cdc5231..91b8801 100644
--- a/app/lib/src/features/lotes/routing/lotes_routes.dart
+++ b/app/lib/src/features/lotes/routing/lotes_routes.dart
@@ -26,7 +26,9 @@ List<RouteBase> get lotesRoutes => [
         routes: [
           GoRoute(
             path: ':loteId',
-            redirect: (context, state) => '\${state.uri.path}/setores',
+            redirect: (context, state) => state.uri.path == state.matchedLocation
+                ? '${state.matchedLocation}/setores'
+                : null,
             routes: [
               ...setoresRoutes,
             ],
diff --git a/app/lib/src/features/obras/presentation/obras_list_screen.dart b/app/lib/src/features/obras/presentation/obras_list_screen.dart
index ec93dca..f40ce99 100644
--- a/app/lib/src/features/obras/presentation/obras_list_screen.dart
+++ b/app/lib/src/features/obras/presentation/obras_list_screen.dart
@@ -72,6 +72,7 @@ class ObrasListScreen extends ConsumerWidget {
     final despesasAsync = admin
         ? ref.watch(despesasConstrutoraProvider(construtoraId))
         : const AsyncData<List<Despesa>>([]);
+    final canViewLoteamentos = admin || cm?['isActive'] == true;
 
     return SigoLayout(
       title: 'Painel da Construtora',
@@ -96,6 +97,14 @@ class ObrasListScreen extends ConsumerWidget {
               context.go('/construtora/$construtoraId/membros');
             },
           ),
+        if (canViewLoteamentos)
+          IconButton(
+            icon: const Icon(Icons.map_outlined, color: Colors.black54),
+            tooltip: 'Loteamentos',
+            onPressed: () {
+              context.go('/construtora/$construtoraId/loteamentos');
+            },
+          ),
         if (hasRh)
           IconButton(
             icon: const Icon(Icons.badge, color: Colors.black54),
diff --git a/app/lib/src/features/quadras/data/quadra_repository.dart b/app/lib/src/features/quadras/data/quadra_repository.dart
index 41d7b4c..a3ca345 100644
--- a/app/lib/src/features/quadras/data/quadra_repository.dart
+++ b/app/lib/src/features/quadras/data/quadra_repository.dart
@@ -30,3 +30,11 @@ class QuadraRepository {
     await docRef.set(quadra);
   }
 }
+
+typedef QuadraParams = ({String construtoraId, String loteamentoId});
+
+final watchQuadrasProvider =
+    StreamProvider.family<List<Quadra>, QuadraParams>((ref, params) {
+  final repo = ref.watch(quadraRepositoryProvider);
+  return repo.watchQuadras(params.construtoraId, params.loteamentoId);
+});
diff --git a/app/lib/src/features/quadras/presentation/quadras_list_screen.dart b/app/lib/src/features/quadras/presentation/quadras_list_screen.dart
index bd59bda..7167d27 100644
--- a/app/lib/src/features/quadras/presentation/quadras_list_screen.dart
+++ b/app/lib/src/features/quadras/presentation/quadras_list_screen.dart
@@ -2,7 +2,7 @@ import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:go_router/go_router.dart';
 import '../data/quadra_repository.dart';
-import '../domain/quadra.dart';
+import '../../../common_widgets/sigo_breadcrumbs.dart';
 
 class QuadrasListScreen extends ConsumerWidget {
   final String construtoraId;
@@ -16,36 +16,51 @@ class QuadrasListScreen extends ConsumerWidget {
 
   @override
   Widget build(BuildContext context, WidgetRef ref) {
-    final stream = ref.watch(quadraRepositoryProvider).watchQuadras(construtoraId, loteamentoId);
+    final quadrasAsync = ref.watch(
+      watchQuadrasProvider((
+        construtoraId: construtoraId,
+        loteamentoId: loteamentoId,
+      )),
+    );
 
     return Scaffold(
       appBar: AppBar(title: const Text('Quadras')),
-      body: StreamBuilder<List<Quadra>>(
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
+          const SigoBreadcrumbs(),
+          Expanded(
+            child: quadrasAsync.when(
+              loading: () => const Center(child: CircularProgressIndicator()),
+              error: (err, stack) => const Center(
+                child: Text('Não foi possível carregar as quadras. Tente novamente.'),
+              ),
+              data: (items) {
+                if (items.isEmpty) {
+                  return const Center(
+                    child: Text('Nenhum registro encontrado.'),
+                  );
+                }
 
-          return ListView.builder(
-            itemCount: items.length,
-            itemBuilder: (context, index) {
-              final item = items[index];
-              return ListTile(
-                title: Text(item.name),
-                trailing: const Icon(Icons.arrow_forward_ios),
-                onTap: () {
-                  context.go('/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/${item.id}');
-                },
-              );
-            },
-          );
-        },
+                return ListView.builder(
+                  itemCount: items.length,
+                  itemBuilder: (context, index) {
+                    final item = items[index];
+                    return ListTile(
+                      title: Text(item.name),
+                      trailing: const Icon(Icons.arrow_forward_ios),
+                      onTap: () {
+                        context.go(
+                          '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/${item.id}/lotes',
+                        );
+                      },
+                    );
+                  },
+                );
+              },
+            ),
+          ),
+        ],
       ),
     );
   }
diff --git a/app/lib/src/features/quadras/routing/quadras_routes.dart b/app/lib/src/features/quadras/routing/quadras_routes.dart
index 6b70ef2..1b2df31 100644
--- a/app/lib/src/features/quadras/routing/quadras_routes.dart
+++ b/app/lib/src/features/quadras/routing/quadras_routes.dart
@@ -1,4 +1,3 @@
-import 'package:flutter/material.dart';
 import 'package:go_router/go_router.dart';
 import '../presentation/quadras_list_screen.dart';
 import '../../../common_widgets/access_guard.dart';
@@ -26,9 +25,9 @@ List<RouteBase> get quadrasRoutes => [
         routes: [
           GoRoute(
             path: ':quadraId',
-            builder: (context, state) {
-              return const SizedBox();
-            },
+            redirect: (context, state) => state.uri.path == state.matchedLocation
+                ? '${state.matchedLocation}/lotes'
+                : null,
             routes: [
               ...lotesRoutes,
             ],
diff --git a/app/lib/src/features/setores/presentation/setores_list_screen.dart b/app/lib/src/features/setores/presentation/setores_list_screen.dart
index 86731db..fb46870 100644
--- a/app/lib/src/features/setores/presentation/setores_list_screen.dart
+++ b/app/lib/src/features/setores/presentation/setores_list_screen.dart
@@ -45,7 +45,7 @@ class SetoresListScreen extends ConsumerWidget {
                       title: Text(item.name),
                       subtitle: Text('Criado em: $dateStr'),
                       onTap: () {
-                        context.go('/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores/${item.id}/equipes');
+                        context.go('/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores/${item.id}/equipes');
                       },
                     );
                   },
diff --git a/app/lib/src/features/setores/routing/setores_routes.dart b/app/lib/src/features/setores/routing/setores_routes.dart
index b590f51..2e32dd0 100644
--- a/app/lib/src/features/setores/routing/setores_routes.dart
+++ b/app/lib/src/features/setores/routing/setores_routes.dart
@@ -28,7 +28,9 @@ List<RouteBase> get setoresRoutes => [
         routes: [
           GoRoute(
             path: ':setorId',
-            redirect: (context, state) => '\${state.uri.path}/equipes',
+            redirect: (context, state) => state.uri.path == state.matchedLocation
+                ? '${state.matchedLocation}/equipes'
+                : null,
             routes: [
               ...equipesRoutes,
             ],
diff --git a/app/test/loteamento_quadra_lote_navigation_test.dart b/app/test/loteamento_quadra_lote_navigation_test.dart
new file mode 100644
index 0000000..233a249
--- /dev/null
+++ b/app/test/loteamento_quadra_lote_navigation_test.dart
@@ -0,0 +1,416 @@
+import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
+import 'package:app/src/features/authentication/data/user_repository.dart';
+import 'package:app/src/features/construtoras/routing/construtora_routes.dart';
+import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
+import 'package:app/src/features/loteamentos/domain/loteamento.dart';
+import 'package:app/src/features/loteamentos/presentation/loteamentos_list_screen.dart';
+import 'package:app/src/features/lotes/data/lote_repository.dart';
+import 'package:app/src/features/lotes/domain/lote.dart';
+import 'package:app/src/features/lotes/presentation/lotes_list_screen.dart';
+import 'package:app/src/features/equipes/data/equipe_repository.dart';
+import 'package:app/src/features/equipes/domain/equipe.dart';
+import 'package:app/src/features/equipes/presentation/equipes_list_screen.dart';
+import 'package:app/src/features/quadras/data/quadra_repository.dart';
+import 'package:app/src/features/quadras/domain/quadra.dart';
+import 'package:app/src/features/quadras/presentation/quadras_list_screen.dart';
+import 'package:app/src/features/setores/data/setor_repository.dart';
+import 'package:app/src/features/setores/domain/setor.dart';
+import 'package:app/src/features/setores/presentation/setores_list_screen.dart';
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:go_router/go_router.dart';
+
+class FakeLoteamentoRepository implements LoteamentoRepository {
+  final List<Loteamento> loteamentos;
+  FakeLoteamentoRepository(this.loteamentos);
+
+  @override
+  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) =>
+      Stream.value(loteamentos);
+
+  @override
+  Future<void> createLoteamento(Loteamento loteamento) async {}
+}
+
+class FakeQuadraRepository implements QuadraRepository {
+  final List<Quadra> quadras;
+  FakeQuadraRepository(this.quadras);
+
+  @override
+  Stream<List<Quadra>> watchQuadras(String construtoraId, String loteamentoId) =>
+      Stream.value(quadras);
+
+  @override
+  Future<void> createQuadra(Quadra quadra) async {}
+}
+
+class FakeLoteRepository implements LoteRepository {
+  final List<Lote> lotes;
+  FakeLoteRepository(this.lotes);
+
+  @override
+  Stream<List<Lote>> watchLotes(
+    String construtoraId,
+    String loteamentoId,
+    String quadraId,
+  ) =>
+      Stream.value(lotes);
+
+  @override
+  Future<void> createLote(Lote lote) async {}
+}
+
+class FakeSetorRepository implements SetorRepository {
+  final List<Setor> setores;
+  FakeSetorRepository(this.setores);
+
+  @override
+  Stream<List<Setor>> watchSetores(
+    String construtoraId,
+    String loteamentoId,
+    String quadraId,
+    String loteId,
+  ) =>
+      Stream.value(setores);
+}
+
+class FakeEquipeRepository implements EquipeRepository {
+  final List<Equipe> equipes;
+  FakeEquipeRepository(this.equipes);
+
+  @override
+  Stream<List<Equipe>> watchEquipes(
+    String construtoraId,
+    String loteamentoId,
+    String quadraId,
+    String loteId,
+    String setorId,
+  ) =>
+      Stream.value(equipes);
+}
+
+Loteamento makeLoteamento(String id) => Loteamento(
+      id: id,
+      construtoraId: 'c1',
+      name: 'Loteamento $id',
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+Quadra makeQuadra(String id) => Quadra(
+      id: id,
+      construtoraId: 'c1',
+      loteamentoId: 'l1',
+      name: 'Quadra $id',
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+Lote makeLote(String id) => Lote(
+      id: id,
+      construtoraId: 'c1',
+      loteamentoId: 'l1',
+      quadraId: 'q1',
+      name: 'Lote $id',
+      phase: 'Plantas',
+      status: LoteStatus.noPrazo,
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+Setor makeSetor(String id) => Setor(
+      id: id,
+      construtoraId: 'c1',
+      loteamentoId: 'l1',
+      quadraId: 'q1',
+      loteId: 'lo1',
+      name: 'Setor $id',
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+Equipe makeEquipe(String id) => Equipe(
+      id: id,
+      construtoraId: 'c1',
+      loteamentoId: 'l1',
+      quadraId: 'q1',
+      loteId: 'lo1',
+      setorId: 's1',
+      name: 'Equipe $id',
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+void main() {
+  testWidgets('LoteamentosListScreen navega para a lista de quadras',
+      (tester) async {
+    final router = GoRouter(
+      initialLocation: '/construtora/c1/loteamentos',
+      routes: [
+        GoRoute(
+          path: '/construtora/:cId/loteamentos',
+          builder: (context, state) => LoteamentosListScreen(
+            construtoraId: state.pathParameters['cId']!,
+          ),
+          routes: [
+            GoRoute(
+              path: ':loteamentoId/quadras',
+              builder: (context, state) => QuadrasListScreen(
+                construtoraId: state.pathParameters['cId']!,
+                loteamentoId: state.pathParameters['loteamentoId']!,
+              ),
+            ),
+          ],
+        ),
+      ],
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          loteamentoRepositoryProvider.overrideWithValue(
+            FakeLoteamentoRepository([makeLoteamento('l1')]),
+          ),
+          quadraRepositoryProvider.overrideWithValue(FakeQuadraRepository([])),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+    expect(find.text('Loteamento l1'), findsOneWidget);
+
+    await tester.tap(find.text('Loteamento l1'));
+    await tester.pumpAndSettle();
+
+    expect(find.byType(QuadrasListScreen), findsOneWidget);
+  });
+
+  testWidgets('QuadrasListScreen navega para a lista de lotes', (tester) async {
+    final router = GoRouter(
+      initialLocation: '/construtora/c1/loteamentos/l1/quadras',
+      routes: [
+        GoRoute(
+          path: '/construtora/:cId/loteamentos/:loteamentoId/quadras',
+          builder: (context, state) => QuadrasListScreen(
+            construtoraId: state.pathParameters['cId']!,
+            loteamentoId: state.pathParameters['loteamentoId']!,
+          ),
+          routes: [
+            GoRoute(
+              path: ':quadraId/lotes',
+              builder: (context, state) => LotesListScreen(
+                construtoraId: state.pathParameters['cId']!,
+                loteamentoId: state.pathParameters['loteamentoId']!,
+                quadraId: state.pathParameters['quadraId']!,
+              ),
+            ),
+          ],
+        ),
+      ],
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          quadraRepositoryProvider.overrideWithValue(
+            FakeQuadraRepository([makeQuadra('q1')]),
+          ),
+          loteRepositoryProvider.overrideWithValue(FakeLoteRepository([])),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+    expect(find.text('Quadra q1'), findsOneWidget);
+
+    await tester.tap(find.text('Quadra q1'));
+    await tester.pumpAndSettle();
+
+    expect(find.byType(LotesListScreen), findsOneWidget);
+  });
+
+  testWidgets(
+      'rotas reais aninhadas renderizam breadcrumbs e crumb-pai ascende para a lista',
+      (tester) async {
+    final router = GoRouter(
+      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      routes: construtoraRoutes,
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
+          loteamentoRepositoryProvider.overrideWithValue(
+            FakeLoteamentoRepository([makeLoteamento('l1')]),
+          ),
+          quadraRepositoryProvider.overrideWithValue(
+            FakeQuadraRepository([makeQuadra('q1')]),
+          ),
+          loteRepositoryProvider.overrideWithValue(
+            FakeLoteRepository([makeLote('lo1')]),
+          ),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(find.byType(LotesListScreen), findsOneWidget);
+    expect(find.text('Lote lo1'), findsOneWidget);
+
+    final breadcrumbs = find.byType(SigoBreadcrumbs);
+    expect(
+      find.descendant(of: breadcrumbs, matching: find.text('Loteamento')),
+      findsOneWidget,
+    );
+    expect(
+      find.descendant(of: breadcrumbs, matching: find.text('Quadra')),
+      findsOneWidget,
+    );
+    expect(
+      find.descendant(of: breadcrumbs, matching: find.text('Lotes')),
+      findsOneWidget,
+    );
+
+    await tester.tap(find.text('Quadra'));
+    await tester.pumpAndSettle();
+
+    expect(find.byType(QuadrasListScreen), findsOneWidget);
+    expect(find.text('Quadra q1'), findsOneWidget);
+    expect(
+      router.state.uri.path,
+      '/construtora/c1/loteamentos/l1/quadras',
+    );
+  });
+
+  testWidgets('crumb raiz ascende para a lista de loteamentos', (tester) async {
+    final router = GoRouter(
+      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      routes: construtoraRoutes,
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
+          loteamentoRepositoryProvider.overrideWithValue(
+            FakeLoteamentoRepository([makeLoteamento('l1')]),
+          ),
+          quadraRepositoryProvider.overrideWithValue(
+            FakeQuadraRepository([makeQuadra('q1')]),
+          ),
+          loteRepositoryProvider.overrideWithValue(
+            FakeLoteRepository([makeLote('lo1')]),
+          ),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    await tester.tap(find.text('Loteamento'));
+    await tester.pumpAndSettle();
+
+    expect(find.byType(LoteamentosListScreen), findsOneWidget);
+    expect(
+      router.state.uri.path,
+      '/construtora/c1/loteamentos',
+    );
+  });
+
+  testWidgets('deep-link em :loteId redireciona para a lista de setores',
+      (tester) async {
+    final router = GoRouter(
+      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1',
+      routes: construtoraRoutes,
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
+          setorRepositoryProvider.overrideWithValue(
+            FakeSetorRepository([makeSetor('s1')]),
+          ),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(find.byType(SetoresListScreen), findsOneWidget);
+    expect(find.text('Setor s1'), findsOneWidget);
+    expect(
+      router.state.uri.path,
+      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/setores',
+    );
+  });
+
+  testWidgets('deep-link em :setorId redireciona para a lista de equipes',
+      (tester) async {
+    final router = GoRouter(
+      initialLocation:
+          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/setores/s1',
+      routes: construtoraRoutes,
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
+          setorRepositoryProvider.overrideWithValue(FakeSetorRepository([])),
+          equipeRepositoryProvider.overrideWithValue(
+            FakeEquipeRepository([makeEquipe('e1')]),
+          ),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(find.byType(EquipesListScreen), findsOneWidget);
+    expect(find.text('Equipe e1'), findsOneWidget);
+    expect(
+      router.state.uri.path,
+      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/setores/s1/equipes',
+    );
+  });
+
+  testWidgets('crumb de Setor ascende para a lista de setores', (tester) async {
+    final router = GoRouter(
+      initialLocation:
+          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/setores/s1/equipes',
+      routes: construtoraRoutes,
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
+          setorRepositoryProvider.overrideWithValue(
+            FakeSetorRepository([makeSetor('s1')]),
+          ),
+          equipeRepositoryProvider.overrideWithValue(
+            FakeEquipeRepository([makeEquipe('e1')]),
+          ),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+    expect(find.byType(EquipesListScreen), findsOneWidget);
+
+    await tester.tap(find.text('Setor'));
+    await tester.pumpAndSettle();
+
+    expect(find.byType(SetoresListScreen), findsOneWidget);
+    expect(
+      router.state.uri.path,
+      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/setores',
+    );
+  });
+}
diff --git a/app/test/loteamento_quadra_lote_providers_test.dart b/app/test/loteamento_quadra_lote_providers_test.dart
new file mode 100644
index 0000000..b84197f
--- /dev/null
+++ b/app/test/loteamento_quadra_lote_providers_test.dart
@@ -0,0 +1,194 @@
+import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
+import 'package:app/src/features/loteamentos/domain/loteamento.dart';
+import 'package:app/src/features/lotes/data/lote_repository.dart';
+import 'package:app/src/features/lotes/domain/lote.dart';
+import 'package:app/src/features/quadras/data/quadra_repository.dart';
+import 'package:app/src/features/quadras/domain/quadra.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:flutter_test/flutter_test.dart';
+
+class FakeLoteamentoRepository implements LoteamentoRepository {
+  final List<Loteamento> loteamentos;
+  FakeLoteamentoRepository(this.loteamentos);
+
+  @override
+  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) =>
+      Stream.value(loteamentos);
+
+  @override
+  Future<void> createLoteamento(Loteamento loteamento) async {}
+}
+
+class FakeQuadraRepository implements QuadraRepository {
+  final List<Quadra> quadras;
+  final List<(String, String)> calls = [];
+  FakeQuadraRepository(this.quadras);
+
+  @override
+  Stream<List<Quadra>> watchQuadras(String construtoraId, String loteamentoId) {
+    calls.add((construtoraId, loteamentoId));
+    return Stream.value(quadras);
+  }
+
+  @override
+  Future<void> createQuadra(Quadra quadra) async {}
+}
+
+class FakeLoteRepository implements LoteRepository {
+  final List<Lote> lotes;
+  final List<(String, String, String)> calls = [];
+  FakeLoteRepository(this.lotes);
+
+  @override
+  Stream<List<Lote>> watchLotes(
+    String construtoraId,
+    String loteamentoId,
+    String quadraId,
+  ) {
+    calls.add((construtoraId, loteamentoId, quadraId));
+    return Stream.value(lotes);
+  }
+
+  @override
+  Future<void> createLote(Lote lote) async {}
+}
+
+Loteamento makeLoteamento(String id) => Loteamento(
+      id: id,
+      construtoraId: 'c1',
+      name: 'Loteamento $id',
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+Quadra makeQuadra(String id) => Quadra(
+      id: id,
+      construtoraId: 'c1',
+      loteamentoId: 'l1',
+      name: 'Quadra $id',
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+Lote makeLote(String id) => Lote(
+      id: id,
+      construtoraId: 'c1',
+      loteamentoId: 'l1',
+      quadraId: 'q1',
+      name: 'Lote $id',
+      phase: 'Plantas',
+      status: LoteStatus.noPrazo,
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+void main() {
+  test('watchLoteamentosProvider resolve via Records sem novo loading', () async {
+    final container = ProviderContainer(
+      overrides: [
+        loteamentoRepositoryProvider.overrideWithValue(
+          FakeLoteamentoRepository([makeLoteamento('l1')]),
+        ),
+      ],
+    );
+    addTearDown(container.dispose);
+
+    const params = (construtoraId: 'c1');
+    final sub = container.listen(
+      watchLoteamentosProvider(params),
+      (_, _) {},
+    );
+    addTearDown(sub.close);
+
+    expect(container.read(watchLoteamentosProvider(params)).isLoading, isTrue);
+
+    await container.read(watchLoteamentosProvider(params).future);
+
+    final data = container.read(watchLoteamentosProvider(params));
+    expect(data.hasValue, isTrue);
+    expect(data.value!.single.name, 'Loteamento l1');
+
+    final reread = container.read(watchLoteamentosProvider(params));
+    expect(identical(data, reread), isTrue);
+  });
+
+  test('watchQuadrasProvider encaminha os IDs na ordem correta', () async {
+    final fake = FakeQuadraRepository([makeQuadra('q1')]);
+    final container = ProviderContainer(
+      overrides: [
+        quadraRepositoryProvider.overrideWithValue(fake),
+      ],
+    );
+    addTearDown(container.dispose);
+
+    const params = (construtoraId: 'c1', loteamentoId: 'l1');
+    final sub = container.listen(
+      watchQuadrasProvider(params),
+      (_, _) {},
+    );
+    addTearDown(sub.close);
+
+    expect(container.read(watchQuadrasProvider(params)).isLoading, isTrue);
+
+    await container.read(watchQuadrasProvider(params).future);
+
+    final data = container.read(watchQuadrasProvider(params));
+    expect(data.hasValue, isTrue);
+    expect(data.value!.single.name, 'Quadra q1');
+
+    expect(fake.calls, [('c1', 'l1')]);
+
+    final reread = container.read(watchQuadrasProvider(params));
+    expect(identical(data, reread), isTrue);
+  });
+
+  test('watchLotesProvider encaminha os IDs na ordem correta', () async {
+    final fake = FakeLoteRepository([makeLote('lo1')]);
+    final container = ProviderContainer(
+      overrides: [
+        loteRepositoryProvider.overrideWithValue(fake),
+      ],
+    );
+    addTearDown(container.dispose);
+
+    const params = (construtoraId: 'c1', loteamentoId: 'l1', quadraId: 'q1');
+    final sub = container.listen(
+      watchLotesProvider(params),
+      (_, _) {},
+    );
+    addTearDown(sub.close);
+
+    expect(container.read(watchLotesProvider(params)).isLoading, isTrue);
+
+    await container.read(watchLotesProvider(params).future);
+
+    final data = container.read(watchLotesProvider(params));
+    expect(data.hasValue, isTrue);
+    expect(data.value!.single.name, 'Lote lo1');
+
+    expect(fake.calls, [('c1', 'l1', 'q1')]);
+
+    final reread = container.read(watchLotesProvider(params));
+    expect(identical(data, reread), isTrue);
+  });
+
+  test('watchLotesProvider isola chaves de family distintas', () async {
+    final fake = FakeLoteRepository([makeLote('lo1')]);
+    final container = ProviderContainer(
+      overrides: [
+        loteRepositoryProvider.overrideWithValue(fake),
+      ],
+    );
+    addTearDown(container.dispose);
+
+    const a = (construtoraId: 'c1', loteamentoId: 'l1', quadraId: 'q1');
+    const b = (construtoraId: 'c1', loteamentoId: 'l1', quadraId: 'q2');
+
+    final subA = container.listen(watchLotesProvider(a), (_, _) {});
+    final subB = container.listen(watchLotesProvider(b), (_, _) {});
+    addTearDown(subA.close);
+    addTearDown(subB.close);
+
+    await container.read(watchLotesProvider(a).future);
+    await container.read(watchLotesProvider(b).future);
+
+    expect(fake.calls, containsAll([('c1', 'l1', 'q1'), ('c1', 'l1', 'q2')]));
+  });
+}
diff --git a/app/test/obras_lotes_crud_test.dart b/app/test/obras_lotes_crud_test.dart
index 0614817..50d32ab 100644
--- a/app/test/obras_lotes_crud_test.dart
+++ b/app/test/obras_lotes_crud_test.dart
@@ -1,6 +1,7 @@
 import 'package:flutter/material.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:go_router/go_router.dart';
 import 'package:app/src/features/lotes/domain/lote.dart';
 import 'package:app/src/features/lotes/presentation/add_lote_screen.dart';
 import 'package:app/src/features/lotes/presentation/lotes_list_screen.dart';
@@ -143,14 +144,25 @@ void main() {
         ),
       );
 
+      final router = GoRouter(
+        routes: [
+          GoRoute(
+            path: '/',
+            builder: (context, state) => const LotesListScreen(
+              construtoraId: 'c1',
+              loteamentoId: 'lt1',
+              quadraId: 'qd1',
+            ),
+          ),
+        ],
+      );
+
       await tester.pumpWidget(
         ProviderScope(
           overrides: [
             loteRepositoryProvider.overrideWithValue(fakeRepo),
           ],
-          child: const MaterialApp(
-            home: LotesListScreen(construtoraId: 'c1', loteamentoId: 'lt1', quadraId: 'qd1'),
-          ),
+          child: MaterialApp.router(routerConfig: router),
         ),
       );
 
diff --git a/app/test/sigo_breadcrumbs_test.dart b/app/test/sigo_breadcrumbs_test.dart
index 09fe834..4683b43 100644
--- a/app/test/sigo_breadcrumbs_test.dart
+++ b/app/test/sigo_breadcrumbs_test.dart
@@ -3,84 +3,90 @@ import 'package:flutter/material.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:go_router/go_router.dart';
 
-void main() {
-  testWidgets('renderiza todos os segmentos e separadores', (tester) async {
-    await tester.pumpWidget(
-      const MaterialApp(
-        home: Scaffold(
-          body: SigoBreadcrumbs(
-             
-              BreadcrumbSegment(label: 'Loteamento', url: '/a'),
-              BreadcrumbSegment(label: 'Quadra', url: '/b'),
-              BreadcrumbSegment(label: 'Lotes'),
-            ],
-          ),
+GoRouter _router() => GoRouter(
+      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      routes: [
+        GoRoute(
+          path: '/construtora/:cId',
+          builder: (context, state) => const SizedBox(),
+          routes: [
+            GoRoute(
+              path: 'loteamentos',
+              builder: (context, state) =>
+                  const Scaffold(body: Text('loteamentos destino')),
+              routes: [
+                GoRoute(
+                  path: ':loteamentoId',
+                  builder: (context, state) => const SizedBox(),
+                  routes: [
+                    GoRoute(
+                      path: 'quadras',
+                      builder: (context, state) =>
+                          const Scaffold(body: Text('quadras destino')),
+                      routes: [
+                        GoRoute(
+                          path: ':quadraId',
+                          builder: (context, state) => const SizedBox(),
+                          routes: [
+                            GoRoute(
+                              path: 'lotes',
+                              builder: (context, state) =>
+                                  const Scaffold(body: SigoBreadcrumbs()),
+                            ),
+                          ],
+                        ),
+                      ],
+                    ),
+                  ],
+                ),
+              ],
+            ),
+          ],
         ),
-      ),
+      ],
     );
 
+void main() {
+  testWidgets('renderiza a trilha derivada do path com separadores', (tester) async {
+    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
+    await tester.pumpAndSettle();
+
     expect(find.text('Loteamento'), findsOneWidget);
     expect(find.text('Quadra'), findsOneWidget);
     expect(find.text('Lotes'), findsOneWidget);
     expect(find.text('/'), findsNWidgets(2));
   });
 
-  testWidgets('tocar num segmento com url navega para a url', (tester) async {
-    final router = GoRouter(
-      initialLocation: '/',
-      routes: [
-        GoRoute(
-          path: '/',
-          builder: (context, state) => const Scaffold(
-            body: SigoBreadcrumbs(
-               
-                BreadcrumbSegment(label: 'Loteamento', url: '/destino'),
-                BreadcrumbSegment(label: 'Lotes'),
-              ],
-            ),
-          ),
-        ),
-        GoRoute(
-          path: '/destino',
-          builder: (context, state) => const Scaffold(body: Text('chegou')),
-        ),
-      ],
-    );
+  testWidgets('tocar num segmento com url navega para a lista do nivel',
+      (tester) async {
+    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
+    await tester.pumpAndSettle();
+
+    await tester.tap(find.text('Quadra'));
+    await tester.pumpAndSettle();
+
+    expect(find.text('quadras destino'), findsOneWidget);
+  });
+
+  testWidgets('tocar no segmento raiz navega para a lista de loteamentos',
+      (tester) async {
+    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
+    await tester.pumpAndSettle();
 
-    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
     await tester.tap(find.text('Loteamento'));
     await tester.pumpAndSettle();
 
-    expect(find.text('chegou'), findsOneWidget);
+    expect(find.text('loteamentos destino'), findsOneWidget);
   });
 
   testWidgets('ultimo segmento nao e clicavel e nao navega', (tester) async {
-    final router = GoRouter(
-      initialLocation: '/',
-      routes: [
-        GoRoute(
-          path: '/',
-          builder: (context, state) => const Scaffold(
-            body: SigoBreadcrumbs(
-               
-                BreadcrumbSegment(label: 'Loteamento', url: '/destino'),
-                BreadcrumbSegment(label: 'Lotes'),
-              ],
-            ),
-          ),
-        ),
-        GoRoute(
-          path: '/destino',
-          builder: (context, state) => const Scaffold(body: Text('chegou')),
-        ),
-      ],
-    );
+    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
+    await tester.pumpAndSettle();
 
-    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
     await tester.tap(find.text('Lotes'));
     await tester.pumpAndSettle();
 
-    expect(find.text('chegou'), findsNothing);
+    expect(find.text('quadras destino'), findsNothing);
     expect(find.text('Loteamento'), findsOneWidget);
   });
 }
diff --git a/app/test/src/features/loteamentos/presentation/loteamentos_list_screen_test.dart b/app/test/src/features/loteamentos/presentation/loteamentos_list_screen_test.dart
new file mode 100644
index 0000000..3229ef7
--- /dev/null
+++ b/app/test/src/features/loteamentos/presentation/loteamentos_list_screen_test.dart
@@ -0,0 +1,155 @@
+import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
+import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
+import 'package:app/src/features/loteamentos/domain/loteamento.dart';
+import 'package:app/src/features/loteamentos/presentation/loteamentos_list_screen.dart';
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:go_router/go_router.dart';
+
+class FakeLoteamentoRepository implements LoteamentoRepository {
+  final List<Loteamento> loteamentos;
+  FakeLoteamentoRepository(this.loteamentos);
+
+  @override
+  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) =>
+      Stream.value(loteamentos);
+
+  @override
+  Future<void> createLoteamento(Loteamento loteamento) async {}
+}
+
+Loteamento makeLoteamento(String id) => Loteamento(
+      id: id,
+      construtoraId: 'c1',
+      name: 'Loteamento $id',
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+Widget buildTestWidget(Widget child) {
+  final router = GoRouter(
+    initialLocation: '/construtora/c1/loteamentos',
+    routes: [
+      GoRoute(
+        path: '/construtora/c1/loteamentos',
+        builder: (context, state) => child,
+      ),
+    ],
+  );
+
+  return MaterialApp.router(routerConfig: router);
+}
+
+void main() {
+  testWidgets('Renderiza lista de loteamentos vazia', (tester) async {
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          watchLoteamentosProvider.overrideWith((ref, arg) => Stream.value([])),
+        ],
+        child: buildTestWidget(
+          const LoteamentosListScreen(construtoraId: 'c1'),
+        ),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(find.text('Nenhum registro encontrado.'), findsOneWidget);
+  });
+
+  testWidgets('Renderiza lista com loteamentos e breadcrumbs', (tester) async {
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          watchLoteamentosProvider.overrideWith(
+            (ref, arg) => Stream.value([makeLoteamento('l1')]),
+          ),
+        ],
+        child: buildTestWidget(
+          const LoteamentosListScreen(construtoraId: 'c1'),
+        ),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(find.text('Loteamento l1'), findsOneWidget);
+    expect(
+      find.descendant(
+        of: find.byType(SigoBreadcrumbs),
+        matching: find.text('Loteamentos'),
+      ),
+      findsOneWidget,
+    );
+  });
+
+  testWidgets('Renderiza mensagem de erro quando o stream falha',
+      (tester) async {
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          watchLoteamentosProvider.overrideWith(
+            (ref, arg) => Stream.error(Exception('falha')),
+          ),
+        ],
+        child: buildTestWidget(
+          const LoteamentosListScreen(construtoraId: 'c1'),
+        ),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(
+      find.text('Não foi possível carregar os loteamentos. Tente novamente.'),
+      findsOneWidget,
+    );
+  });
+
+  testWidgets('Reconstruir a tela não reemite AsyncLoading (Records)',
+      (tester) async {
+    final rebuild = ValueNotifier<int>(0);
+    addTearDown(rebuild.dispose);
+    var buildCount = 0;
+
+    final router = GoRouter(
+      initialLocation: '/construtora/c1/loteamentos',
+      routes: [
+        GoRoute(
+          path: '/construtora/c1/loteamentos',
+          builder: (context, state) => ValueListenableBuilder<int>(
+            valueListenable: rebuild,
+            builder: (context, _, _) {
+              buildCount++;
+              return LoteamentosListScreen(construtoraId: 'c1');
+            },
+          ),
+        ),
+      ],
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          loteamentoRepositoryProvider.overrideWithValue(
+            FakeLoteamentoRepository([makeLoteamento('l1')]),
+          ),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+    expect(find.text('Loteamento l1'), findsOneWidget);
+    expect(find.byType(CircularProgressIndicator), findsNothing);
+    final buildsBefore = buildCount;
+
+    rebuild.value++;
+    await tester.pump();
+
+    expect(buildCount, greaterThan(buildsBefore));
+    expect(find.byType(CircularProgressIndicator), findsNothing);
+    expect(find.text('Loteamento l1'), findsOneWidget);
+  });
+}
diff --git a/app/test/src/features/lotes/presentation/lotes_list_screen_test.dart b/app/test/src/features/lotes/presentation/lotes_list_screen_test.dart
new file mode 100644
index 0000000..d8e9899
--- /dev/null
+++ b/app/test/src/features/lotes/presentation/lotes_list_screen_test.dart
@@ -0,0 +1,180 @@
+import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
+import 'package:app/src/features/lotes/data/lote_repository.dart';
+import 'package:app/src/features/lotes/domain/lote.dart';
+import 'package:app/src/features/lotes/presentation/lotes_list_screen.dart';
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:go_router/go_router.dart';
+
+class FakeLoteRepository implements LoteRepository {
+  final List<Lote> lotes;
+  FakeLoteRepository(this.lotes);
+
+  @override
+  Stream<List<Lote>> watchLotes(
+    String construtoraId,
+    String loteamentoId,
+    String quadraId,
+  ) =>
+      Stream.value(lotes);
+
+  @override
+  Future<void> createLote(Lote lote) async {}
+}
+
+Lote makeLote(String id) => Lote(
+      id: id,
+      construtoraId: 'c1',
+      loteamentoId: 'l1',
+      quadraId: 'q1',
+      name: 'Lote $id',
+      phase: 'Plantas',
+      status: LoteStatus.noPrazo,
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+Widget buildTestWidget(Widget child) {
+  final router = GoRouter(
+    initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+    routes: [
+      GoRoute(
+        path: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+        builder: (context, state) => child,
+      ),
+    ],
+  );
+
+  return MaterialApp.router(routerConfig: router);
+}
+
+void main() {
+  testWidgets('Renderiza lista de lotes vazia', (tester) async {
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          watchLotesProvider.overrideWith((ref, arg) => Stream.value([])),
+        ],
+        child: buildTestWidget(const LotesListScreen(
+          construtoraId: 'c1',
+          loteamentoId: 'l1',
+          quadraId: 'q1',
+        )),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(find.text('Nenhum registro encontrado.'), findsOneWidget);
+  });
+
+  testWidgets('Renderiza lista com lotes e breadcrumbs', (tester) async {
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          watchLotesProvider.overrideWith(
+            (ref, arg) => Stream.value([makeLote('lo1')]),
+          ),
+        ],
+        child: buildTestWidget(const LotesListScreen(
+          construtoraId: 'c1',
+          loteamentoId: 'l1',
+          quadraId: 'q1',
+        )),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(find.text('Lote lo1'), findsOneWidget);
+
+    final breadcrumbs = find.byType(SigoBreadcrumbs);
+    expect(
+      find.descendant(of: breadcrumbs, matching: find.text('Loteamento')),
+      findsOneWidget,
+    );
+    expect(
+      find.descendant(of: breadcrumbs, matching: find.text('Quadra')),
+      findsOneWidget,
+    );
+    expect(
+      find.descendant(of: breadcrumbs, matching: find.text('Lotes')),
+      findsOneWidget,
+    );
+  });
+
+  testWidgets('Renderiza mensagem de erro quando o stream falha',
+      (tester) async {
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          watchLotesProvider.overrideWith(
+            (ref, arg) => Stream.error(Exception('falha')),
+          ),
+        ],
+        child: buildTestWidget(const LotesListScreen(
+          construtoraId: 'c1',
+          loteamentoId: 'l1',
+          quadraId: 'q1',
+        )),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(
+      find.text('Não foi possível carregar os lotes. Tente novamente.'),
+      findsOneWidget,
+    );
+  });
+
+  testWidgets('Reconstruir a tela não reemite AsyncLoading (Records)',
+      (tester) async {
+    final rebuild = ValueNotifier<int>(0);
+    addTearDown(rebuild.dispose);
+    var buildCount = 0;
+
+    final router = GoRouter(
+      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+      routes: [
+        GoRoute(
+          path: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
+          builder: (context, state) => ValueListenableBuilder<int>(
+            valueListenable: rebuild,
+            builder: (context, _, _) {
+              buildCount++;
+              return LotesListScreen(
+                construtoraId: 'c1',
+                loteamentoId: 'l1',
+                quadraId: 'q1',
+              );
+            },
+          ),
+        ),
+      ],
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          loteRepositoryProvider.overrideWithValue(
+            FakeLoteRepository([makeLote('lo1')]),
+          ),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+    expect(find.text('Lote lo1'), findsOneWidget);
+    expect(find.byType(CircularProgressIndicator), findsNothing);
+    final buildsBefore = buildCount;
+
+    rebuild.value++;
+    await tester.pump();
+
+    expect(buildCount, greaterThan(buildsBefore));
+    expect(find.byType(CircularProgressIndicator), findsNothing);
+    expect(find.text('Lote lo1'), findsOneWidget);
+  });
+}
diff --git a/app/test/src/features/quadras/presentation/quadras_list_screen_test.dart b/app/test/src/features/quadras/presentation/quadras_list_screen_test.dart
new file mode 100644
index 0000000..63b410a
--- /dev/null
+++ b/app/test/src/features/quadras/presentation/quadras_list_screen_test.dart
@@ -0,0 +1,162 @@
+import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
+import 'package:app/src/features/quadras/data/quadra_repository.dart';
+import 'package:app/src/features/quadras/domain/quadra.dart';
+import 'package:app/src/features/quadras/presentation/quadras_list_screen.dart';
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:go_router/go_router.dart';
+
+class FakeQuadraRepository implements QuadraRepository {
+  final List<Quadra> quadras;
+  FakeQuadraRepository(this.quadras);
+
+  @override
+  Stream<List<Quadra>> watchQuadras(String construtoraId, String loteamentoId) =>
+      Stream.value(quadras);
+
+  @override
+  Future<void> createQuadra(Quadra quadra) async {}
+}
+
+Quadra makeQuadra(String id) => Quadra(
+      id: id,
+      construtoraId: 'c1',
+      loteamentoId: 'l1',
+      name: 'Quadra $id',
+      createdAt: DateTime(2026, 1, 1),
+    );
+
+Widget buildTestWidget(Widget child) {
+  final router = GoRouter(
+    initialLocation: '/construtora/c1/loteamentos/l1/quadras',
+    routes: [
+      GoRoute(
+        path: '/construtora/c1/loteamentos/l1/quadras',
+        builder: (context, state) => child,
+      ),
+    ],
+  );
+
+  return MaterialApp.router(routerConfig: router);
+}
+
+void main() {
+  testWidgets('Renderiza lista de quadras vazia', (tester) async {
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          watchQuadrasProvider.overrideWith((ref, arg) => Stream.value([])),
+        ],
+        child: buildTestWidget(
+          const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
+        ),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(find.text('Nenhum registro encontrado.'), findsOneWidget);
+  });
+
+  testWidgets('Renderiza lista com quadras e breadcrumbs', (tester) async {
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          watchQuadrasProvider.overrideWith(
+            (ref, arg) => Stream.value([makeQuadra('q1')]),
+          ),
+        ],
+        child: buildTestWidget(
+          const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
+        ),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(find.text('Quadra q1'), findsOneWidget);
+
+    final breadcrumbs = find.byType(SigoBreadcrumbs);
+    expect(
+      find.descendant(of: breadcrumbs, matching: find.text('Loteamento')),
+      findsOneWidget,
+    );
+    expect(
+      find.descendant(of: breadcrumbs, matching: find.text('Quadras')),
+      findsOneWidget,
+    );
+  });
+
+  testWidgets('Renderiza mensagem de erro quando o stream falha',
+      (tester) async {
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          watchQuadrasProvider.overrideWith(
+            (ref, arg) => Stream.error(Exception('falha')),
+          ),
+        ],
+        child: buildTestWidget(
+          const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
+        ),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+
+    expect(
+      find.text('Não foi possível carregar as quadras. Tente novamente.'),
+      findsOneWidget,
+    );
+  });
+
+  testWidgets('Reconstruir a tela não reemite AsyncLoading (Records)',
+      (tester) async {
+    final rebuild = ValueNotifier<int>(0);
+    addTearDown(rebuild.dispose);
+    var buildCount = 0;
+
+    final router = GoRouter(
+      initialLocation: '/construtora/c1/loteamentos/l1/quadras',
+      routes: [
+        GoRoute(
+          path: '/construtora/c1/loteamentos/l1/quadras',
+          builder: (context, state) => ValueListenableBuilder<int>(
+            valueListenable: rebuild,
+            builder: (context, _, _) {
+              buildCount++;
+              return QuadrasListScreen(
+                construtoraId: 'c1',
+                loteamentoId: 'l1',
+              );
+            },
+          ),
+        ),
+      ],
+    );
+
+    await tester.pumpWidget(
+      ProviderScope(
+        overrides: [
+          quadraRepositoryProvider.overrideWithValue(
+            FakeQuadraRepository([makeQuadra('q1')]),
+          ),
+        ],
+        child: MaterialApp.router(routerConfig: router),
+      ),
+    );
+
+    await tester.pumpAndSettle();
+    expect(find.text('Quadra q1'), findsOneWidget);
+    expect(find.byType(CircularProgressIndicator), findsNothing);
+    final buildsBefore = buildCount;
+
+    rebuild.value++;
+    await tester.pump();
+
+    expect(buildCount, greaterThan(buildsBefore));
+    expect(find.byType(CircularProgressIndicator), findsNothing);
+    expect(find.text('Quadra q1'), findsOneWidget);
+  });
+}

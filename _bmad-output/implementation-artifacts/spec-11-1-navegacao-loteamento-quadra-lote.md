---
title: 'Story 11.1 - Navegação Loteamento → Quadra → Lote'
type: 'feature'
created: '2026-09-24'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '068978981139fb56dca53c42456792da7fa71458'
context: ['_bmad-output/implementation-artifacts/epic-11-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O sistema precisa de uma fundação sólida para a navegação estrutural baseada em Loteamentos, Quadras e Lotes (os três primeiros níveis da hierarquia de 5 níveis). Como o dashboard atual não suporta esse drill-down completo e otimizado de forma aninhada, os usuários não conseguem visualizar a organização básica das obras.

**Approach:** Criar as rotas aninhadas para `loteamentos`, `quadras` e `lotes` utilizando o GoRouter. Implementar as telas de listagem para cada um desses níveis, replicando a estrutura de navegação e os componentes genéricos construídos na Story 11.2 (como o `SigoBreadcrumbs`). O gerenciamento de estado nas listagens deve utilizar Records nos providers do Riverpod para a passagem de múltiplos IDs, evitando assim o loop contínuo de `AsyncLoading` durante o rebuild.

## Boundaries & Constraints

**Always:** 
- O estado da navegação deve ser mantido na URL (path parameters) seguindo a hierarquia `/construtoras/:cId/loteamentos/:lId/quadras/:qId/lotes/:loId`.
- Reutilizar o componente genérico `SigoBreadcrumbs` implementado na Story 11.2 para permitir o retorno rápido aos níveis superiores da hierarquia de forma consistente.
- Utilizar Records no Riverpod (ex.: family com `({String loteamentoId, String quadraId})`) ao criar os Streams de listagem para evitar loops de carregamento ou múltiplas subscrições que geram piscar na interface (`AsyncLoading`).
- Testes automatizados (unitários/widget) devem cobrir a lógica de rotas, a listagem e os breadcrumbs, garantindo a mesma cobertura e qualidade alcançadas na Story 11.2.

**Never:** 
- Não usar estado em memória (como provedores estáticos ou globais separados) para gerenciar o ID atual da rota. O GoRouter/URL deve ser a fonte da verdade.

**Decisions:**
- O escopo desta história foca em UI, roteamento com GoRouter e gerenciamento de estado das listagens com Riverpod + Records. 
- A camada do Firestore para as entidades de loteamento, quadra e lote deve ser conectada de forma alinhada à subcoleção, e as regras de segurança correspondentes (`firestore.rules`) devem ser revisadas ou criadas caso falte o suporte de leitura ao respectivo nó.

</frozen-after-approval>

## Code Map

- `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart` -- Definição das rotas de nível 1.
- `app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart` -- Tela de listagem de loteamentos.
- `app/lib/src/features/quadras/routing/quadras_routes.dart` -- Definição das rotas de nível 2.
- `app/lib/src/features/quadras/presentation/quadras_list_screen.dart` -- Tela de listagem de quadras de um loteamento.
- `app/lib/src/features/lotes/routing/lotes_routes.dart` -- Integração e atualização das rotas de nível 3 para funcionar como filha de Quadra e pai de Setores (Story 11.2).
- `app/lib/src/features/lotes/presentation/lotes_list_screen.dart` -- Atualização/Criação da tela de listagem de lotes utilizando Records no Riverpod.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart` -- Criar módulo de rotas para Loteamentos (como child da rota de construtora).
- [x] `app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart` -- Implementar tela base incluindo o `SigoBreadcrumbs` e listagem baseada em StreamProvider.
- [x] `app/lib/src/features/quadras/routing/quadras_routes.dart` -- Criar módulo de rotas para Quadras aninhado em `:loteamentoId`.
- [x] `app/lib/src/features/quadras/presentation/quadras_list_screen.dart` -- Implementar tela de listagem de Quadras utilizando Records no Riverpod e breadcrumbs dinâmicos.
- [x] `app/lib/src/features/lotes/routing/lotes_routes.dart` -- Refatorar as rotas de lotes para serem filhas de `:quadraId`, mantendo integridade com as rotas descendentes (Setor e Equipe construídos na 11.2).
- [x] `app/lib/src/features/lotes/presentation/lotes_list_screen.dart` -- Refatorar tela de listagem de Lotes, usando `SigoBreadcrumbs` e Records nos provedores Riverpod para prevenir loops de `AsyncLoading`.
- [x] `firestore.rules` -- Revisar security rules para as subcoleções `loteamentos`, `quadras` e `lotes`, preservando o isolamento de segurança baseado na Construtora/Nó.
- [x] `app/test/` -- Adicionar testes automatizados cobrindo os providers Riverpod de listagem (verificando Records vs AsyncLoading) e garantindo correta geração dos breadcrumbs e rotas.

**Acceptance Criteria:**
- Given que um usuário acessou o dashboard de uma construtora, when ele abrir Loteamentos, then a URL deve espelhar a rota de loteamento e a `LoteamentosListScreen` renderiza seus breadcrumbs correspondentes.
- Given que um usuário acessa a tela de Lotes, when a tela é visualizada, then o estado carrega corretamente os itens via Riverpod usando Records e a interface não apresenta transições desnecessárias de loading (piscar de AsyncLoading).
- Given que o usuário clica em "Quadra X" no breadcrumb na tela de Lotes, then a navegação ascende para a rota correta da listagem de lotes mantendo os IDs pais intocados na URL.

## Verification

**Commands:**
- `flutter analyze` -- expected: Sem problemas nos arquivos de roteamento e nas novas listagens com Records.
- `flutter test` -- expected: Cobertura dos provedores refatorados e dos fluxos de breadcrumbs.

## Review Triage Log

- `false` — firestore.rules marcado `[x]` sem diff: as rules de `loteamentos`/`quadras`/`lotes` já concedem `read: if member(c)` e `write: if admin(c)` (firestore.rules:46-65); "revisar" não exige alteração e o isolamento por construtora está preservado.
- `false` — ACs "sem marcação": são declarações Given/When/Then, não checkboxes; o template só marca `Execution`.
- `false` — `review_loop_iteration` não incrementado: a iteração só sobe antes de um loopback, não na primeira passada de review.
- `false` — sprint-status `in-progress` vs frontmatter `in-review`: o ciclo do sprint-status mapeia para `review` apenas na conclusão (step-05); `in-progress` durante o review é esperado.
- `false` — `spec-fix-testes-obsoletos-lote` `done` só com defers, e notas não verificáveis no diff: artefato de outra história; não causado por esta mudança.
- `false` — diff inclui edições de outra história (`setores_routes.dart`, `movimentacao_screen.dart`): alterações pré-existentes/não commitadas de outro escopo, ampliadas pelo range do baseline; sem dano.
- `false` — "nenhum teste cobre os redirects entregues": os redirects `:loteamentoId→/quadras` e `:quadraId→/lotes` SÃO exercitados pelos testes que usam `construtoraRoutes` (neutralizá-los quebra a suíte). O caso `:loteId/:setorId` está tratado à parte (ver `medium` do verification-gap).
- `false` — "ramo condicional `null` do redirect sem teste": o ramo `uri.path != matchedLocation` é exercitado pelos testes de deep path em `construtoraRoutes`.
- `false` — "mensagem de erro fixa remove detalhe": segue o padrão das telas da 11.2; ocultar erro bruto do usuário é intencional, não regressão.
- `false` — "dependência 11.1/11.2 não reconciliada" e "sem contrato documentado de labels dos breadcrumbs": processo/documentação; a dependência já consta no `epic-11-context` e o widget deriva labels do path, com testes fixando o comportamento.
- `false` — "Verification sem evidência observada": `flutter analyze` (limpo) e `flutter test` (459 verdes) foram executados; o fix editaria o próprio spec do build (rejeitado por regra).
- `false` — "id cru com `?`/`#`/`/` interpolado na URL": os ids são UUID v4 (`add_lote_screen.dart:32`) e doc ids do Firestore, URL-safe; caso inalcançável.
- `medium` (blind-hunter + verification-gap, mesmo root cause) — testes de "rebuild sem AsyncLoading" não comprovam a propriedade: em `loteamentos_list_screen_test.dart` o `child:` `const` faz `Element.updateChild` curto-circuitar e a tela NÃO é reconstruída, então o teste passa independentemente; os testes de provider só checam `identical` (cache normal do Riverpod). Patch.
- `medium` (verification-gap) — redirects `:loteId→/setores` e `:setorId→/equipes` sem teste: comprovado que neutralizá-los mantém a suíte relacionada verde. Patch.
- `low` → defer — "Boundaries em plural `/construtoras/...` vs código singular `/construtora/`": divergência de documentação, mas o singular é a convenção de todo o app (`ConstrutoraPaths.detail`); navegação funciona; pré-existente.
- `low` → defer — ramos `error`/`loading` das listagens sem teste: lacuna de cobertura, sem defeito demonstrado.
- `low` → defer — `family` sem `autoDispose` acumula subscriptions do Firestore: padrão já usado por setores/equipes; `autoDispose` reintroduziria o `AsyncLoading` que a história quer evitar; decisão de design a revisitar.
- `low` → rejeitado — trailing slash quebra o redirect: improvável no uso diário e o fix adiciona normalização/guard (custo > correção direta).
- `low` → rejeitado — URLs literais em vez de `LoteamentosPaths`/`QuadrasPaths`: DRY apenas de desenvolvedor, sem dano ao usuário e refatoração não trivial.
- `low` → rejeitado — query params perdidos no redirect: estas rotas não carregam query params; hipotético.
- `low` → rejeitado — fakes/factories duplicados entre arquivos de teste e mistura `test/` vs `test/src/features/`: organização de testes, sem impacto funcional.

### Review Findings

#### Decision

- [x] [Review][Decision] AC1 sem ponto de entrada no dashboard — `LoteamentosListScreen` existe, mas `ObrasListScreen` não expõe nenhuma ação/atalho para `/construtora/:cId/loteamentos` (actions só cobrem obras/membros/rh/almoxarifado/financeiro/validacao/epis/fornecedores). O fluxo do AC1 ("abrir Loteamentos" a partir do dashboard) só é alcançável por URL manual/deep-link. Definir se adiciona entrada e qual permissão a gateia, ou se a AC deve ser lida como deep-link. [app/lib/src/features/obras/presentation/obras_list_screen.dart:79-150]
- [x] [Review][Decision] Segmento-pai do breadcrumb não ascende — em `/.../quadras/q1/lotes`, o crumb "Quadra" aponta para `/.../quadras/q1`, que redireciona de volta para `/.../lotes` (mesma tela); só o crumb "Loteamento" sobe de nível. Definir se crumbs-pai devem apontar para a rota de listagem (`/.../quadras`) — mudança em `sigo_breadcrumbs.dart`, compartilhado com a 11.2. [app/lib/src/common_widgets/sigo_breadcrumbs.dart:34]

#### Patch

- [x] [Review][Patch] IDs encaminhados pelos providers não são verificados por teste — os fakes ignoram os argumentos (`Stream.value`), então trocar a ordem dos IDs em `quadra_repository.dart:39` / `lote_repository.dart:43-47` mantém a suíte verde e uma regressão de path do Firestore passa silenciosamente. Assertar os IDs recebidos e isolar chaves de `family` distintas. [app/test/loteamento_quadra_lote_providers_test.dart:1059]
- [x] [Review][Patch] Ramos de erro das 3 listagens sem teste — os callbacks `error:` só são exercitados por `Stream.value`; nenhum override com `AsyncError`/`Stream.error`. Adicionar um teste por tela assertando a mensagem fixa. [app/test/src/features/lotes/presentation/lotes_list_screen_test.dart:1311]

#### Defer

- [x] [Review][Defer] `StreamProvider.family` sem `autoDispose` acumula subscriptions do Firestore [app/lib/src/features/loteamentos/data/loteamento_repository.dart:36] — deferred: padrão pré-existente de setores/equipes; `autoDispose` reintroduziria o `AsyncLoading` que a história quer evitar; decisão de ciclo de vida a revisitar.

#### Rejected

- `false` — frontmatter `status: done` vs sprint-status `review`: trackers com propósitos distintos (autoria do spec vs tracking de sprint); `review` é o estado esperado durante o review; sem efeito de código.
- `false` — `review_loop_iteration` em 0: contador só sobe em loopback, não na primeira passada.
- `false` — testes de provider "só checam `identical`": o `identical` reflete o cache normal do Riverpod; a lacuna acionável é o mapeamento de IDs (item Patch acima).
- `false` — teste de "rebuild sem AsyncLoading" mede `buildCount` no wrapper, não na tela: o wrapper reconstrói um `LoteamentosListScreen` não-`const`, logo a tela é reconstruída e a ausência de `CircularProgressIndicator` é assertion válida (o defeito de `child:` `const` foi corrigido).
- `false` — "nenhum teste dirige transições lista→lista pelas rotas reais": o teste de breadcrumbs usa `construtoraRoutes` e navega Lotes→Quadras; os testes de item-tap usam routers que replicam os paths.
- `false` — redirects `:loteId`/`:setorId` "não exercitados": o tap no crumb "Lote"/"Setor" navega para a origem do redirect (`/lotes/:loteId`, `/setores/:setorId`), e remover o redirect quebraria esses testes.
- `false` — providers como `final` de topo na camada de dados: mesma convenção de `watchSetoresProvider`/`watchEquipesProvider` (definidos nos respectivos `*_repository.dart`).
- `false` — `firestore.rules` marcado `[x]` sem diff: as rules de `loteamentos`/`quadras`/`lotes` já concedem `read: if member(c)` / `write: if admin(c)` (firestore.rules:46-65); "revisar" não exige alteração.
- `false` — `spec-fix-testes-obsoletos-lote` `done` só com defers: artefato de outra história, não causado por esta mudança.
- `false` — sem hash/listagem de traceability na triage: registro de processo; a própria triage cita comando e contagem.
- `false` — ACs nunca mapeadas a testes: são declarações Given/When/Then; o template só marca `Execution`.
- `false` — `generated` do sprint-status desatualizado: metadado sem impacto funcional.
- `false` — escopo com `movimentacao_screen.dart`/`setores_routes.dart`: alterações pré-existentes de outro escopo ampliadas pelo range do baseline; sem dano.
- `false` — IDs com caracteres especiais interpolados sem encode: ids são UUID v4 e doc ids do Firestore, URL-safe; caso inalcançável.
- `low` (rejeitado) — query params/fragment perdidos no redirect: estas rotas não carregam query params; hipotético; fix adiciona branch.
- `low` (rejeitado) — trailing slash quebra o redirect: improvável no uso diário; fix adiciona normalização/guard.
- `low` (rejeitado) — `state.uri.path` (decodificado) vs `matchedLocation` (codificado): divergência só com ids especiais, que não ocorrem.
- `low` (rejeitado) — Boundaries em plural `/construtoras/...` vs código singular: pré-existente; o fix editaria o próprio spec.
- `low` (rejeitado) — URLs literais em vez de `LoteamentosPaths`/`QuadrasPaths`: DRY apenas de desenvolvedor, sem dano; refatoração não trivial.
- `low` (rejeitado) — fakes/factories duplicados e mistura `test/` vs `test/src/features/`: organização de testes, sem impacto funcional.

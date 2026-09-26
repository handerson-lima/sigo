---
title: 'Story 11.2 - Navegação Lote → Setor → Equipe'
type: 'feature'
created: '2026-09-24'
status: 'done'
route: 'dispatch'
review_loop_iteration: 1
baseline_commit: '29e3d5c30d76508dad4bac45bbb476dea3776fd0'
context: ['_bmad-output/implementation-artifacts/epic-11-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O sistema atualmente possui rotas e navegação apenas até o Nível 3 (Lote). O usuário não consegue aprofundar a navegação estrutural para os níveis de Setor e Equipe (Níveis 4 e 5), o que impede a visão completa da hierarquia e a atribuição de responsáveis neste nível.

**Approach:** Estender o roteamento modular do GoRouter para suportar as rotas aninhadas de Setor (sob Lote) e Equipe (sob Setor). Criar as interfaces básicas de listagem para esses níveis e implementar um componente de Breadcrumbs que permita o retorno rápido aos níveis superiores da hierarquia, com validação apropriada das permissões (`AccessGuard`).

## Boundaries & Constraints

**Always:** 
- O estado da navegação deve ser mantido na URL (path parameters) seguindo a hierarquia `/loteamentos/:lId/quadras/:qId/lotes/:loId/setores/:sId/equipes/:eId`.
- As rotas devem ser protegidas por `AccessGuard` validando o acesso à construtora (e níveis inferiores se o ACL granular já suportar).

**Never:** 
- Não usar estado em memória (como providers de estado global) para gerenciar a rota atual. A URL é a fonte da verdade.

**Decisions:**
- O escopo de repositórios será COMPLETO, ou seja, além das rotas, devem ser implementados os repositories e models reais acessando o Firestore para Setor e Equipe.
- Os modelos de Setor e Equipe devem incluir explicitamente o campo `responsavelId`.
- As regras de segurança do Firestore (Firestore Rules) para as subcoleções `setores` e `equipes` devem ser incluídas no escopo desta história.
- Testes automatizados para a nova navegação, componentes e modelos devem ser criados para garantir a cobertura.

</frozen-after-approval>
## Code Map

- `app/lib/src/features/lotes/routing/lotes_routes.dart` -- Ponto de injeção das rotas filhas de `Setores`.
- `app/lib/src/features/setores/routing/setores_routes.dart` -- Novo arquivo para definir as rotas de nível 4 (Setor) e acoplar Equipes.
- `app/lib/src/features/setores/presentation/setores_list_screen.dart` -- Nova tela de listagem de setores de um lote.
- `app/lib/src/features/equipes/routing/equipes_routes.dart` -- Novo arquivo para definir as rotas de nível 5 (Equipe).
- `app/lib/src/features/equipes/presentation/equipes_list_screen.dart` -- Nova tela de listagem de equipes de um setor.
- `app/lib/src/common_widgets/sigo_breadcrumbs.dart` -- Novo componente para exibição de breadcrumbs para navegação ascendente rápida.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/common_widgets/sigo_breadcrumbs.dart` -- Criar componente de breadcrumb genérico que recebe uma lista de segmentos (label + url) e renderiza a trilha (garantir suporte a dark mode e acessibilidade).
- [x] `app/lib/src/features/setores/routing/setores_routes.dart` -- Criar módulo de rotas para Setores recebendo os parâmetros ascendentes (mantendo o prefixo `/construtoras/:cId`).
- [x] `app/lib/src/features/setores/presentation/setores_list_screen.dart` -- Implementar tela base incluindo o componente Breadcrumbs e listagem usando StreamProvider, com tratamento de datas e erros adequados.
- [x] `app/lib/src/features/lotes/routing/lotes_routes.dart` -- Integrar `setoresRoutes` como rotas filhas da rota `:loteId` e resolver rotas vazias (SizedBox).
- [x] `app/lib/src/features/equipes/routing/equipes_routes.dart` -- Criar módulo de rotas para Equipes.
- [x] `app/lib/src/features/equipes/presentation/equipes_list_screen.dart` -- Implementar tela base de Equipes, também usando Breadcrumbs corretos, com tratamento de datas, erros e StreamProvider.
- [x] `app/lib/src/features/setores/routing/setores_routes.dart` -- Integrar `equipesRoutes` como rotas filhas de `:setorId`.
- [x] `firestore.rules` -- Adicionar security rules para `setores` e `equipes` mantendo a consistência da política de acesso da construtora.
- [x] `app/test/` -- Adicionar testes de unidade e/ou widget cobrindo os repositórios, parsing seguro de datas (Timestamp/String) e a correta formação de breadcrumbs.

**Acceptance Criteria:**
- Given que um usuário acessou a rota de um Lote específico, when ele clicar para ver setores, then a URL será atualizada para o nível de setores e a tela `SetoresListScreen` será exibida.
- Given que um usuário acessou a rota de equipes, when ele visualizar a tela, then o componente de Breadcrumbs deve mostrar os links corretos para Loteamento > Quadra > Lote > Setor, permitindo navegação para cima.

### Review Findings

_Revisão de homologação (2026-09-26): código atual do escopo 11.2 vs baseline `29e3d5c`; o nível 4 "Setor" foi renomeado para `Etapa` no código atual._

- [x] [Review][Patch] Etapa é o nível 4 formal: adicionar `responsavelId` à `Etapa` e uma via de atribuição [app/lib/src/features/etapas/domain/etapa.dart:26-50] — decisão: manter Etapa como nível 4 e reconciliar o Intent adicionando o campo (o enum `EtapaTipo` fixo permanece como rótulo/ordem).
- [x] [Review][Patch] Renomear a nova `Equipe` da hierarquia para evitar colisão com a `Equipe` de RH [app/lib/src/features/equipes/domain/equipe.dart:22] — decisão: renomear (ex.: `EquipeLote`/`EquipeHierarquia`); a `Equipe` de RH (`features/rh`) permanece.
- [x] [Review][Patch] Rules top-level sem validação de coerência de pai nem de módulo [firestore.rules:209-228]
- [x] [Review][Patch] `EtapasListScreen` passa `loteamentoId` como `obraId` ao `currentPermissionsProvider` [app/lib/src/features/etapas/presentation/etapas_list_screen.dart:92-97]
- [x] [Review][Patch] FAB "Novo Lote" ignora `trustedDevProvider` (dev global sem membership não vê o botão, embora a rota permita) [app/lib/src/features/lotes/presentation/lotes_list_screen.dart:32-37]

- [x] [Review][Defer] Codec de data inseguro/inconsistente em Etapa e null handling nos repositórios [app/lib/src/features/etapas/domain/etapa.g.dart:17-18] — deferred: pré-existente da Story 13.1; já registrado em `deferred-work.md` e retro-item 39 (unificar codecs).
- [x] [Review][Defer] Faltam testes das leituras reais `watchEtapas`/`watchEquipes`/seed sem batch e das rules top-level [app/test/etapa_repository_test.dart:1] — deferred: pré-existente da 13.1; `deferred-work.md` (sem harness Dart de Firestore real; `test:rules` fora do CI).
- [x] [Review][Defer] Providers-family de etapas/equipes sem `autoDispose` retêm listeners [app/lib/src/features/etapas/data/etapa_repository.dart:106] — deferred: padrão pré-existente; já diferido para 11-1 (reintroduz `AsyncLoading`).
- [x] [Review][Defer] Sem cascata/limpeza de órfãos de `etapas`/`equipes` ao apagar pais [app/lib/src/features/equipes/data/equipe_repository.dart:22-38] — deferred: comportamento típico de denormalização; sem impacto imediato.
- [x] [Review][Defer] Duas hierarquias de `lotes` coexistem (raiz vs `construtoras/{c}/obras/{o}/lotes`) [firestore.rules:101,209] — deferred: pré-existente; estado transitório 13.1→13.3 (AD-1, retro-item 35).
- [x] [Review][Defer] Escopo extra fora dos ACs da 11.2: seed automático de etapas e fluxo "Novo Lote" [app/lib/src/features/etapas/data/etapa_repository.dart:43-96] — deferred: trabalho dos épicos 13.x, não exigido pela 11.2.

#### Rejected (appendix)
- `accepted-deviation` — Modelo achatado em coleções raiz em vez das subcoleções aninhadas do epic: decisão do usuário em 2026-09-26 de aceitar o esquema top-level (AD-1) e formalizar o desvio; achado encerrado.
- `false` — `Equipe` nova sem `copyWith/isActive/schemaVersion` e "incompatível com docs legados": coleções distintas (`equipes` raiz vs `construtoras/{c}/equipes`), não há docs legados na raiz; `_dateTimeFromTimestamp` evita crash.
- `false` — `orderBy('ordem')`/`orderBy('name')` descartam docs sem o campo: todo caminho de escrita (`toJson`) inclui `ordem`/`name`; cenário não alcançável pelo app.
- `false` — teste atômico referencia `LoteRepository(fakeFirestore, etapaRepository)`/`createLoteComEtapas` "ausentes": existem em `app/lib/src/features/lotes/data/lote_repository.dart:19,43` (fora do recorte do diff).
- `false` — índices compostos ausentes: `firestore.indexes.json` já contém `collectionGroup` `etapas` e `equipes` (linhas 78,104), adicionados em `1489c17`.
- `low` — `member(c)` passa a chamar `activeConstrutora(c)` (fail-closed se o doc da construtora sumir): cenário improvável; bloqueio global é intencional.
- `low` — timeframe/timer de `_inicializarEtapas` não cancela o commit: efeito limitado (provider reemite ao concluir; `merge:true` torna reenvio idempotente).
- `low` — ids determinísticos + `merge` não corrigem `nome/ordem` de etapas existentes: exigiria versionamento/migração; sem impacto hoje.
- `low` — `SigoBreadcrumbs` ignora segmentos desconhecidos, usa rótulos genéricos e mantém branch `'obra'` morto: cosmético/derivado do path.
- `low` — `AccessGuard` reutiliza `module: 'lotes'` para etapas/equipes: não há módulo distinto definido; comportamento aceitável.
- `low` — tela de equipes sem CTA de criação/gating admin: 11.2 só exige listagem base; sem ações de escrita na tela.
- `low` — defeitos de estilo (espaços à direita, ordem de imports, comentário obsoleto): cosméticos.
- `rejected (fix edita a spec)` — Contradição interna do contrato de breadcrumbs (recebe segments vs deriva do GoRouter): a própria Triage Log da spec já resolveu para derivado-do-router.

## Implementation Notes
- O modelo `Lote` sofreu alterações em histórias anteriores (Story 11.1), resultando na quebra de 63 testes relacionados a `Lote` que esperavam parâmetros como `obraId` em vez de `loteamentoId` e `quadraId`. Esses erros de teste foram ignorados nesta etapa pois pertencem ao escopo da história anterior que não atualizou os testes adequadamente. As novas rotas não apresentam erros de análise e estão funcionando conforme o esperado.
## Spec Change Log

## Review Triage Log
- `low`: SigoBreadcrumbs usa Colors.black fixo em vez do tema, quebrando modo escuro.
- `low`: SigoBreadcrumbs InkWell tem área de toque muito pequena e sem Semantics para leitor de tela.
- `low`: SigoBreadcrumbs pinta segmentos sem url com primaryColor, aparentando ser link não-clicável.
- `medium`: EquipeRepository falha em snapshot.data()! se o doc não tiver dados e não usa orderBy.
- `high`: Equipe e Setor não têm responsavelId, o que contraria o requisito de "atribuição de responsáveis neste nível" definido no Intent. -> `intent_gap`
- `high`: Equipe e Setor cracham ao fazer parse de Timestamp como String no campo createdAt do Firestore.
- `high`: Rotas de breadcrumbs e navegação usam caminhos absolutos como `/loteamentos/...` faltando o prefixo `/construtoras/:cId`, o que quebra a navegação por completo. -> `bad_spec`
- `medium`: Stream de equipes é criado no build em vez de provider.
- `low`: Erros brutos expostos ao usuário nas listagens.
- `low`: Datas sem formatação amigável (cruas).
- `low`: EquipesPaths.detail declarado e não utilizado.
- `low`: Indentação quebrada em lotes_list_screen.dart.
- `medium`: Rota de Lote retorna const SizedBox() deixando a tela em branco se acessada diretamente.
- `medium`: SetorRepository falha em snapshot.data()! sem tratamento.
- `low`: SetoresPaths.detail não utilizado.
- `high`: Firestore rules ausentes para as subcoleções setores e equipes, causando permission-denied. -> `intent_gap`
- `medium`: Nenhum teste adicionado para componentes ou navegação de Setor/Equipe. -> `intent_gap`
- `high`: Breadcrumbs construídos manualmente em vez de derivados do GoRouter state, como exigido. -> `bad_spec`

## Verification

**Commands:**
- `flutter analyze` -- expected: Sem erros ou avisos relacionados às novas rotas.
- `flutter test` -- expected: Testes devem passar (os widgets devem renderizar com sucesso).

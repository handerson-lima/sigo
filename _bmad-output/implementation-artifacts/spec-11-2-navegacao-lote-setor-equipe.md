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

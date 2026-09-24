---
title: 'Story 11.1 - Navegação Loteamento → Quadra → Lote'
type: 'feature'
created: '2026-09-24'
status: 'in-progress'
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

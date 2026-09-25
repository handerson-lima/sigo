---
title: 'Story 13.3 - Ramificação Específica de Etapas por Lote'
type: 'feature'
created: '2026-09-25'
status: 'in-progress'
baseline_commit: '9668da9'
route: 'dispatch'
review_loop_iteration: 0
context: ['_bmad-output/implementation-artifacts/epic-13-context.md', '_bmad-output/specs/spec-navegacao-loteamento-etapa/hierarquia-etapas.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Atualmente, a tela de listagem de Etapas de um Lote exibe uma lista vazia, mas a arquitetura exige que cada Lote possua uma hierarquia fixa de 5 etapas (Muro, Cinza/1ª, Cinza/2ª, Cinza/3ª, Branca/Acabamento). É necessário garantir que, ao acessar ou criar um Lote, essas 5 etapas estejam predefinidas e prontas para receber Equipes.

**Approach:** Modificar o fluxo de criação de Lote para inicializar automaticamente as 5 etapas padrão usando `EtapaRepository.createDefaultEtapas`. Na tela de listagem de Etapas, caso a lista ainda esteja vazia (ex: lotes pré-existentes), exibir um estado vazio com a opção explícita de inicializar as etapas manualmente, garantindo que o usuário possa ramificar a árvore do Lote conforme a hierarquia fixa.

## Boundaries & Constraints

**Always:**
- As etapas devem seguir estritamente o `EtapaTipo` (Muro, Cinza/1ª, Cinza/2ª, Cinza/3ª, Branca/Acabamento).
- A escrita (criação) deve ser feita em batch para garantir atomicidade.
- A criação de etapas deve ser limitada a administradores (`isAdmin`).

**Never:**
- Não permitir a criação de etapas customizadas ou avulsas (a hierarquia é estritamente fixa).
- Não excluir ou sobrepor etapas que já existam para o Lote.

**Decisions:**
- Lotes legados que não possuem etapas terão um botão "Inicializar Etapas" visível apenas para Administradores na tela `EtapasListScreen` vazia. Isso permite inicialização sob demanda controlada, evitando condições de corrida ou escritas excessivas não intencionais.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| NEW_LOTE | Usuário (Admin) cria um novo Lote | O sistema cria o Lote e as 5 etapas padrão no Firestore | SnackBar com mensagem de erro |
| LEGACY_LOTE | Acessa `EtapasListScreen` de um Lote sem etapas (antigo) | Exibe `SigoEmptyState` com botão "Inicializar Etapas" (apenas se Admin) | N/A |
| INIT_MANUAL | Usuário (Admin) clica em "Inicializar Etapas" | As 5 etapas são geradas e renderizadas na tela | SnackBar com erro |
| LIST_ETAPAS | Acessa `EtapasListScreen` de um Lote com etapas | Renderiza a lista ordenada (ordem 1..5) | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- Modificar `_submit()` para chamar `createDefaultEtapas` após criar o Lote.
- `app/lib/src/features/etapas/presentation/etapas_list_screen.dart` -- Adicionar o botão "Inicializar Etapas" no `SigoEmptyState` se `isAdmin` for true, para suportar lotes antigos. Adicionar estado de loading durante a inicialização.
- `app/lib/src/features/obras/presentation/current_permissions_provider.dart` -- Usado para verificar a role na tela de Etapas (assim como em `lotes_list_screen.dart`).

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- Na função `_submit()`, após `createLote(lote)`, adicionar chamada await para `ref.read(etapaRepositoryProvider).createDefaultEtapas(...)` -- Garante que todo novo Lote inicie com as 5 etapas padrão prontas.
- [ ] `app/lib/src/features/etapas/presentation/etapas_list_screen.dart` -- Ler a permissão do usuário (`construtoraPermissionProvider`) para obter `isAdmin`. No `SigoEmptyState`, adicionar o botão `ElevatedButton` com ação `ref.read(etapaRepositoryProvider).createDefaultEtapas(...)` caso `isAdmin` seja true -- Suporte para inicialização em lotes legados de dev.
- [ ] `app/lib/src/features/etapas/presentation/etapas_list_screen.dart` -- Converter para `ConsumerStatefulWidget` (ou adicionar `useState` se usar hooks) para ter uma variável de estado local `_isInitializing` que mostre um loading indicator no lugar do botão "Inicializar Etapas" -- UX feedback durante gravação em batch.

**Acceptance Criteria:**
- Given um Admin na tela de Novo Lote, when salvar o lote, then as 5 etapas pré-definidas também são criadas no banco de dados.
- Given um Lote sem etapas cadastradas, when um Admin acessa a tela de Etapas, then exibe um botão "Inicializar Etapas".
- Given a mesma tela, when o Admin clica em inicializar, then as etapas aparecem em ordem na lista (Muro a Acabamento).

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

A inicialização de etapas (`createDefaultEtapas`) foi implementada em 13.1 no repositório. O foco agora é integrá-la no momento da criação de um lote, garantindo atomicidade na visão de UX e retrocompatibilidade com lotes que possam ter sido criados sem etapas via botão explícito de inicialização.

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found!
- `flutter test` -- expected: All widget tests passing.

**Manual checks (if no CLI):**
- Criar novo Lote, navegar até suas Etapas e confirmar que as 5 já estão geradas e exibidas.
- (Usando um lote antigo vazio) Clicar em Inicializar Etapas e confirmar a criação instantânea.

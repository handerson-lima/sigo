---
title: 'Story 1.8 — Recálculo de Módulos e Layout Imediato na Troca de Obra'
type: 'feature'
created: '2026-09-16'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/docs/task.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Ao alternar de obra no SIGO ou navegar diretamente entre rotas de obras diferentes, o usuário precisa que os módulos disponíveis (e os elementos visuais de navegação na sidebar e no dashboard) sejam recalculados imediatamente para refletir apenas os módulos autorizados da nova obra (`modules`/`allowedModules`), evitando retenção de permissões da obra anterior ou vazamento de acesso.

**Approach:** Prover um seletor de obra ativa no topo (`SigoTopBar`) baseado nas obras disponíveis da construtora, garantir que `currentPermissionsProvider` e `AccessGuard` revalidem e recalculem instantaneamente os módulos autorizados (incluindo compatibilidade com `allowedModules` e normalização de aliases), atualizando o layout, a sidebar e o dashboard de forma estritamente reativa e sem necessidade de reload.

## Boundaries & Constraints

**Always:**
- Preservar a hierarquia existente `construtoras/{cId}/obras/{oId}`.
- Normalizar aliases de módulos legados (`rdo` -> `diario`, `almoxarifado` -> `estoque`).
- Respeitar o privilégio dev global e permissões de administrador de construtora (`isAdmin`/`isOwner`).
- Falhar de forma fechada (AccessDenied) caso a obra ou o membro estejam inativos ou o módulo não conste nas permissões da obra selecionada.

**Never:**
- Não executar reloads de página inteira (F5) ou criar loops de navegação.
- Não compartilhar cache de permissões entre diferentes obras.
- Não alterar schemas de banco em produção ou desrespeitar os isolamentos estabelecidos em C0–C6.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Troca de Obra A -> Obra B | Usuário seleciona Obra B no seletor da TopBar | Navega para `/construtora/{cId}/obra/{oIdB}`; Sidebar e Dashboard recalculam exibindo apenas os módulos autorizados de B | N/A |
| Módulo diferente por obra | Obra A tem `['diario']`, Obra B tem `['lotes']` | Na Obra A exibe Diário; ao trocar para B, Diário desaparece e Lotes aparece imediatamente | N/A |
| Rota direta não autorizada | Usuário acessa `/construtora/{cId}/obra/{oIdB}/diarios` sem permissão em B | `AccessGuard` detecta ausência do módulo na nova obra e renderiza `AccessDeniedScreen` | Tela de Acesso Negado exibida |
| Obra inativa | Obra com `isActive == false` | Acesso negado para usuários comuns; dev global preserva acesso de suporte | AccessDeniedScreen para usuário comum |
| Compatibilidade de campos | Documento Firestore usando `allowedModules` | Normaliza e carrega módulos idêntico a `modules` | Falha fechada se vazio ou inválido |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/obras/presentation/current_permissions_provider.dart` -- Provedor de permissões por escopo `(construtoraId, obraId)`; adicionar suporte a `allowedModules` e verificação de obra ativa.
- `app/lib/src/common_widgets/sigo_top_bar.dart` -- Adicionar seletor de obra ativa (`ObraSwitcher`) quando em contexto de construtora/obra.
- `app/lib/src/common_widgets/sigo_sidebar.dart` -- Assegurar reatividade instantânea dos itens de menu às permissões da obra ativa.
- `app/lib/src/common_widgets/access_guard.dart` -- Garantir bloqueio imediato na troca de obra para módulos não autorizados.
- `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart` -- Cards de módulos renderizados estritamente a partir do `currentPermissionsProvider`.
- `app/test/widget_test.dart` -- Testes de widget cobrindo a troca de obra e o recálculo dinâmico do layout.

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/features/obras/presentation/current_permissions_provider.dart` -- Suportar `allowedModules` como fallback de `modules` e validar status da obra.
- [ ] `app/lib/src/common_widgets/sigo_top_bar.dart` -- Implementar dropdown/seletor de obra ativa permitindo troca rápida entre obras da mesma construtora.
- [ ] `app/lib/src/common_widgets/sigo_sidebar.dart` -- Sincronizar itens de navegação com a obra ativa imediatamente após a seleção.
- [ ] `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart` -- Garantir renderização reativa dos cards da obra ativa.
- [ ] `app/test/widget_test.dart` -- Adicionar testes de widget e de provedor verificando a troca de contexto entre obras com módulos distintos.

**Acceptance Criteria:**
- Given um usuário com acesso a Obra A (com módulo `diario`) e Obra B (com módulo `lotes`), when o usuário alterna de Obra A para Obra B no seletor, then o layout da sidebar e os cards do dashboard atualizam instantaneamente, exibindo 'Lotes e Setores' e ocultando 'Diário de Obra'.
- Given um usuário navegando para uma sub-rota `/construtora/{cId}/obra/{oId}/diarios` em uma obra onde não possui permissão, when a página é carregada, then o `AccessGuard` bloqueia o conteúdo e renderiza `AccessDeniedScreen`.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

Utilizar Riverpod family provider `currentPermissionsProvider((construtoraId: cId, obraId: oId))` para isolar os estados por obra. O seletor de obra na `SigoTopBar` obtém as obras da construtora através de `construtoraObrasProvider(cId)` e navega via `context.go('/construtora/$cId/obra/$novaObraId')`, garantindo sincronização imediata com o GoRouter e componentes filhos.

## Verification

**Commands:**
- `cd app && flutter analyze` -- expected: Sem erros ou warnings.
- `cd app && flutter test` -- expected: Todos os testes passando (incluindo novo teste de recálculo de módulos).
- `cd app && flutter build web` -- expected: Build de produção Web sem erros.

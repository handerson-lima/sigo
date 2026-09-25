---
title: 'Correção da navegação hierárquica (Epic 11)'
type: 'bugfix'
created: '2026-09-24'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'f43a5d3c3b644614c5cce491faab6ca4821f921a'
context: ['_bmad-output/implementation-artifacts/epic-11-context.md', '_bmad-output/implementation-artifacts/epic-11-retro-2026-09-24.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A navegação Loteamento → Quadra → Lote → Setor → Equipe entregue no Epic 11 tem defeitos que impedem uso real: dois caminhos com ids `'dummy'`/`'dummy_loteamento'`/`'dummy_quadra'`; `AddLoteScreen` sem rota e sem ação de criação; rotas da hierarquia sem `module`/`adminOnly` no `AccessGuard` e ícone do dashboard dessincronizado; links para a rota removida `/construtora/:cId/obra/:oId/lotes` (404 em navegação primária); redirects que perdem query/fragment; e as 5 telas novas com erro/vazio genéricos (erro descartado) e copy com enum interno e "Phase" em inglês.

**Approach:** Eliminar os placeholders via seleção explícita Loteamento→Quadra→Lote (Decisions/F1); registrar a rota de criação de Lote e gatear criação/leitura por permissão espelhando o `AccessGuard`; corrigir links legados e redirects; e padronizar as 5 listagens em `SigoLayout` com estados de erro (retry + causa resumida) e vazio específicos, com status em pt-BR.

## Boundaries & Constraints

**Always:**
- Hierarquia canônica: construtora > loteamento > quadra > lote > setor > equipe; a URL é a fonte da verdade da navegação.
- Nunca exibir nome interno de enum nem texto em inglês ao usuário; copy em pt-BR.
- Rotas da hierarquia usam `AccessGuard` com `module: 'lotes'`; criação com `adminOnly: true`. O ícone "Loteamentos" do dashboard espelha exatamente essa condição (`admin/owner` OU módulo central `lotes`).
- Erro: retry via `ref.invalidate(<provider>(params))` e causa resumida; vazio: copy específica por tela; CTA de criação só onde existe formulário e permissão.
- Preservar query/fragment nos redirects (`state.uri.replace(path: ...)`).

**Never:**
- Não alterar o schema do Firestore nem migrar dados (OQ-1 do PRD permanece aberta).
- Não usar estado em memória para a rota; não remover `SigoLayout`/`SigoBreadcrumbs`.
- Não inventar vínculo Obra→Loteamento.

**Decisions:**
- **F1 (aprovado):** resolve-se por **seleção explícita na hierarquia** (Loteamento → Quadra → Lote) nos formulários obra-scoped; o gráfico "Status dos Lotes" do dashboard de obra é removido e `obraLotesProvider` deixa de existir (consumidores passam a usar `watchLotesProvider` com ids explícitos). Sem migração de dados e sem alterar o schema.

</frozen-after-approval>

## Code Map

- `app/lib/src/features/lotes/presentation/obra_lotes_provider.dart` -- remover (sem consumidores após F1).
- `app/lib/src/features/rh/presentation/chamada_form_screen.dart:430` -- `'dummy_loteamento'` + TODO; ajustar conforme F1.
- `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart` -- consumo `obraLotesProvider` (74-78); links `/obra/:oId/lotes` (151,168); gate do ícone (75,100-107).
- `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart:367` e `app/lib/src/features/despesas_adm/presentation/despesa_adm_form_screen.dart:271` -- consumidores.
- `app/lib/src/features/lotes/routing/lotes_routes.dart` -- rota `novo` (antes de `:loteId`), `module`, redirect com `replace`.
- `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart`, `.../quadras/routing/quadras_routes.dart`, `.../setores/routing/setores_routes.dart`, `.../equipes/routing/equipes_routes.dart` -- `module`, redirects com `replace`.
- `app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- já usa `SigoLayout`; registrar rota.
- 5 listagens (`loteamentos/quadras/lotes/setores/equipes`) -- `SigoLayout` + `SigoErrorState`/`SigoEmptyState`.
- `app/lib/src/common_widgets/sigo_error_state.dart`, `sigo_empty_state.dart` -- novos widgets compartilhados.
- `app/lib/src/features/obras/presentation/obras_list_screen.dart:75,100-107` -- gate do ícone alinhado ao `AccessGuard`.
- `app/lib/src/common_widgets/sigo_sidebar.dart:240`, `app/lib/src/features/validacao/presentation/lote_validacoes_screen.dart:210` -- links legados.
- `app/lib/src/features/lotes/domain/lote.dart` -- label pt-BR de `LoteStatus`.
- Testes: `app/test/loteamento_quadra_lote_providers_test.dart` (`FakeLoteRepository.calls`), `app/test/fixtures/chamada_form_fixture.dart:91` (`TestLoteRepository`), `app/test/obras_lotes_crud_test.dart:171`, `app/test/src/features/*/presentation/*_list_screen_test.dart`, `app/test/loteamento_quadra_lote_navigation_test.dart`.

## Tasks & Acceptance

**Execution:**
- [x] Conforme **F1**: remover os ids `'dummy'` em `obra_lotes_provider.dart` e `chamada_form_screen.dart` e ajustar os 3 consumidores.
- [x] `lotes_routes.dart` -- adicionar rota `novo` (AddLoteScreen) sob `lotes`, antes de `:loteId`, com `module: 'lotes', adminOnly: true` -- reabilita criação.
- [x] `lotes_routes.dart` + `loteamentos/quadras/setores/equipes _routes.dart` -- passar `module: 'lotes'` às listas e usar `state.uri.replace(path: ...)` nos redirects `:loteamentoId/:quadraId/:loteId/:setorId`.
- [x] `lotes_list_screen.dart` -- FAB/ação "Novo Lote" (admin) navegando para a rota `novo` com `loteamentoId`/`quadraId`.
- [x] `obras_list_screen.dart` -- gatear o ícone por `admin/owner` OU módulo `lotes` (igual ao `AccessGuard`).
- [x] `obra_dashboard_screen.dart`, `sigo_sidebar.dart`, `lote_validacoes_screen.dart` -- trocar links `/obra/:oId/lotes` por `/construtora/:cId/loteamentos` (ou adicionar redirect em `obra_routes.dart`).
- [x] Criar `SigoErrorState`/`SigoEmptyState`; aplicá-los nas 5 listagens envolvidas em `SigoLayout`, com copy específica e retry.
- [x] `lote.dart` + `lotes_list_screen.dart` -- label pt-BR de `LoteStatus` (No prazo/Atrasado/Paralisado/Concluído) e "Fase" no lugar de "Phase".
- [x] Testes: asserir args reais nos providers e em `TestLoteRepository.watchLotes`; tooltip "Loteamentos" por permissão; texto de status em LotesList; redirects `:loteamentoId`/`:quadraId`; retry e vazio por tela.

**Acceptance Criteria:**
- Given nenhuma string `'dummy'`, when `grep dummy app/lib`, then nenhuma ocorrência.
- Given usuário sem módulo `lotes` e não-admin, when abre o dashboard, then tooltip "Loteamentos" ausente; com módulo/admin, presente.
- Given admin na lista de lotes, when toca "Novo Lote", then `AddLoteScreen` abre com `loteamentoId`/`quadraId` corretos.
- Given erro no stream, when toca "Tentar novamente", then o provider é invalidado e a tela recarrega.
- Given lista vazia, when renderiza, then copy específica da tela (ex.: "Nenhum loteamento cadastrado").
- Given deep-link `/.../lotes/:loteId?x=1`, when redireciona, then o fragmento/query é preservado.

## Implementation Notes

- F1 implementada conforme aprovado: `obra_lotes_provider.dart` removido; novo `lote_hierarchy_selector.dart` (Loteamento→Quadra→Lote) usado por `chamada_form_screen`, `movimentacao_screen` e `despesa_adm_form_screen`; gráfico "Status dos Lotes" removido de `obra_dashboard_screen.dart`.
- Rotas: `lotes/novo` (AddLoteScreen, `module:'lotes', adminOnly:true`) declarada antes de `:loteId`; `module:'lotes'` nas 5 listas; redirects `state.uri.replace(path:...)`.
- Links legados `/obra/:oId/lotes` atualizados para `/construtora/:cId/loteamentos` (sidebar, dashboard, validação) — sem redirect, pois não há mapeamento obra→loteamento.
- 5 listagens migradas para `SigoLayout` + `SigoErrorState`/`SigoEmptyState`; `LoteStatus.label` em pt-BR e "Fase".
- Follow-up (não silenciado): criação de Loteamento/Quadra ainda sem tela (repos têm `create`, sem UI); registrado em `deferred-work.md`. Regressão menor conhecida: em edição de despesa ADM o lote salvo não é reposto no seletor hierárquico (o caminho antigo já retornava vazio em produção; não piora).
- Evidência: `flutter analyze` limpo; `flutter test` 480 verdes; `grep dummy app/lib` sem ocorrências.

## Review Triage Log

Passada 1 (blind-hunter + edge-case-hunter + verification-gap). Sem loopback: nenhum `intent_gap`/`bad_spec`; patches agrupados por causa raiz.

**Grupo A — estados/UX do `LoteHierarchySelector` e erros**
- `medium` BH1/EC2/BH15/EC10 — selector engole erro de loteamentos/quadras/lotes (`SizedBox.shrink`) e `chamada` usa `value ?? []`: sem retry/causa. Verificado no diff e no widget. → patch: exibir `SigoErrorState` com retry por nível.
- `medium` BH5 — `loteValidator != null` remove a opção "Nenhum lote específico (Geral da Obra)", impedindo limpar o lote. Verificado em `lote_hierarchy_selector.dart`. → patch: manter a opção nula e validar quando apropriação ativa.
- `low` BH3 — `helperText` de rateio vs custo direto perdido em `despesa_adm_form_screen`. Verificado. → patch: repor via `loteLabel/helper`.
- `medium` BH6 — `SigoErrorState` exibe `cause.toString()` cru (sem pt-BR/sanitização). → patch: resumo pt-BR por tipo.
- `low` BH7/EC9 — `substring(0,120)` pode cortar par surrogate. → patch: `characters.take`.
- `low` BH2 — `SigoEmptyState.action` sem uso; CTA de vazio. → patch: usar em Lotes quando admin.

**Grupo B — verificação/lacunas de teste**
- `medium` VG1 — `module`/`adminOnly` das rotas nunca avaliados (testes usam dev=true). → patch: casos no `access_guard_test.dart` + rota `novo` com não-admin.
- `medium` VG2 — links legados trocados sem teste de navegação. → patch: assertar `router.state.uri.path` ao tocar no card/voltar.
- `low` VG3 — `LoteStatus.label` sem asserção (só "Fase"). → patch: assertar `Status: No prazo`.
- `medium` BH9 — sem testes para os widgets novos/branches do selector. → patch.
- `medium` BH10 — `stock_saida`/`stock_monetario` removem override e passam a depender do erro engolido. → patch: overrides + assert.

**Grupo C — divergência de permissão nos pontos de entrada**
- `medium` BH11/EC8/VG4 — FAB "Novo Lote" aceita `role` string; `AccessGuard` usa booleanos → botão aparece e rota nega. Verificado (`lotes_list_screen.dart:34-38` vs `access_guard.dart:38`). → patch: fonte única de permissão (isAdmin||isOwner, sem `role`).
- `medium` EC5/EC6 — card/sidebar "Lotes e Setores" gateados por módulo de **obra**, mas a rota central exige módulo central `lotes` → AccessDenied. → patch: gatear por permissão central (igual `AccessGuard`).
- `medium` EC4 — card "Validação & Qualidade" aponta para `/loteamentos` e nega a quem só tem `validacao`. → patch: apontar para a rota de validação.
- `medium` EC7 — "Voltar aos Lotes" em `lote_validacoes_screen` aponta para `/loteamentos` e nega a quem só tem `validacao`. → patch: voltar ao dashboard da obra.

**Adiados/rejeitados**
- `false` BH12 — remoção do gráfico "Status dos Lotes" foi decisão F1 aprovada; sem defeito.
- `false` BH14 — corrigir coordenadas da spec = editar esta spec; rejeitado por regra.
- `false` BH16 — `context.go` para rota-filha + `pop` no AddLoteScreen funcional no GoRouter aninhado.
- `false` EC1 — `quadraId` não nulo com `loteamentoId` nulo é inalcançável: os callbacks resetam `quadraId` ao trocar loteamento.
- `low` → reject BH8 — cores/semântica dos widgets novos: cosmético, padrão do repo usa `Colors.*`; sem dano demonstrado.
- `low` → defer EC3 — ids retidos ausentes após refresh causam dropdowns vazios; borda pré-existente de dados.
- `maybe-false` → defer BH4 — edição de chamada não repõe loteamento/quadra do lote salvo; o caminho antigo já retornava vazio em produção.

## Verification

**Commands:**
- `flutter analyze` (em `app/`) -- expected: sem novos erros/avisos.
- `flutter test` (em `app/`) -- expected: suíte verde.

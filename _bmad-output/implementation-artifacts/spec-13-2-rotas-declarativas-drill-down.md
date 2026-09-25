---
title: 'Story 13.2 - Rotas Declarativas e Drill-down Inicial (Construtora → Loteamento → Quadra)'
type: 'feature'
created: '2026-09-25'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
context: ['_bmad-output/implementation-artifacts/epic-13-context.md', '_bmad-output/planning-artifacts/architecture/architecture-obras-2026-09-24/ARCHITECTURE-SPINE.md', '_bmad-output/specs/spec-navegacao-loteamento-etapa/SPEC.md', '_bmad-output/planning-artifacts/architecture/architecture-modular-routing-2026-09-23/ARCHITECTURE-SPINE.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A navegação usa o prefixo singular `/construtora/:cId`, divergente do AD-2 (`/construtoras/:cid/loteamentos/:lid/quadras/:qid/...`), e a UI principal ainda exibe "Obras" e "Lotes e Setores". O card de construtora cai em `ObrasListScreen` em vez da lista de Loteamentos, e parte do contexto depende de singletons (`obraSelecionadaProvider`, `ObraSwitcher`) em vez da URL.

**Approach:** Padronizar as rotas declarativas em `/construtoras/:cid/...`, derivando o contexto dos parâmetros da URL, com drill-down até Quadra (Lote/Etapa/Equipe ficam para 13.3/13.4). Renomear "Obras"→"Loteamentos" na navegação principal e fazer o card de construtora abrir a listagem de Loteamentos (CAP-1).

## Boundaries & Constraints

**Always:**
- Paths plurais e minúsculos: `/construtoras`, `/loteamentos`, `/quadras`, `/lotes`, `/etapas`, `/equipes` (AD-2 e Conventions da spine).
- Cada listagem carrega a partir dos params da URL; nunca de singleton global de seleção (AD-2).
- Breadcrumbs derivam do path e exibem também o nível Construtora.
- Navegação usa exclusivamente a terminologia Loteamento/Quadra/Lote/Etapa/Equipe.

**Never:**
- Não alterar o esquema de dados entregue na 13.1 nem criar subcollections.
- Não remover as features obra-scoped ainda em uso (diário, RH, compras, custos) sem rota substituta.
- Não mudar perfis de acesso nem o dashboard principal além de label/clique (non-goal do SPEC).

**Decisions:**
- Prefixo plural `/construtoras` com rota de compatibilidade: `/construtora/:cid/...` → redirect para `/construtoras/:cid/...` preservando query/fragment.
- Rotas obra-scoped (`/obra/:oid/{diarios,rh,compras,despesas,custos-360}`) permanecem vivas sob `/construtoras/:cid/...`; apenas o entrypoint da construtora passa a Loteamentos.
- Higienização do estado global `obraSelecionadaProvider`/`ObraSwitcher` fica diferida (registrada em `deferred-work.md`).
- Card de construtora abre direto `/construtoras/:cid/loteamentos`.
- Spec mantido completo (coeso; ~1638 tokens, pouco acima do alvo).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH | toque no card de uma construtora | URL vira `/construtoras/:cid/loteamentos` e lista os Loteamentos da construtora | N/A |
| DEEP_LINK | abrir `/construtoras/:cid/loteamentos/:lid/quadras` direto | renderiza as Quadras do loteamento da URL | estado vazio contextual se não houver quadras |
| PARENT_REDIRECT | abrir `/construtoras/:cid/loteamentos/:lid` | redireciona para `.../:lid/quadras` preservando query/fragment | N/A |
| LEGACY_SINGULAR | abrir `/construtora/:cid/...` | redireciona para `/construtoras/:cid/...` preservando query/fragment | N/A |
| BREADCRUMB_ASCENT | tocar no crumb "Loteamentos" | ascende para a lista de Loteamentos | N/A |
| EMPTY_STATE | construtora sem loteamentos | exibe vazio contextual com CTA de criação (se houver) | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/routing/app_router.dart:29,60-64` — `routerProvider`; spread de `authRoutes`/`devRoutes`/`construtoraRoutes`; redirect central de auth/dev em `:36-59`.
- `app/lib/src/features/construtoras/routing/construtora_routes.dart:24,32-71` — `ConstrutoraPaths.detail = '/construtora/:cId'` e o nó-pai que recebe `...obraRoutes`, `...loteamentosRoutes`, etc. (`:58-69`). Prefixo singular a migrar.
- `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart:7-8,24-36` — `loteamentos`/`loteamentos/:loteamentoId`; redirect `:loteamentoId`→`/quadras` em `:27-31`.
- `app/lib/src/features/quadras/routing/quadras_routes.dart:7-8,26-38` — `quadras`/`quadras/:quadraId`; redirect `:quadraId`→`/lotes`.
- `app/lib/src/features/lotes/routing/lotes_routes.dart:8-9,50-59` — `lotes`/`:loteId`→`/etapas`; `...etapasRoutes` composto em `:54`.
- `app/lib/src/features/etapas/routing/etapas_routes.dart:7,29-41` e `.../equipes/routing/equipes_routes.dart:6-30` — módulos Lote→Etapa→Equipe (já entregues; manter funcionando).
- `app/lib/src/features/obras/routing/obra_routes.dart:8-27` — `obra/:oId` → `ObraDashboardScreen`; módulos obra-scoped (`diario_routes.dart:11-13`, `rh_routes.dart:16-19`, `epi_routes.dart:10`, `despesas_adm_routes.dart:10-14`, `compras_routes.dart:10-14`, `custos_360_routes.dart:9-11`).
- `app/lib/src/common_widgets/sigo_breadcrumbs.dart:16-62` — deriva de `uri.pathSegments`; reconhece só `loteamentos|quadras|lotes|etapas|equipes`; **ignora `construtora`/`construtoras`** e não emite crumb da construtora.
- `app/lib/src/common_widgets/sigo_sidebar.dart:28` — parser testa `pathSegments[0] == 'construtora'`; itens "Dashboard" (`:220-229`), "Lotes e Setores" (`:235-243`, navega para `/construtora/$cId/loteamentos`), "Diário de Obra" (`:250`).
- `app/lib/src/common_widgets/sigo_top_bar.dart:69-73,206-282` — parser singular em `:69`; `ObraSwitcher` navega para `/construtora/$construtoraId/obra/$newObraId` em `:272`.
- `app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart:68` — card navega para `/construtora/${construtora.id}` (cai em `ObrasListScreen`).
- `app/lib/src/features/obras/presentation/obras_list_screen.dart:82-110,174-399` — entrypoint atual; labels "Obra"/"Nova Obra"; atalho "Loteamentos" em `:104-110`.
- `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart:88-155` — "Painel da Obra"; card "Lotes e Setores" (`:144-150`) → `/construtora/$cId/loteamentos`.
- `app/lib/src/features/construtoras/presentation/membros_providers.dart:206-217` — `obraSelecionadaProvider` (estado global).
- Screens que montam `activeRoute`/`context.go` com prefixo singular: `loteamentos_list_screen.dart:25,55`, `quadras_list_screen.dart:28,58`, `lotes_list_screen.dart:37`, `etapas_list_screen.dart:35`, `equipes_list_screen.dart:40`.
- Testes a migrar para plural: `app/test/loteamento_quadra_lote_navigation_test.dart`, `app/test/sigo_breadcrumbs_test.dart`, `app/test/loteamento_quadra_lote_providers_test.dart`, `app/test/sigo_top_bar_test.dart`, `app/test/obra_switcher_layout_test.dart`, `app/test/sigo_sidebar_test.dart`, `app/test/sigo_sidebar_collapsed_test.dart`, e `app/test/src/features/**/presentation/*_test.dart`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/features/construtoras/routing/construtora_routes.dart` — trocar `ConstrutoraPaths.detail` para `/construtoras/:cid` e ajustar `membros`/subárvore; manter os módulos obra-scoped vivos sob o plural (ver Decisions).
- [ ] `app/lib/src/features/{loteamentos,quadras,lotes,etapas,equipes}/routing/*_routes.dart` — atualizar paths/`*For()` para plural e `:cid`; preservar os redirects pai→filho existentes.
- [ ] `app/lib/src/routing/app_router.dart` — adicionar redirect de `/construtora/...` → `/construtoras/...` preservando query/fragment (rota de compatibilidade).
- [ ] `app/lib/src/common_widgets/sigo_breadcrumbs.dart` — reconhecer `construtoras` e emitir o crumb da Construtora (link para `/construtoras/:cid/loteamentos`), sem quebrar os crumbs existentes.
- [ ] `app/lib/src/common_widgets/sigo_sidebar.dart` e `sigo_top_bar.dart` — parser para `construtoras`; renomear "Lotes e Setores"→"Loteamentos" e demais labels de navegação.
- [ ] `app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart` — card navega para `/construtoras/:cid/loteamentos` (CAP-1).
- [ ] `app/lib/src/features/obras/presentation/obras_list_screen.dart` / `obra_dashboard_screen.dart` — ajustar entrypoint e labels "Obra"→"Loteamento" na navegação (card da construtora → Loteamentos; ver Decisions).
- [ ] `app/test/**` — migrar paths para plural e cobrir: card→Loteamentos, deep-link até Quadra, redirects pai→filho, redirect de compatibilidade (se A) e crumb da Construtora.

**Acceptance Criteria:**
- Given um usuário logado, when toca o card de uma construtora, then a URL é `/construtoras/:cid/loteamentos` e vê os Loteamentos da construtora.
- Given a lista de Loteamentos, when seleciona um loteamento, then a URL vira `.../loteamentos/:lid/quadras` e vê apenas as Quadras desse loteamento.
- Given deep-link em `/construtoras/:cid/loteamentos/:lid/quadras`, when abre direto, then renderiza as Quadras corretas a partir da URL.
- Given abertura de path pai (`.../loteamentos/:lid`), when navega, then redireciona para a listagem filha preservando query/fragment.
- Given qualquer path com "Obras"/"Setor" na navegação, when renderiza, then os labels exibem Loteamentos/Etapa.
- Given a rota legada, when abre `/construtora/:cid/loteamentos`, then redireciona para `/construtoras/:cid/loteamentos` preservando query/fragment.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

**Rota modular (padrão existente):** cada feature expõe `<Feature>Paths` + `get <feature>Routes` e é composta por spread no nó-pai (`construtora_routes.dart:58-69`); manter esse padrão e apenas migrar o prefixo/params. Não introduzir provider de navegação global — a URL é a fonte do contexto (AD-2).

```dart
abstract class ConstrutoraPaths {
  static const detail = '/construtoras/:cid';
  static String detailFor(String cid) => '/construtoras/$cid';
}
```

**Redirects pai→filho:** manter o padrão atual que preserva query/fragment (`state.uri.path == state.matchedLocation ? state.uri.replace(path: '...') : null`) já usado em `loteamentos_routes.dart:27-31` e `quadras_routes.dart:29-33`.

## Verification

**Commands:**
- `flutter analyze` (workdir `app/`) — expected: `No issues found!`
- `flutter test` (workdir `app/`) — expected: todos os testes passam, incluindo navegação e breadcrumbs migrados para `/construtoras`.
- `flutter test test/loteamento_quadra_lote_navigation_test.dart test/sigo_breadcrumbs_test.dart` — expected: deep-links, redirects e crumb da Construtora passam.

**Manual checks (if no CLI):**
- Tocar o card de construtora e confirmar `/construtoras/:cid/loteamentos` com Loteamentos.
- Clicar num Loteamento → Quadras, conferindo a URL e o breadcrumb (incluindo Construtora).
- Abrir um deep-link direto de Quadras e confirmar render a partir da URL.

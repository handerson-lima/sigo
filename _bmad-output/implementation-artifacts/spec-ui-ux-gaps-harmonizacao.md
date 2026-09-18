---
title: 'UX/UI — Harmonização Visual, Navegação na Sidebar, Dashboard Categorizado e SigoLayout'
type: 'enhancement'
created: '2026-09-18'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-1-modulo-epi.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-2-modulo-validacao.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-3-modulo-adm.md'
---

# UX/UI — Harmonização Visual e Navegação Completa

## Resumo das Modificações
1. **Barra Lateral (`sigo_sidebar.dart`):**
   - Inclusão das rotas de **Contas a Pagar / ADM** (`/construtora/:cId/obra/:oId/despesas`) e **Entrega de EPIs** (`/construtora/:cId/obra/:oId/epis/entrega`) no escopo da obra.
   - Inclusão das rotas de **Catálogo de EPIs** (`/construtora/:cId/epis`) e **Templates de Validação** (`/construtora/:cId/validacao/templates`) na navegação global da construtora.
   - Implementadas as checagens seguras de permissão RBAC (`canAdm`, `canEpi`, `canEpiCatalogo`, `canValidacao`).

2. **Dashboard da Obra (`obra_dashboard_screen.dart`):**
   - Inclusão do card do módulo de **Validação & Qualidade** (direcionando para vistorias dos lotes da obra).
   - Reorganização dos módulos em 3 seções semânticas estruturadas (*Canteiro & Produção*, *Pessoas & Segurança*, *Gestão & Suprimentos*), reduzindo a carga cognitiva e melhorando a affordance.

3. **Padronização do Shell Responsivo (`SigoLayout`):**
   - Substituição de `Scaffold` cru por `SigoLayout` em `CatalogoEpisScreen` e `EntregaEpiScreen` (Módulo EPI).
   - Envelopamento com `SigoLayout` em `DespesasAdmListScreen` e `DespesaAdmDetailsScreen` (Módulo ADM), garantindo que a barra lateral fixa no Desktop e o Drawer no Mobile estejam presentes em 100% das telas principais.

4. **Resiliência de Layout em `SigoModuleCard`:**
   - Prevenção de overflow de RenderFlex em títulos de múltiplas linhas com `Flexible` e `TextOverflow.ellipsis`.

## Verificação
- `flutter analyze`: 0 apontamentos encontrados (exit code 0).
- `flutter test`: 252/252 testes aprovados com 100% de sucesso (exit code 0).
- `hot_reload`: recarga a quente executada com sucesso via DTD no aplicativo Flutter Web ativo.

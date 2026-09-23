---
title: 'Modularizar router — rotas por feature'
type: 'refactor'
created: '2026-09-23'
status: 'in-progress'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-modular-routing-2026-09-23/ARCHITECTURE-SPINE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O `app_router.dart` acumula 677 linhas e ~50 imports de 15 features num único arquivo, gerando conflitos de merge e acoplamento entre módulos.

**Approach:** Extrair as rotas de cada feature para `features/<feature>/routing/<feature>_routes.dart`, cada uma exportando `List<RouteBase>` e path constants; o router central compõe via spread (`...featureRoutes`). Redirect de auth/dev permanece centralizado. Zero mudança funcional.

</frozen-after-approval>

## Implementation Notes


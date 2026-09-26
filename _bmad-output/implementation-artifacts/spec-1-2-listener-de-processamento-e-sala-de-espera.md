---
title: 'Story 1.2: Listener de processamento e sala de espera'
type: 'feature'
created: '2026-09-26'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: ["_bmad-output/implementation-artifacts/epic-1-context.md"]
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O sistema precisa que o usuário aguarde o processamento contínuo em background (sem polling), exibindo animação até que o rascunho GeoJSON seja retornado para a próxima tela.

**Approach:** A funcionalidade de listener no Firestore (`loteamentos_drafts/{id}`) e a tela de sala de espera com a animação e redirecionamento (`loteamento_processing_screen.dart`) já foram implementadas durante a execução da Story 1.1. Esta spec registra formalmente a conclusão dos requisitos da Story 1.2.

</frozen-after-approval>

## Implementation Notes

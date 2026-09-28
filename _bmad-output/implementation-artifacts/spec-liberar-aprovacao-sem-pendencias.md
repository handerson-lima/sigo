---
title: 'Liberar aprovação do loteamento sem pendências'
type: 'bugfix'
created: '2026-09-28'
status: 'in-progress'
route: 'oneshot'
review_loop_iteration: 0
context: []
baseline_commit: '6bfe5de322ba80d46e8beaafc16e1d2739757388'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A tela mostra zero pendências após a revisão do DXF, mas o botão “Aprovar Definitivamente” permanece desabilitado por validações internas que não correspondem ao estado exibido.

**Approach:** Habilitar a aprovação quando não houver lotes ambíguos e garantir que o backend aceite os lotes já válidos ou resolvidos gerados pelo processo de importação.

</frozen-after-approval>

## Implementation Notes

- O bloqueio atual exige que todos os lotes tenham `status: resolvido`, nome e quadra preenchidos, embora a importação marque lotes identificados automaticamente como `valido`. A UI já informa corretamente o critério visível: zero pendências.

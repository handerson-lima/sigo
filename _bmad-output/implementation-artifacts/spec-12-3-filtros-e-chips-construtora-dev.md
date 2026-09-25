---
title: 'Filtros e Chips de Status na listagem de Construtoras (Painel Dev)'
type: 'feature'
created: '2026-09-24'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A tela de listagem de construtoras no painel dev não exibe visualmente o status atual de ativação da construtora, nem permite filtrar a lista por nome, CNPJ ou status.

**Approach:** Converter `DevConstrutorasListScreen` para `StatefulWidget` para armazenar o estado de busca (query text) e filtro de status (Todas/Ativas/Inativas). Adicionar chips visuais ("Ativa"/"Inativa") na renderização de cada construtora na lista. Filtrar a lista recuperada pelo `StreamBuilder` localmente (client-side) com base nos critérios de busca e status.

</frozen-after-approval>

## Code Map

- `app/lib/src/features/developer/presentation/dev_construtoras_list_screen.dart` -- Tela alvo. Converter para StatefulWidget, adicionar TextField e Wrap/ToggleButtons para busca e status, e adicionar ChoiceChip ou Chip para exibir o status no ListTile.

## Implementation Notes


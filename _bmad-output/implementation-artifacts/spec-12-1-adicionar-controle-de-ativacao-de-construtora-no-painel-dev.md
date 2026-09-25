---
title: 'Adicionar controle de ativação de construtora no Painel Dev'
type: 'feature'
created: '2026-09-24'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Atualmente, não há controle de ativação das construtoras cadastradas no painel. Permitir inativar uma construtora garante que ela não seja acessada indevidamente.

**Approach:** Adicionar um componente de Toggle/Switch (como SwitchListTile) na interface de edição no Painel Dev (`dev_construtoras_list_screen.dart` - `_EditConstrutoraDialog`), permitindo alterar o status `isActive` de uma construtora, persistindo essa mudança no Firestore e exibindo um snackbar de confirmação ao usuário. O modelo `Construtora` já possui a propriedade `isActive`.

</frozen-after-approval>

## Implementation Notes


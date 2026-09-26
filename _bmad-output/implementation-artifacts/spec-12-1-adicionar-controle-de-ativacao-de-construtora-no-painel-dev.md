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

### Review Findings

**Revisão de homologação (2026-09-26):** commit `ed53736` (story 12.1) vs baseline `8a38163`; 4 camadas (blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). Recorte: toggle `isActive` no Painel Dev.

- [x] [Review][Patch] Snackbar anuncia mudança de status mesmo quando não houve mudança [app/lib/src/features/developer/presentation/dev_construtoras_list_screen.dart:589-597] — a mensagem deriva apenas do `_isActive` final; salvar nome/CNPJ de uma construtora já ativa ainda exibe "Construtora ativada com sucesso.". Capturar o valor original e só confirmar a transição (ou usar mensagem neutra).
- [x] [Review][Patch] Switch permanece habilitado durante o salvamento [app/lib/src/features/developer/presentation/dev_construtoras_list_screen.dart:667] — `onChanged` sem guarda de `_isSaving`; alternar durante o `await docRef.update` faz o snackbar divergir do valor persistido. Usar `onChanged: _isSaving ? null : (val) => setState(...)`.
- [x] [Review][Patch] Nenhum teste prova a persistência de `isActive` [app/lib/src/features/developer/presentation/dev_construtoras_list_screen.dart:583] — nenhum teste referencia `DevConstrutorasListScreen`/`_EditConstrutoraDialog`; trocar `'isActive': _isActive` por `'isActive': true` (ou omitir o campo) passa silenciosamente e o acesso global segue liberado. Adicionar teste de widget com `FakeFirebaseFirestore` (já é dev_dependency).
- [x] [Review][Defer] Inativar pela 12.1 não suspende acesso por si só [firestore.rules] — deferred: o enforcement (query `.where('isActive', isEqualTo: true)` + `activeConstrutora` em `member(c)`) é o escopo da Story 12.2 (em `review`); presente no HEAD, ausente no commit `ed53736`.

**Patches aplicados (2026-09-26):** guarda `_isSaving` no switch; mensagem neutra "Construtora atualizada com sucesso." quando o status não muda; seam `@visibleForTesting buildEditConstrutoraDialog` com `FirebaseFirestore` injetável e teste de widget `app/test/features/developer/dev_construtoras_edit_dialog_test.dart`. **Verificação:** `flutter analyze` sem novos achados; `flutter test` 511/512 (`loteamento_switcher_layout_test.dart` falha pré-existente, confirmada com a mudança em stash).

#### Rejected (appendix)

- `false` — spec `status: done` vs sprint-status `review`/épico `in-progress`: trackers com propósitos distintos; a correção editaria a spec sob review (padrão das triagens anteriores).
- `false` — `## Implementation Notes` vazio e `context: []`: artefatos documentais; a correção edita a spec.
- `false` — nome do arquivo da spec com acento, Approach desatualizado e ausência de AC: artefatos documentais; a correção edita a spec.
- `false` — `ScaffoldMessenger.of(context)` após `Navigator.pop(context)`: no mesmo bloco síncrono o `context` do State ainda está montado; o lookup encontra o messenger raiz do `MaterialApp` e o snackbar é exibido.
- `false` — inativar sem diálogo de confirmação: o intent congelado (`stories.yaml`) pede explicitamente snackbar em vez de diálogos obstrutivos.
- `false` — ausência de registro de auditoria (ator/motivo): nenhum requisito de auditoria na spec ou no épico.
- `false` — whitelist de update de `construtoras` exclui `isActive` (`firestore.rules:44`): o Painel Dev é dev-only e `dev()` concede bypass global; o caminho pretendido grava normalmente.


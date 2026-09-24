---
title: 'Corrigir concorrência no salvamento da chamada'
type: 'bugfix'
created: '2026-09-24'
status: 'in-progress'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problema:** O salvamento da chamada consulta conflitos cross-obra antes de uma espera assíncrona e depois lê novamente o formulário mutável. Isso permite validar uma data e gravar outra, misturar custos/trabalhadores e iniciar operações concorrentes com dois acionamentos rápidos.

**Abordagem:** Capturar os dados da operação antes da primeira espera e usá-los do início ao fim da validação, custos, auditoria e gravação; proteger o salvamento contra reentrada e descarte da tela. Preservar a refatoração já realizada e a meta de no máximo 500 linhas na tela, com testes de regressão determinísticos para as esperas assíncronas.

</frozen-after-approval>

## Implementation Notes

- Usuário autorizou continuar sobre as alterações não commitadas da refatoração anterior. Sem lacunas de intenção, migrações ou efeitos externos; correção local pela rota `oneshot`.
- Arquivo principal: `app/lib/src/features/rh/presentation/chamada_form_screen.dart` (agora 497 linhas, limite 500). Snapshot completo antes do primeiro await: repo, autor (`authRepositoryProvider.currentUser`), data, equipe/lote, chamada anterior, `funcionarios` unmodifiable, workers copiados com `allocations` em `List.unmodifiable`. Single-flight: `if (_isSaving || !mounted) return;` antes de qualquer await; `finally` libera `_isSaving`. Guards de mutação (`_pickDate`, `_onTeamChanged`, `_onDefaultLotChanged`, `_markAllPresent`, `onWorkerChanged`, wrapper `onTeamChanged`) retornam cedo se `_isSaving`. `mounted` após cada await.
- RED confirmado antes do fix: duplo acionamento gerava 2 consultas; consulta atrasada com edição mutava snapshot. Sub-componentes `chamada_form_view.dart` e `chamada_rateio_summary.dart` preservados da refatoração anterior.
- Testes em `app/test/chamada_form_screen_test.dart` (8 widgets) com fixture `app/test/fixtures/chamada_form_fixture.dart` (`ControlledChamadaRepository` com completers). Cobrem: duplo acionamento, snapshot vs edição bloqueada, lote pendente, imutabilidade, conflito cross-obra + retry, erro de gravação + retry, cancelar/confirmar retificação, descarte durante consulta.
- Surpresa nos testes de snackbar: o snackbar de mount ("Todos os operários...") ficava ativo e enfileirava os snackbars de conflito/erro; resolvido com `pump(const Duration(seconds: 2))` após `onMarkAllPresent` na fixture e `pump(350ms)` após os completers.
- Verificação: 8/8 testes novos + 47 testes nas suítes RH (`rh_chamada`, `rh_custos_apropriacao`, `rh_invariantes_auditoria`, `chamada_form_screen`); `dart analyze` limpo nos 3 arquivos; `flutter analyze` só com os 13 `unused_import` preexistentes de roteamento. Entrada high em `deferred-work.md` (snapshot de concorrência) resolvida por esta correção.

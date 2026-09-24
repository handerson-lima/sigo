---
title: 'Corrigir concorrência no salvamento da chamada'
type: 'bugfix'
created: '2026-09-24'
status: 'done'
route: 'oneshot'
review_loop_iteration: 1
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
- Verificação: 8/8 testes novos + 47 testes nas suítes RH (`rh_chamada`, `rh_custos_apropriacao`, `rh_invariantes_auditoria`, `chamada_form_screen`); `dart analyze` limpo nos arquivos; `flutter analyze` só com os 13 `unused_import` preexistentes de roteamento. Entrada high em `deferred-work.md` (snapshot de concorrência) resolvida por esta correção.
- Pós-review Blind Hunter (patch aplicado): `ChamadaFiltrosHeader` ganhou `isSaving` (data/lote/equipe desabilitados durante gravação) e o action "Todos Presentes" passou a respeitar `isSaving`; fixture perdeu `saving`/`container` mortos.

## Review Triage Log

- Sem unicidade data/obra no repositório (UUID novo em `saveChamada`) — **medium, defer**: real, pré-existente, server-side; fora do intent de concorrência de cliente.
- TOCTOU entre `findCrossObraApontamentos` e `saveChamada` — **medium, defer**: real, arquitetura pré-existente; atomicidade exige transação Firestore.
- Retificação `versaoAuditoria + 1` sem precondição + `SetOptions(merge: true)` — **medium, defer**: lost-update real, pré-existente no repo.
- Team-change race (lote stale em `_syncWorkersList` vs `getDefaultLot` assíncrono) — **medium, defer**: real (`chamada_form_screen.dart:182-201` + wrapper `:475-479`), pré-existente, não causado por este changeset.
- Troca de equipe em retificação esvazia lista permanentemente — **medium, defer**: `_onTeamChanged` limpa `_workers` mas `_syncWorkersList` retorna cedo se `_existingChamada != null` (`:145`); pré-existente.
- Botão salvar habilitado com banner de invariantes vermelho — **low, defer**: `_isFormValid` não inclui `lotesValidosDaObra`; pré-existente; user ainda recebe snackbar de rejeição.
- Sem guarda de data duplicada dentro de `_saveChamada` — **low, defer**: `_checkExistingChamadaForDate` é só advisory por design; fluxo "Ver Chamada" sem cobertura; pré-existente.
- `_loadInitialData` sem try/catch — **maybe-false, defer** (medium se real): `getChamada` quebrando viraria unhandled async; assentaria com teste de repo que lança; pré-existente.
- `chamadaId` inexistente cai em modo nova sem aviso — **low, defer**: UX pré-existente em `_loadInitialData`; sem feedback ao usuário de edição.
- `_selectedDate` mistura UTC (`DateTime.tryParse`) e local — **false**: `DateTime.parse('YYYY-MM-DD')` sem offset é local (`utc=false` em Dart 3); roundtrip com `DateFormat('yyyy-MM-dd')` é estável.
- `_syncWorkersList` muta `_workers` durante `build` sem `setState` — **low, defer**: pré-existente; quando lista filtrada vazia o loop é no-op a cada rebuild.
- Sync de workers só por comprimento (sem merge por `workerId`) — **medium, defer**: troca 1-a-1 não refresca; wipe de edições em mudança de contagem; pré-existente.
- Controles de filtro/`Todos Presentes` ativos visualmente durante `_isSaving` — **low, patch (feito)**: guards engoliam taps; agora `isSaving` desabilita InkWell/dropdowns/action.
- Sem teste cobrindo controles desabilitados com `isSaving` — **low, patch**: teste widget de `ChamadaFiltrosHeader`/`onMarkAllPresent` durante save.
- Mensagem de conflito cross-obra mostra `obraId` cru — **low, defer**: record não carrega nome da obra; pré-existente.
- `saveDefaultLot` fire-and-forget sem tratamento de erro; lote pendente descartado durante save — **low, defer**: erro pré-existente; descarte durante save é intencional (snapshot); re-aplicar pós-save é ideia futura.
- Fixture sem teste de write lento (`saving` Completer) — **low, defer**: single-flight já coberto durante a fase de query com o mesmo `_isSaving`; `saving` morto removido no patch.
- `findChamadaByDate` da fixture sempre `null` — **low, defer**: gap de cobertura do caminho "já existe chamada"; pré-existente no harness.
- Sem teste de wiring de `ChamadaRateioSummary`/`ChamadaFormView` — **low, defer**: gap da extração anterior, não deste changeset.
- Ação "Ver Chamada" sem `context.mounted` — **maybe-false, defer** (medium se real): snackbars podem sobreviver à rota; assentaria com teste de tap pós-navegação; pré-existente.
- `uid = user?.uid ?? 'unknown'` grava sem usuário — **low, defer**: fallback pré-existente; rota protegida por `AccessGuard`; assentaria com teste sem `currentUser`.
- Sem `PopScope` durante save/desconferido — **low, defer**: feature gap pré-existente; navegação mid-save ainda é possível no system back.
- Texto cru de exceção no snackbar de erro — **low, defer**: `'Erro ao salvar chamada: $e'` pré-existente; ideal log + mensagem genérica.
- Fixture depende de `pump(2s)` pós-`onMarkAllPresent` — **low, rejeitado**: necessário para expirar snackbar de mount (1s) antes de snackbars de conflito/erro; harness de teste, sem impacto em produção; correção exigiria mock de `ScaffoldMessenger`.
- Date picker `firstDate`/`lastDate` hard-coded 2020–2035 — **low, defer**: pré-existente; manutenção cosmética anual.
- `onWorkerChanged` sem guarda de bounds; lista viva exposta à view — **maybe-false, defer** (medium se real): RangeError exigiria index obsoleto entre build e callback; assentaria com caminho reprodutível; lista viva pré-existente.
- `DropdownButtonFormField.initialValue` não refletiria setState programático — **false**: `_DropdownButtonFormFieldState.didUpdateWidget` chama `setValue` quando `initialValue` muda (`dropdown.dart:2002-2005`); teste de rebuild confirma display atualiza.
- Código morto/duplicado na fixture (`container`, `view()` duplicado) — **low, patch parcial**: `container` e `saving` removidos; helper `view()` da fixture é usado pelo `mount`, duplicata no teste é cosmética (rejeitada).

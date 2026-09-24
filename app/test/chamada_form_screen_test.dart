import 'dart:async';

import 'package:app/src/features/rh/data/custo_mao_de_obra_service.dart';
import 'package:app/src/features/rh/domain/chamada_diaria.dart';
import 'package:app/src/features/rh/presentation/chamada_form_screen.dart';
import 'package:app/src/features/rh/presentation/widgets/chamada_form_view.dart';
import 'package:app/src/features/rh/presentation/widgets/chamada_filtros_header.dart';
import 'package:app/src/features/rh/presentation/widgets/retificacao_chamada_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/chamada_form_fixture.dart';

void main() {
  ChamadaFormView view(WidgetTester tester) =>
      tester.widget<ChamadaFormView>(find.byType(ChamadaFormView));

  ApontamentoTrabalhador worker(String id, {PresencaStatus? status}) =>
      ApontamentoTrabalhador(
        workerId: id,
        workerName: 'Operário ${id.substring(1)}',
        workerRole: 'Pedreiro',
        status: status ?? PresencaStatus.presente,
        allocations: status == PresencaStatus.falta
            ? const []
            : const [AlocacaoLote(lotId: 'l1', lotName: 'l1', percentage: 100)],
      );

  ChamadaDiaria existingChamada() => ChamadaDiaria(
    id: 'ch1',
    construtoraId: 'c1',
    obraId: 'o1',
    date: '2026-01-10',
    teamId: 'e1',
    teamName: 'Equipe 1',
    createdByUid: 'autor',
    defaultLotId: 'l1',
    status: 'fechada',
    workers: [worker('f1'), worker('f2')],
    totalDayCostCents: 20000,
    createdAt: DateTime(2026, 1, 10),
    updatedAt: DateTime(2026, 1, 10),
  );

  testWidgets(
    'duplo acionamento antes do rebuild inicia uma única consulta e gravação',
    (tester) async {
      final f = ChamadaFormFixture();
      await f.mount(tester);
      final save = view(tester).onSave;
      save();
      save();
      expect(f.repo.queries, hasLength(1));
      f.repo.pending.single.complete([]);
      await tester.pumpAndSettle();
      expect(f.repo.saved, hasLength(1));
      expect(find.text('Lista de chamadas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'consulta atrasada grava snapshot original mesmo com edição bloqueada',
    (tester) async {
      final f = ChamadaFormFixture();
      await f.mount(tester);
      final originalDate = view(tester).formattedDate;
      final originalTeam = view(tester).selectedTeamId;
      final originalWorkers = List.of(view(tester).workers);
      final onSave = view(tester).onSave;
      final onTeam = view(tester).onTeamChanged;
      final onWorker = view(tester).onWorkerChanged;
      final onMark = view(tester).onMarkAllPresent;
      final onPick = view(tester).onPickDate;

      onSave();
      expect(f.repo.queries, [originalDate]);

      onTeam('e2');
      onWorker(0, worker('f1', status: PresencaStatus.falta));
      onMark();
      onPick();
      await tester.pump();
      expect(view(tester).selectedTeamId, originalTeam);
      expect(
        view(tester).workers.map((w) => w.status),
        originalWorkers.map((w) => w.status),
      );

      f.repo.pending.single.complete([]);
      await tester.pumpAndSettle();

      expect(f.repo.saved, hasLength(1));
      final saved = f.repo.saved.single;
      expect(saved.date, originalDate);
      expect(saved.teamId, originalTeam);
      expect(
        saved.workers.map((w) => w.status),
        originalWorkers.map((w) => w.status),
      );
      expect(
        saved.totalDayCostCents,
        CustoMaoDeObraService.computeChamadaCosts(
          funcionarios: f.rh.funcionarios,
          apontamentos: originalWorkers,
        ).totalDayCostCents,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lote padrão pendente não sobrescreve o snapshot durante a consulta',
    (tester) async {
      final f = ChamadaFormFixture();
      await f.mount(tester);
      final pendingLot = Completer<String?>();
      f.defaultLot.loading = pendingLot;
      view(tester).onTeamChanged('e2');
      await tester.pump();
      final defaultLotAtSave = view(tester).defaultLotId;

      view(tester).onSave();
      expect(f.repo.queries, hasLength(1));
      pendingLot.complete('l2');
      await tester.pump();
      expect(view(tester).defaultLotId, defaultLotAtSave);

      f.repo.pending.single.complete([]);
      await tester.pumpAndSettle();
      expect(f.repo.saved.single.defaultLotId, defaultLotAtSave);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('gravação salva cópia imutável dos trabalhadores', (
    tester,
  ) async {
    final f = ChamadaFormFixture();
    await f.mount(tester);
    view(tester).onSave();
    f.repo.pending.single.complete([]);
    await tester.pumpAndSettle();
    final saved = f.repo.saved.single;
    expect(() => saved.workers[0].allocations.clear(), throwsUnsupportedError);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflito cross-obra não grava e permite nova tentativa', (
    tester,
  ) async {
    final f = ChamadaFormFixture();
    await f.mount(tester);
    view(tester).onSave();
    f.repo.pending.single.complete([
      (
        obraId: 'outra',
        date: view(tester).formattedDate,
        apontamento: worker('f1'),
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(f.repo.saved, isEmpty);
    expect(find.textContaining('já possui apontamento'), findsOneWidget);

    view(tester).onSave();
    expect(f.repo.queries, hasLength(2));
    f.repo.pending.last.complete([]);
    await tester.pumpAndSettle();
    expect(f.repo.saved, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro na gravação libera o formulário e permite nova tentativa', (
    tester,
  ) async {
    final f = ChamadaFormFixture();
    await f.mount(tester);
    f.repo.failNextSave = true;
    view(tester).onSave();
    f.repo.pending.single.complete([]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(f.repo.saved, isEmpty);
    expect(find.textContaining('Erro ao salvar chamada'), findsOneWidget);

    view(tester).onSave();
    expect(f.repo.queries, hasLength(2));
    f.repo.pending.last.complete([]);
    await tester.pumpAndSettle();
    expect(f.repo.saved, hasLength(1));
    expect(find.text('Lista de chamadas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar retificação não grava e permite nova tentativa', (
    tester,
  ) async {
    final f = ChamadaFormFixture();
    f.repo.existing = existingChamada();
    await f.mount(tester, chamadaId: 'ch1');
    view(tester).onSave();
    f.repo.pending.single.complete([]);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RetificacaoChamadaDialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(f.repo.saved, isEmpty);
    expect(find.byType(ChamadaFormScreen), findsOneWidget);

    view(tester).onSave();
    expect(f.repo.queries, hasLength(2));
    f.repo.pending.last.complete([]);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RetificacaoChamadaDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Correção formal de rateio');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Confirmar Retificação'),
    );
    await tester.pumpAndSettle();
    expect(f.repo.saved, hasLength(1));
    expect(f.repo.saved.single.status, 'retificada');
    expect(f.repo.saved.single.auditTrail, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('descarte durante a consulta não grava nem lança exceção', (
    tester,
  ) async {
    final f = ChamadaFormFixture();
    await f.mount(tester);
    view(tester).onSave();
    expect(f.repo.queries, hasLength(1));
    await f.disposeScreen(tester);
    f.repo.pending.single.complete([]);
    await tester.pumpAndSettle();
    expect(f.repo.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controles de filtro ficam desabilitados durante o salvamento', (
    tester,
  ) async {
    final f = ChamadaFormFixture();
    await f.mount(tester);
    view(tester).onSave();
    await tester.pump();

    final header = tester.widget<ChamadaFiltrosHeader>(
      find.byType(ChamadaFiltrosHeader),
    );
    expect(header.isSaving, isTrue);

    final markAll = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Todos Presentes'),
    );
    expect(markAll.onPressed, isNull);

    final lotDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(lotDropdown.onChanged, isNull);

    final teamDropdown = tester.widget<DropdownButtonFormField<String?>>(
      find.byType(DropdownButtonFormField<String?>),
    );
    expect(teamDropdown.onChanged, isNull);

    f.repo.pending.single.complete([]);
    await tester.pumpAndSettle();
    expect(f.repo.saved, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

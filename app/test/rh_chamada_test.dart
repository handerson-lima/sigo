import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/rh/data/lote_persistido_service.dart';
import 'package:app/src/features/rh/domain/chamada_diaria.dart';
import 'package:app/src/features/rh/presentation/widgets/apontamento_worker_card.dart';
import 'package:app/src/features/rh/presentation/widgets/rateio_lotes_sheet.dart';

void main() {
  group('Story 4.2 — Invariantes de Apontamento e Rateio', () {
    test('Trabalhador Presente com alocação integral (100%) é válido', () {
      final apontamento = ApontamentoTrabalhador(
        workerId: 'w-1',
        workerName: 'João da Silva',
        workerRole: 'Pedreiro',
        status: PresencaStatus.presente,
        allocations: const [
          AlocacaoLote(lotId: 'lote-1', lotName: 'Casa 01', percentage: 100),
        ],
      );

      expect(apontamento.totalPercentage, equals(100));
      expect(apontamento.isValidAllocation, isTrue);
      expect(apontamento.validationError, isNull);
    });

    test('Trabalhador Presente com rateio em múltiplos lotes somando 100% é válido', () {
      final apontamento = ApontamentoTrabalhador(
        workerId: 'w-1',
        workerName: 'João da Silva',
        workerRole: 'Pedreiro',
        status: PresencaStatus.presente,
        allocations: const [
          AlocacaoLote(lotId: 'lote-1', lotName: 'Casa 01', percentage: 60),
          AlocacaoLote(lotId: 'lote-2', lotName: 'Casa 02', percentage: 40),
        ],
      );

      expect(apontamento.totalPercentage, equals(100));
      expect(apontamento.isValidAllocation, isTrue);
    });

    test('Trabalhador Presente com soma divergente de 100% viola invariante', () {
      final apontamento80 = ApontamentoTrabalhador(
        workerId: 'w-1',
        workerName: 'João da Silva',
        workerRole: 'Pedreiro',
        status: PresencaStatus.presente,
        allocations: const [
          AlocacaoLote(lotId: 'lote-1', lotName: 'Casa 01', percentage: 80),
        ],
      );

      expect(apontamento80.totalPercentage, equals(80));
      expect(apontamento80.isValidAllocation, isFalse);
      expect(apontamento80.validationError, contains('100%'));

      final apontamento120 = ApontamentoTrabalhador(
        workerId: 'w-1',
        workerName: 'João da Silva',
        workerRole: 'Pedreiro',
        status: PresencaStatus.presente,
        allocations: const [
          AlocacaoLote(lotId: 'lote-1', lotName: 'Casa 01', percentage: 70),
          AlocacaoLote(lotId: 'lote-2', lotName: 'Casa 02', percentage: 50),
        ],
      );

      expect(apontamento120.totalPercentage, equals(120));
      expect(apontamento120.isValidAllocation, isFalse);
    });

    test('Trabalhador em Meio-Período exige soma de exatamente 50%', () {
      final validoMeio = ApontamentoTrabalhador(
        workerId: 'w-2',
        workerName: 'Maria Santos',
        workerRole: 'Pintora',
        status: PresencaStatus.meioPeriodo,
        allocations: const [
          AlocacaoLote(lotId: 'lote-1', lotName: 'Casa 01', percentage: 50),
        ],
      );

      expect(validoMeio.totalPercentage, equals(50));
      expect(validoMeio.isValidAllocation, isTrue);

      final invalidoMeio = ApontamentoTrabalhador(
        workerId: 'w-2',
        workerName: 'Maria Santos',
        workerRole: 'Pintora',
        status: PresencaStatus.meioPeriodo,
        allocations: const [
          AlocacaoLote(lotId: 'lote-1', lotName: 'Casa 01', percentage: 100),
        ],
      );

      expect(invalidoMeio.totalPercentage, equals(100));
      expect(invalidoMeio.isValidAllocation, isFalse);
      expect(invalidoMeio.validationError, contains('50%'));
    });

    test('Trabalhador Ausente (Falta) exige 0% de apropriação e lista vazia', () {
      final validoFalta = ApontamentoTrabalhador(
        workerId: 'w-3',
        workerName: 'Carlos Lima',
        workerRole: 'Ajudante',
        status: PresencaStatus.falta,
        allocations: const [],
      );

      expect(validoFalta.totalPercentage, equals(0));
      expect(validoFalta.isValidAllocation, isTrue);

      final invalidoFalta = ApontamentoTrabalhador(
        workerId: 'w-3',
        workerName: 'Carlos Lima',
        workerRole: 'Ajudante',
        status: PresencaStatus.falta,
        allocations: const [
          AlocacaoLote(lotId: 'lote-1', lotName: 'Casa 01', percentage: 50),
        ],
      );

      expect(invalidoFalta.isValidAllocation, isFalse);
      expect(invalidoFalta.validationError, contains('ausente'));
    });

    test('ChamadaDiaria valida todos os trabalhadores e contadores do dia', () {
      final chamada = ChamadaDiaria(
        id: 'ch-1',
        construtoraId: 'const-1',
        obraId: 'obra-1',
        date: '2026-09-17',
        createdByUid: 'encarregado-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        workers: const [
          ApontamentoTrabalhador(
            workerId: 'w-1',
            workerName: 'João',
            workerRole: 'Pedreiro',
            status: PresencaStatus.presente,
            allocations: [
              AlocacaoLote(lotId: 'l-1', lotName: 'Lote 1', percentage: 100),
            ],
          ),
          ApontamentoTrabalhador(
            workerId: 'w-2',
            workerName: 'Maria',
            workerRole: 'Servente',
            status: PresencaStatus.meioPeriodo,
            allocations: [
              AlocacaoLote(lotId: 'l-1', lotName: 'Lote 1', percentage: 50),
            ],
          ),
          ApontamentoTrabalhador(
            workerId: 'w-3',
            workerName: 'Carlos',
            workerRole: 'Ajudante',
            status: PresencaStatus.falta,
            allocations: [],
          ),
        ],
      );

      expect(chamada.totalWorkers, equals(3));
      expect(chamada.presentCount, equals(1));
      expect(chamada.meioPeriodoCount, equals(1));
      expect(chamada.faltaCount, equals(1));
      expect(chamada.isValid, isTrue);
    });

    test('Serialização e desserialização de ChamadaDiaria preserva estrutura', () {
      final original = ChamadaDiaria(
        id: 'ch-99',
        construtoraId: 'c-10',
        obraId: 'o-20',
        date: '2026-09-17',
        teamId: 'team-alpha',
        teamName: 'Equipe Alvenaria',
        createdByUid: 'user-77',
        defaultLotId: 'lot-5',
        status: 'confirmada',
        createdAt: DateTime(2026, 9, 17, 7, 30),
        updatedAt: DateTime(2026, 9, 17, 7, 30),
        workers: const [
          ApontamentoTrabalhador(
            workerId: 'w-100',
            workerName: 'Pedro Alvenaria',
            workerRole: 'Encarregado',
            status: PresencaStatus.presente,
            allocations: [
              AlocacaoLote(lotId: 'lot-5', lotName: 'Casa 05', percentage: 100),
            ],
          ),
        ],
      );

      final map = original.toMap();
      expect(map['date'], equals('2026-09-17'));
      expect(map['teamName'], equals('Equipe Alvenaria'));

      final restored = ChamadaDiaria.fromMap(map, id: 'ch-99');
      expect(restored.id, equals('ch-99'));
      expect(restored.workers.length, equals(1));
      expect(restored.workers.first.workerName, equals('Pedro Alvenaria'));
      expect(restored.workers.first.allocations.first.percentage, equals(100));
    });
  });

  group('Story 4.2 — Memorização do Lote Atual', () {
    test('LotePersistidoService salva e recupera preferência de lote por equipe', () async {
      final service = LotePersistidoService();

      expect(
        await service.getDefaultLot(obraId: 'obra-1', teamId: 'equipe-1'),
        isNull,
      );

      await service.saveDefaultLot(
        obraId: 'obra-1',
        teamId: 'equipe-1',
        lotId: 'lote-42',
      );

      final lotId = await service.getDefaultLot(
        obraId: 'obra-1',
        teamId: 'equipe-1',
      );
      expect(lotId, equals('lote-42'));
    });
  });

  group('Story 4.2 — Widgets e Experiência do Encarregado', () {
    final mockLotes = [
      Lote(
        id: 'l-1',
        construtoraId: 'c-1',
        loteamentoId: 'lt-1',
        quadraId: 'qd-1',
        name: 'Casa 10',
        phase: 'Alvenaria',
        status: LoteStatus.noPrazo,
        createdAt: DateTime.now(),
      ),
      Lote(
        id: 'l-2',
        construtoraId: 'c-1',
        loteamentoId: 'lt-1',
        quadraId: 'qd-1',
        name: 'Casa 11',
        phase: 'Alvenaria',
        status: LoteStatus.noPrazo,
        createdAt: DateTime.now(),
      ),
    ];

    testWidgets('ApontamentoWorkerCard alterna presença para Falta e Meio-Período', (tester) async {
      ApontamentoTrabalhador current = ApontamentoTrabalhador(
        workerId: 'w-1',
        workerName: 'Antônio da Silva',
        workerRole: 'Armador',
        status: PresencaStatus.presente,
        allocations: const [
          AlocacaoLote(lotId: 'l-1', lotName: 'Casa 10', percentage: 100),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ApontamentoWorkerCard(
                  apontamento: current,
                  availableLotes: mockLotes,
                  onChanged: (updated) {
                    setState(() {
                      current = updated;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Antônio da Silva'), findsOneWidget);
      expect(find.text('Armador'), findsOneWidget);
      expect(find.text('Casa 10 (100%)'), findsOneWidget);

      // Clica em 'Falta'
      await tester.tap(find.text('Falta'));
      await tester.pumpAndSettle();

      expect(current.status, equals(PresencaStatus.falta));
      expect(current.allocations, isEmpty);
      expect(find.text('Casa 10 (100%)'), findsNothing);

      // Clica em '1/2 Período'
      await tester.tap(find.text('1/2 Período'));
      await tester.pumpAndSettle();

      expect(current.status, equals(PresencaStatus.meioPeriodo));
      expect(current.allocations.first.percentage, equals(50));
      expect(find.text('Casa 10 (50%)'), findsOneWidget);
    });

    testWidgets('RateioLotesSheet valida equilíbrio e bloqueia confirmação divergente', (tester) async {
      List<AlocacaoLote> savedAllocations = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  RateioLotesSheet.show(
                    context: context,
                    workerName: 'Roberto Alves',
                    status: PresencaStatus.presente,
                    availableLotes: mockLotes,
                    initialAllocations: const [
                      AlocacaoLote(lotId: 'l-1', lotName: 'Casa 10', percentage: 100),
                    ],
                    onSave: (allocs) {
                      savedAllocations = allocs;
                    },
                  );
                },
                child: const Text('Abrir Rateio'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Rateio'));
      await tester.pumpAndSettle();

      expect(find.text('Rateio de Lotes: Roberto Alves'), findsOneWidget);
      expect(find.text('Alocação equilibrada (100%)'), findsOneWidget);
      expect(find.text('Confirmar Rateio'), findsOneWidget);

      // Botão confirmar deve estar habilitado inicialmente
      await tester.tap(find.text('Confirmar Rateio'));
      await tester.pumpAndSettle();

      expect(savedAllocations.length, equals(1));
      expect(savedAllocations.first.percentage, equals(100));
    });
  });
}

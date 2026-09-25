import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/rh/data/custo_mao_de_obra_service.dart';
import 'package:app/src/features/rh/domain/chamada_diaria.dart';
import 'package:app/src/features/rh/domain/custo_mao_de_obra.dart';
import 'package:app/src/features/rh/domain/funcionario.dart';
import 'package:app/src/features/rh/presentation/widgets/apontamento_worker_card.dart';
import 'package:app/src/features/rh/presentation/widgets/resumo_custos_chamada_dialog.dart';

void main() {
  group('Story 4.3 — Cálculo e Apropriação de Custos de Mão de Obra (Matriz I/O)', () {
    test('Cenário 1: Colaborador Presente em Lote Único (100%)', () {
      final func = Funcionario(
        id: 'f1',
        construtoraId: 'c1',
        name: 'João Pedreiro',
        cpf: '12345678909',
        role: 'Pedreiro',
        employmentType: 'clt',
        salaryBasis: 'diaria',
        baseSalaryCents: 12000, // R$ 120,00
      );

      final apontamento = const ApontamentoTrabalhador(
        workerId: 'f1',
        workerName: 'João Pedreiro',
        workerRole: 'Pedreiro',
        status: PresencaStatus.presente,
        allocations: [
          AlocacaoLote(lotId: 'lote-10', lotName: 'Lote 10', percentage: 100),
        ],
      );

      final snapshot = CustoMaoDeObraService.computeWorkerSnapshot(
        funcionario: func,
        apontamento: apontamento,
      );

      expect(snapshot.baseDailyRateCents, equals(12000));
      expect(snapshot.effectiveCostCents, equals(12000));
      expect(snapshot.lotAllocations.length, equals(1));
      expect(snapshot.lotAllocations.first.lotId, equals('lote-10'));
      expect(snapshot.lotAllocations.first.costCents, equals(12000));
    });

    test('Cenário 2: Colaborador em Meio-Período (50%)', () {
      final func = Funcionario(
        id: 'f2',
        construtoraId: 'c1',
        name: 'Maria Servente',
        cpf: '12345678909',
        role: 'Servente',
        employmentType: 'clt',
        salaryBasis: 'diaria',
        baseSalaryCents: 15000, // R$ 150,00
      );

      final apontamento = const ApontamentoTrabalhador(
        workerId: 'f2',
        workerName: 'Maria Servente',
        workerRole: 'Servente',
        status: PresencaStatus.meioPeriodo,
        allocations: [
          AlocacaoLote(lotId: 'lote-12', lotName: 'Lote 12', percentage: 50),
        ],
      );

      final snapshot = CustoMaoDeObraService.computeWorkerSnapshot(
        funcionario: func,
        apontamento: apontamento,
      );

      expect(snapshot.baseDailyRateCents, equals(15000));
      expect(snapshot.effectiveCostCents, equals(7500)); // 15000 ~/ 2
      expect(snapshot.lotAllocations.length, equals(1));
      expect(snapshot.lotAllocations.first.costCents, equals(7500));
    });

    test(
      'Cenário 3: Colaborador com Falta (0%) tem custo zero e zero apropriação',
      () {
        final func = Funcionario(
          id: 'f3',
          construtoraId: 'c1',
          name: 'Carlos Ausente',
          cpf: '12345678909',
          role: 'Ajudante',
          employmentType: 'clt',
          salaryBasis: 'diaria',
          baseSalaryCents: 18000,
        );

        final apontamento = const ApontamentoTrabalhador(
          workerId: 'f3',
          workerName: 'Carlos Ausente',
          workerRole: 'Ajudante',
          status: PresencaStatus.falta,
          allocations: [],
        );

        final snapshot = CustoMaoDeObraService.computeWorkerSnapshot(
          funcionario: func,
          apontamento: apontamento,
        );

        expect(snapshot.baseDailyRateCents, equals(18000));
        expect(snapshot.effectiveCostCents, equals(0));
        expect(snapshot.lotAllocations, isEmpty);
      },
    );

    test(
      'Cenário 4: Rateio em Múltiplos Lotes com Centavos Exatos (40% / 60%)',
      () {
        final func = Funcionario(
          id: 'f4',
          construtoraId: 'c1',
          name: 'Pedro Carpinteiro',
          cpf: '12345678909',
          role: 'Carpinteiro',
          employmentType: 'clt',
          salaryBasis: 'diaria',
          baseSalaryCents: 10000, // R$ 100,00
        );

        final apontamento = const ApontamentoTrabalhador(
          workerId: 'f4',
          workerName: 'Pedro Carpinteiro',
          workerRole: 'Carpinteiro',
          status: PresencaStatus.presente,
          allocations: [
            AlocacaoLote(lotId: 'lote-a', lotName: 'Lote A', percentage: 40),
            AlocacaoLote(lotId: 'lote-b', lotName: 'Lote B', percentage: 60),
          ],
        );

        final snapshot = CustoMaoDeObraService.computeWorkerSnapshot(
          funcionario: func,
          apontamento: apontamento,
        );

        expect(snapshot.effectiveCostCents, equals(10000));
        expect(snapshot.lotAllocations[0].costCents, equals(4000));
        expect(snapshot.lotAllocations[1].costCents, equals(6000));
        expect(
          snapshot.lotAllocations.fold<int>(0, (s, a) => s + a.costCents),
          equals(10000),
        );
      },
    );

    test('Cenário 5: Rateio em 3 Lotes com Resíduo (33% / 33% / 34%)', () {
      final func = Funcionario(
        id: 'f5',
        construtoraId: 'c1',
        name: 'Lucas Eletricista',
        cpf: '12345678909',
        role: 'Eletricista',
        employmentType: 'clt',
        salaryBasis: 'diaria',
        baseSalaryCents: 10000, // R$ 100,00
      );

      final apontamento = const ApontamentoTrabalhador(
        workerId: 'f5',
        workerName: 'Lucas Eletricista',
        workerRole: 'Eletricista',
        status: PresencaStatus.presente,
        allocations: [
          AlocacaoLote(lotId: 'l1', lotName: 'Lote 1', percentage: 33),
          AlocacaoLote(lotId: 'l2', lotName: 'Lote 2', percentage: 33),
          AlocacaoLote(lotId: 'l3', lotName: 'Lote 3', percentage: 34),
        ],
      );

      final snapshot = CustoMaoDeObraService.computeWorkerSnapshot(
        funcionario: func,
        apontamento: apontamento,
      );

      expect(snapshot.effectiveCostCents, equals(10000));
      expect(snapshot.lotAllocations[0].costCents, equals(3300));
      expect(snapshot.lotAllocations[1].costCents, equals(3300));
      expect(snapshot.lotAllocations[2].costCents, equals(3400));
      expect(
        snapshot.lotAllocations.fold<int>(0, (s, a) => s + a.costCents),
        equals(10000),
      );
    });

    test('Cenário 6: Rateio 50%/50% com Diária Ímpar (12.501 centavos) compensa resíduo', () {
      final func = Funcionario(
        id: 'f6',
        construtoraId: 'c1',
        name: 'Marcos Armador',
        cpf: '12345678909',
        role: 'Armador',
        employmentType: 'clt',
        salaryBasis: 'diaria',
        baseSalaryCents: 12501, // R$ 125,01
      );

      final apontamento = const ApontamentoTrabalhador(
        workerId: 'f6',
        workerName: 'Marcos Armador',
        workerRole: 'Armador',
        status: PresencaStatus.presente,
        allocations: [
          AlocacaoLote(lotId: 'l1', lotName: 'Lote 1', percentage: 50),
          AlocacaoLote(lotId: 'l2', lotName: 'Lote 2', percentage: 50),
        ],
      );

      final snapshot = CustoMaoDeObraService.computeWorkerSnapshot(
        funcionario: func,
        apontamento: apontamento,
      );

      expect(snapshot.effectiveCostCents, equals(12501));
      final sum = snapshot.lotAllocations.fold<int>(
        0,
        (s, a) => s + a.costCents,
      );
      expect(sum, equals(12501)); // Conservação rigorosa de centavos
      expect(
        snapshot.lotAllocations[0].costCents,
        equals(6251),
      ); // Recebe o centavo residual
      expect(snapshot.lotAllocations[1].costCents, equals(6250));
    });

    test('Cenário 7: Imutabilidade de Snapshots frente a reajuste cadastral posterior', () {
      final funcInicial = Funcionario(
        id: 'f7',
        construtoraId: 'c1',
        name: 'Tiago Encanador',
        cpf: '12345678909',
        role: 'Encanador',
        employmentType: 'clt',
        salaryBasis: 'mensal',
        baseSalaryCents: 300000, // R$ 3.000,00 -> Diária 10.000
      );

      final apontamento = const ApontamentoTrabalhador(
        workerId: 'f7',
        workerName: 'Tiago Encanador',
        workerRole: 'Encanador',
        status: PresencaStatus.presente,
        allocations: [
          AlocacaoLote(lotId: 'l1', lotName: 'Lote 1', percentage: 100),
        ],
      );

      final snapshotHistorico = CustoMaoDeObraService.computeWorkerSnapshot(
        funcionario: funcInicial,
        apontamento: apontamento,
      );

      // Chamada é fechada com o snapshot
      final chamadaFechada = ChamadaDiaria(
        id: 'ch-1',
        construtoraId: 'c1',
        obraId: 'o1',
        date: '2026-09-17',
        createdByUid: 'u1',
        workers: [apontamento],
        totalDayCostCents: snapshotHistorico.effectiveCostCents,
        costSnapshots: [snapshotHistorico],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 15 dias depois o colaborador recebe reajuste no cadastro corporativo:
      final funcReajustado = funcInicial.copyWith(
        baseSalaryCents: 450000, // R$ 4.500,00 -> Diária 15.000
      );

      // A chamada histórica fechada NÃO sofreu alteração:
      expect(chamadaFechada.totalDayCostCents, equals(10000));
      expect(
        chamadaFechada.costSnapshots.first.effectiveCostCents,
        equals(10000),
      );
      expect(
        chamadaFechada.costSnapshots.first.baseSalaryCents,
        equals(300000),
      );

      // Um novo cálculo com o cadastro reajustado gera 15000, mas o histórico permanece blindado
      final snapshotNovo = CustoMaoDeObraService.computeWorkerSnapshot(
        funcionario: funcReajustado,
        apontamento: apontamento,
      );
      expect(snapshotNovo.effectiveCostCents, equals(15000));
    });

    test(
      'Cenário 8: Divisor Personalizado da Obra (22 dias úteis vs. padrão 30)',
      () {
        final funcMensal = Funcionario(
          id: 'f8',
          construtoraId: 'c1',
          name: 'Ana Engenheira',
          cpf: '12345678909',
          role: 'Engenheira',
          employmentType: 'clt',
          salaryBasis: 'mensal',
          baseSalaryCents: 220000, // R$ 2.200,00
          additionalCostsCents: 0,
        );

        final apontamento = const ApontamentoTrabalhador(
          workerId: 'f8',
          workerName: 'Ana Engenheira',
          workerRole: 'Engenheira',
          status: PresencaStatus.presente,
          allocations: [
            AlocacaoLote(lotId: 'l1', lotName: 'Lote 1', percentage: 100),
          ],
        );

        // Política padrão de 30 dias
        final snapshotPadrao = CustoMaoDeObraService.computeWorkerSnapshot(
          funcionario: funcMensal,
          apontamento: apontamento,
          policy: const CostPolicy(monthlyDivisor: 30),
        );
        expect(
          snapshotPadrao.baseDailyRateCents,
          equals(220000 ~/ 30),
        ); // 7333 centavos

        // Política com 22 dias úteis
        final snapshotUteis = CustoMaoDeObraService.computeWorkerSnapshot(
          funcionario: funcMensal,
          apontamento: apontamento,
          policy: const CostPolicy(monthlyDivisor: 22, version: 'v1'),
        );
        expect(
          snapshotUteis.baseDailyRateCents,
          equals(10000),
        ); // R$ 100,00 exatos (220000 ~/ 22)
        expect(snapshotUteis.effectiveCostCents, equals(10000));
      },
    );

    test('Cenário 9: Consolidação por Lote em Chamada Completa (computeChamadaCosts)', () {
      final f1 = Funcionario(
        id: 'f1',
        construtoraId: 'c1',
        name: 'Operário 1',
        cpf: '111',
        role: 'Pedreiro',
        employmentType: 'clt',
        salaryBasis: 'diaria',
        baseSalaryCents: 10000, // R$ 100,00
      );
      final f2 = Funcionario(
        id: 'f2',
        construtoraId: 'c1',
        name: 'Operário 2',
        cpf: '222',
        role: 'Servente',
        employmentType: 'clt',
        salaryBasis: 'diaria',
        baseSalaryCents: 6000, // R$ 60,00
      );

      final ap1 = const ApontamentoTrabalhador(
        workerId: 'f1',
        workerName: 'Operário 1',
        workerRole: 'Pedreiro',
        status: PresencaStatus.presente,
        allocations: [
          AlocacaoLote(lotId: 'l10', lotName: 'Lote 10', percentage: 50),
          AlocacaoLote(lotId: 'l20', lotName: 'Lote 20', percentage: 50),
        ],
      );

      final ap2 = const ApontamentoTrabalhador(
        workerId: 'f2',
        workerName: 'Operário 2',
        workerRole: 'Servente',
        status: PresencaStatus.meioPeriodo, // 50% de 6000 = 3000
        allocations: [
          AlocacaoLote(lotId: 'l10', lotName: 'Lote 10', percentage: 50),
        ],
      );

      final result = CustoMaoDeObraService.computeChamadaCosts(
        funcionarios: [f1, f2],
        apontamentos: [ap1, ap2],
      );

      // Operário 1: 5000 no Lote 10 e 5000 no Lote 20 (Total 10000)
      // Operário 2: 3000 no Lote 10 (Total 3000)
      // Total dia: 13000
      expect(result.totalDayCostCents, equals(13000));
      expect(result.costSnapshots.length, equals(2));

      // Lote 10: 5000 + 3000 = 8000 (2 colaboradores)
      final lote10 = result.lotCostSummaries.firstWhere(
        (l) => l.lotId == 'l10',
      );
      expect(lote10.totalCostCents, equals(8000));
      expect(lote10.workerCount, equals(2));

      // Lote 20: 5000 (1 colaborador)
      final lote20 = result.lotCostSummaries.firstWhere(
        (l) => l.lotId == 'l20',
      );
      expect(lote20.totalCostCents, equals(5000));
      expect(lote20.workerCount, equals(1));

      // Soma dos lotes bate rigorosamente com o total do dia
      final sumLots = result.lotCostSummaries.fold<int>(
        0,
        (s, l) => s + l.totalCostCents,
      );
      expect(sumLots, equals(result.totalDayCostCents));
    });

    test('Cenário 10: Serialização e desserialização de ChamadaDiaria com snapshots', () {
      final policy = const CostPolicy(version: 'v1', monthlyDivisor: 22);
      final workerSnapshot = const WorkerCostSnapshot(
        workerId: 'w1',
        workerName: 'Trabalhador 1',
        workerRole: 'Pedreiro',
        salaryBasis: 'mensal',
        baseSalaryCents: 220000,
        additionalCostsCents: 0,
        baseDailyRateCents: 10000,
        effectiveCostCents: 10000,
        status: 'presente',
        lotAllocations: [
          LotCostAllocationSnapshot(
            lotId: 'l1',
            lotName: 'Lote 1',
            percentage: 100,
            costCents: 10000,
          ),
        ],
      );
      final lotSummary = const LotCostSummary(
        lotId: 'l1',
        lotName: 'Lote 1',
        totalCostCents: 10000,
        workerCount: 1,
      );

      final chamada = ChamadaDiaria(
        id: 'ch-100',
        construtoraId: 'c1',
        obraId: 'o1',
        date: '2026-09-17',
        createdByUid: 'u1',
        workers: const [
          ApontamentoTrabalhador(
            workerId: 'w1',
            workerName: 'Trabalhador 1',
            workerRole: 'Pedreiro',
            status: PresencaStatus.presente,
            allocations: [
              AlocacaoLote(lotId: 'l1', lotName: 'Lote 1', percentage: 100),
            ],
          ),
        ],
        totalDayCostCents: 10000,
        costPolicyVersion: 'v1',
        costPolicy: policy,
        costSnapshots: [workerSnapshot],
        lotCostSummaries: [lotSummary],
        createdAt: DateTime(2026, 9, 17, 8),
        updatedAt: DateTime(2026, 9, 17, 17),
      );

      final map = chamada.toMap();
      expect(map['totalDayCostCents'], equals(10000));
      expect(map['costPolicyVersion'], equals('v1'));
      expect(map['costPolicy']['monthlyDivisor'], equals(22));
      expect((map['costSnapshots'] as List).length, equals(1));
      expect((map['lotCostSummaries'] as List).length, equals(1));

      final restored = ChamadaDiaria.fromMap(map, id: 'ch-100');
      expect(restored.totalDayCostCents, equals(10000));
      expect(restored.costPolicy?.monthlyDivisor, equals(22));
      expect(restored.costSnapshots.first.effectiveCostCents, equals(10000));
      expect(restored.lotCostSummaries.first.totalCostCents, equals(10000));
    });
  });

  group('Story 4.3 — Widgets e Apresentação de Custos', () {
    testWidgets(
      'ApontamentoWorkerCard exibe taxa diária base e custo efetivo dinâmico',
      (tester) async {
        final worker = const ApontamentoTrabalhador(
          workerId: 'w1',
          workerName: 'Carlos Teste',
          workerRole: 'Carpinteiro',
          status: PresencaStatus.presente,
          allocations: [
            AlocacaoLote(lotId: 'l1', lotName: 'Lote 1', percentage: 100),
          ],
        );

        final lotes = [
          Lote(
            id: 'l1',
            construtoraId: 'c1',
            loteamentoId: 'lt1',
            quadraId: 'qd1',
            name: 'Lote 1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ApontamentoWorkerCard(
                apontamento: worker,
                availableLotes: lotes,
                baseDailyRateCents: 14000, // R$ 140,00
                onChanged: (_) {},
              ),
            ),
          ),
        );

        // Deve exibir o nome do colaborador, a taxa diária base e o valor efetivo formatado
        expect(find.text('Carlos Teste'), findsOneWidget);
        expect(find.text('R\$ 140,00/dia'), findsOneWidget);
        expect(
          find.text('R\$ 140,00'),
          findsOneWidget,
        ); // Badge de presente (100%)
      },
    );

    testWidgets('ResumoCustosChamadaDialog renderiza resumo total e por lote', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ResumoCustosChamadaDialog.show(
                      context: context,
                      totalDayCostCents: 24000,
                      date: '2026-09-17',
                      lotCostSummaries: const [
                        LotCostSummary(
                          lotId: 'l1',
                          lotName: 'Lote 1',
                          totalCostCents: 14000,
                          workerCount: 1,
                        ),
                        LotCostSummary(
                          lotId: 'l2',
                          lotName: 'Lote 2',
                          totalCostCents: 10000,
                          workerCount: 1,
                        ),
                      ],
                      costSnapshots: const [
                        WorkerCostSnapshot(
                          workerId: 'w1',
                          workerName: 'Carlos',
                          workerRole: 'Carpinteiro',
                          salaryBasis: 'diaria',
                          baseSalaryCents: 14000,
                          additionalCostsCents: 0,
                          baseDailyRateCents: 14000,
                          effectiveCostCents: 14000,
                          status: 'presente',
                        ),
                      ],
                    );
                  },
                  child: const Text('Abrir Resumo'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Resumo'));
      await tester.pumpAndSettle();

      expect(find.text('Fechamento Financeiro'), findsOneWidget);
      expect(find.text('R\$ 240,00'), findsOneWidget); // Total
      expect(find.text('Lote 1'), findsOneWidget);
      expect(
        find.text('R\$ 140,00'),
        findsNWidgets(2),
      ); // Aparece no lote e no operário
      expect(find.text('Lote 2'), findsOneWidget);
      expect(find.text('R\$ 100,00'), findsOneWidget);
    });
  });
}

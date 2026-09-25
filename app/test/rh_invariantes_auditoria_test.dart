import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/rh/domain/chamada_audit_entry.dart';
import 'package:app/src/features/rh/domain/chamada_diaria.dart';
import 'package:app/src/features/rh/domain/chamada_status.dart';
import 'package:app/src/features/rh/domain/rh_invariante_validator.dart';
import 'package:app/src/features/rh/presentation/widgets/chamada_audit_timeline_dialog.dart';
import 'package:app/src/features/rh/presentation/widgets/retificacao_chamada_dialog.dart';

void main() {
  group('Story 4.4 — RH: Validação de Invariantes e Auditoria', () {
    group('1. Invariantes de Presença e Alocação de Lotes (RhInvarianteValidator)', () {
      test('Presente com 100% em lotes válidos é aceito', () {
        const ap = ApontamentoTrabalhador(
          workerId: 'w1',
          workerName: 'João Silva',
          workerRole: 'Pedreiro',
          status: PresencaStatus.presente,
          allocations: [
            AlocacaoLote(lotId: 'l1', lotName: 'Fundação', percentage: 100),
          ],
        );

        final erros = RhInvarianteValidator.validarApontamento(ap);
        expect(erros, isEmpty);
      });

      test('Presente com menos de 100% de alocação é rejeitado com mensagem descritiva', () {
        const ap = ApontamentoTrabalhador(
          workerId: 'w1',
          workerName: 'João Silva',
          workerRole: 'Pedreiro',
          status: PresencaStatus.presente,
          allocations: [
            AlocacaoLote(lotId: 'l1', lotName: 'Fundação', percentage: 80),
          ],
        );

        final erros = RhInvarianteValidator.validarApontamento(ap);
        expect(erros, hasLength(1));
        expect(erros.first, contains('somar exatamente 100%'));
        expect(erros.first, contains('atual: 80%'));
      });

      test('Presente sem lotes alocados é rejeitado', () {
        const ap = ApontamentoTrabalhador(
          workerId: 'w1',
          workerName: 'João Silva',
          workerRole: 'Pedreiro',
          status: PresencaStatus.presente,
          allocations: [],
        );

        final erros = RhInvarianteValidator.validarApontamento(ap);
        expect(erros, hasLength(1));
        expect(erros.first, contains('ao menos 1 lote alocado'));
      });

      test('Meio-período com exatamente 50% de alocação é aceito', () {
        const ap = ApontamentoTrabalhador(
          workerId: 'w2',
          workerName: 'Carlos Souza',
          workerRole: 'Ajudante',
          status: PresencaStatus.meioPeriodo,
          allocations: [
            AlocacaoLote(lotId: 'l1', lotName: 'Fundação', percentage: 50),
          ],
        );

        final erros = RhInvarianteValidator.validarApontamento(ap);
        expect(erros, isEmpty);
      });

      test('Meio-período com 100% de alocação é rejeitado', () {
        const ap = ApontamentoTrabalhador(
          workerId: 'w2',
          workerName: 'Carlos Souza',
          workerRole: 'Ajudante',
          status: PresencaStatus.meioPeriodo,
          allocations: [
            AlocacaoLote(lotId: 'l1', lotName: 'Fundação', percentage: 100),
          ],
        );

        final erros = RhInvarianteValidator.validarApontamento(ap);
        expect(erros, hasLength(1));
        expect(erros.first, contains('somar exatamente 50%'));
        expect(erros.first, contains('atual: 100%'));
      });

      test('Falta com lote alocado é estritamente rejeitado', () {
        const ap = ApontamentoTrabalhador(
          workerId: 'w3',
          workerName: 'Marcos Dias',
          workerRole: 'Eletricista',
          status: PresencaStatus.falta,
          allocations: [
            AlocacaoLote(lotId: 'l1', lotName: 'Fundação', percentage: 100),
          ],
        );

        final erros = RhInvarianteValidator.validarApontamento(ap);
        expect(erros, hasLength(1));
        expect(erros.first, contains('não pode ter lotes alocados'));
      });

      test('Falta sem lotes alocados é aceita', () {
        const ap = ApontamentoTrabalhador(
          workerId: 'w3',
          workerName: 'Marcos Dias',
          workerRole: 'Eletricista',
          status: PresencaStatus.falta,
          allocations: [],
        );

        final erros = RhInvarianteValidator.validarApontamento(ap);
        expect(erros, isEmpty);
      });
    });

    group('2. Unicidade Nominal e Validação de Lotes da Obra', () {
      test('Detecta colaborador duplicado na lista de apontamentos', () {
        const workers = [
          ApontamentoTrabalhador(
            workerId: 'w1',
            workerName: 'João Silva',
            workerRole: 'Pedreiro',
            status: PresencaStatus.presente,
            allocations: [
              AlocacaoLote(lotId: 'l1', lotName: 'Fundação', percentage: 100),
            ],
          ),
          ApontamentoTrabalhador(
            workerId: 'w1',
            workerName: 'João Silva',
            workerRole: 'Pedreiro',
            status: PresencaStatus.falta,
            allocations: [],
          ),
        ];

        final erros = RhInvarianteValidator.validarChamada(
          apontamentos: workers,
        );

        expect(erros, anyElement(contains('Colaborador duplicado na chamada')));
      });

      test('Detecta lote que não pertence à obra', () {
        const workers = [
          ApontamentoTrabalhador(
            workerId: 'w1',
            workerName: 'João Silva',
            workerRole: 'Pedreiro',
            status: PresencaStatus.presente,
            allocations: [
              AlocacaoLote(lotId: 'lote_alienigena', lotName: 'Outra Obra', percentage: 100),
            ],
          ),
        ];

        final erros = RhInvarianteValidator.validarChamada(
          apontamentos: workers,
          lotesValidosDaObra: {'l1', 'l2'},
        );

        expect(erros, anyElement(contains('não pertencente ao loteamento')));
      });
    });

    group('3. Validação de Conflito Cross-Obra no Mesmo Dia', () {
      test('Bloqueia apontamento quando colaborador já está 100% em outra obra', () {
        final conflito = RhInvarianteValidator.validarConflitoCrossObra(
          workerId: 'w1',
          workerName: 'João Silva',
          statusNovo: PresencaStatus.presente,
          statusExistenteEmOutraObra: PresencaStatus.presente,
          nomeOutraObra: 'Residencial Aurora',
        );

        expect(conflito, isNotNull);
        expect(conflito, contains('tempo integral (100%) no loteamento "Residencial Aurora"'));
      });

      test('Bloqueia tempo integral quando colaborador já tem meio-período (50%) em outra obra', () {
        final conflito = RhInvarianteValidator.validarConflitoCrossObra(
          workerId: 'w1',
          workerName: 'João Silva',
          statusNovo: PresencaStatus.presente,
          statusExistenteEmOutraObra: PresencaStatus.meioPeriodo,
          nomeOutraObra: 'Residencial Aurora',
        );

        expect(conflito, isNotNull);
        expect(conflito, contains('excederia o limite diário de 100%'));
      });

      test('Permite meio-período quando colaborador tem meio-período em outra obra (50% + 50% = 100%)', () {
        final conflito = RhInvarianteValidator.validarConflitoCrossObra(
          workerId: 'w1',
          workerName: 'João Silva',
          statusNovo: PresencaStatus.meioPeriodo,
          statusExistenteEmOutraObra: PresencaStatus.meioPeriodo,
          nomeOutraObra: 'Residencial Aurora',
        );

        expect(conflito, isNull);
      });

      test('Permite qualquer apontamento se na outra obra o colaborador foi marcado com Falta', () {
        final conflito = RhInvarianteValidator.validarConflitoCrossObra(
          workerId: 'w1',
          workerName: 'João Silva',
          statusNovo: PresencaStatus.presente,
          statusExistenteEmOutraObra: PresencaStatus.falta,
          nomeOutraObra: 'Residencial Aurora',
        );

        expect(conflito, isNull);
      });
    });

    group('4. Entidades de Auditoria e Imutabilidade (ChamadaAuditEntry & ChamadaDiaria)', () {
      test('ChamadaAuditEntry serializa e desserializa perfeitamente', () {
        final entry = ChamadaAuditEntry(
          id: 'audit-1',
          userId: 'usr-123',
          userName: 'Engenheiro Chefe',
          timestamp: DateTime(2026, 9, 17, 18, 30),
          motivo: 'Ajuste no lote de alocação do operário João',
          totalCostCentsAnterior: 150000,
          totalCostCentsNovo: 160000,
          versaoAnterior: 1,
          snapshotAnterior: {'status': 'fechada', 'total': 150000},
        );

        final map = entry.toMap();
        final from = ChamadaAuditEntry.fromMap(map);

        expect(from.id, equals('audit-1'));
        expect(from.userName, equals('Engenheiro Chefe'));
        expect(from.motivo, equals('Ajuste no lote de alocação do operário João'));
        expect(from.totalCostCentsAnterior, equals(150000));
        expect(from.totalCostCentsNovo, equals(160000));
        expect(from.versaoAnterior, equals(1));
        expect(from.snapshotAnterior, isNotNull);
      });

      test('ChamadaDiaria suporta status fechada e retificada com trilha de auditoria', () {
        final agora = DateTime.now();
        final audit = ChamadaAuditEntry(
          id: 'audit-1',
          userId: 'usr-1',
          userName: 'Admin',
          timestamp: agora,
          motivo: 'Retificação de horas e lotes',
          totalCostCentsAnterior: 100000,
          totalCostCentsNovo: 120000,
          versaoAnterior: 1,
        );

        final chamada = ChamadaDiaria(
          id: 'ch-1',
          construtoraId: 'c1',
          obraId: 'o1',
          date: '2026-09-17',
          createdByUid: 'usr-1',
          status: 'retificada',
          versaoAuditoria: 2,
          auditTrail: [audit],
          retificadoPor: 'Admin',
          retificadoEm: agora,
          motivoRetificacao: 'Retificação de horas e lotes',
          createdAt: agora,
          updatedAt: agora,
          workers: const [
            ApontamentoTrabalhador(
              workerId: 'w1',
              workerName: 'Pedro',
              workerRole: 'Pedreiro',
              status: PresencaStatus.presente,
              allocations: [
                AlocacaoLote(lotId: 'l1', lotName: 'Lote 1', percentage: 100),
              ],
            ),
          ],
        );

        expect(chamada.isRetificada, isTrue);
        expect(chamada.chamadaStatus, equals(ChamadaStatus.retificada));
        expect(chamada.versaoAuditoria, equals(2));
        expect(chamada.auditTrail, hasLength(1));
        expect(chamada.isValid, isTrue);

        final map = chamada.toMap();
        final reconstructed = ChamadaDiaria.fromMap(map);

        expect(reconstructed.status, equals('retificada'));
        expect(reconstructed.isRetificada, isTrue);
        expect(reconstructed.versaoAuditoria, equals(2));
        expect(reconstructed.auditTrail, hasLength(1));
        expect(reconstructed.retificadoPor, equals('Admin'));
      });
    });

    group('5. Diálogos de Interface e Governança', () {
      testWidgets('RetificacaoChamadaDialog exige justificativa com ao menos 10 caracteres',
          (tester) async {
        String? resultado;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    resultado = await showDialog<String>(
                      context: context,
                      builder: (_) => const RetificacaoChamadaDialog(
                        totalCostCentsAnterior: 100000,
                        totalCostCentsNovo: 120000,
                      ),
                    );
                  },
                  child: const Text('Abrir Diálogo'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Diálogo'));
        await tester.pumpAndSettle();

        expect(find.text('Retificação de Chamada'), findsOneWidget);
        expect(find.text('Custo Anterior:'), findsOneWidget);
        expect(find.text('Novo Custo:'), findsOneWidget);

        final botaoConfirmar = find.widgetWithText(FilledButton, 'Confirmar Retificação');
        expect(tester.widget<FilledButton>(botaoConfirmar).onPressed, isNull);

        // Digitar motivo curto (< 10 chars)
        await tester.enterText(find.byType(TextFormField), 'Curto');
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(botaoConfirmar).onPressed, isNull);

        // Digitar motivo válido (>= 10 chars)
        await tester.enterText(
          find.byType(TextFormField),
          'Correção na alocação de lotes do operário',
        );
        await tester.pumpAndSettle();

        expect(tester.widget<FilledButton>(botaoConfirmar).onPressed, isNotNull);

        await tester.tap(botaoConfirmar);
        await tester.pumpAndSettle();

        expect(resultado, equals('Correção na alocação de lotes do operário'));
      });

      testWidgets('ChamadaAuditTimelineDialog renderiza linha do tempo de retificações',
          (tester) async {
        final agora = DateTime(2026, 9, 17, 14, 0);
        final entry = ChamadaAuditEntry(
          id: 'aud-1',
          userId: 'usr-1',
          userName: 'Engenheiro Responsável',
          timestamp: agora,
          motivo: 'Ajuste de lote após conferência do mestre de obras',
          totalCostCentsAnterior: 200000,
          totalCostCentsNovo: 195000,
          versaoAnterior: 1,
        );

        final chamada = ChamadaDiaria(
          id: 'ch-1',
          construtoraId: 'c1',
          obraId: 'o1',
          date: '2026-09-17',
          createdByUid: 'usr-1',
          status: 'retificada',
          versaoAuditoria: 2,
          auditTrail: [entry],
          createdAt: agora,
          updatedAt: agora,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChamadaAuditTimelineDialog(chamada: chamada),
            ),
          ),
        );

        expect(find.text('Trilha de Auditoria'), findsOneWidget);
        expect(find.text('Revisão v1 ➔ v2'), findsOneWidget);
        expect(find.text('Por: Engenheiro Responsável'), findsOneWidget);
        expect(
          find.text('Motivo: "Ajuste de lote após conferência do mestre de obras"'),
          findsOneWidget,
        );
        expect(find.text('Δ -R\$ 50,00'), findsOneWidget);
      });
    });
  });
}

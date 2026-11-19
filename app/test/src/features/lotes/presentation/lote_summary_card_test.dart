import 'package:app/src/design_system/sigo_theme.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/lote_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Lote _buildLote({
  String name = 'Lote 31',
  String? logradouro = 'Rua Sandoval Wanderley, s/n',
  double? frenteM = 10.0,
  double? profundidadeM = 20.0,
  double? areaTerrenoM2 = 200.0,
  double? areaConstruidaM2 = 49.96,
  int progressoPercentual = 60,
  int etapasConcluidasCount = 3,
  Map<String, String>? statusEtapasMap,
  List<Map<String, dynamic>> equipesVinculadas = const [],
  List<Map<String, dynamic>> funcionariosVinculados = const [],
}) {
  final now = DateTime(2026, 10, 1);
  return Lote(
    id: 'lote-31',
    construtoraId: 'c1',
    loteamentoId: 'lt1',
    quadraId: 'q28',
    name: name,
    logradouro: logradouro,
    frenteM: frenteM,
    profundidadeM: profundidadeM,
    areaTerrenoM2: areaTerrenoM2,
    areaConstruidaM2: areaConstruidaM2,
    progressoPercentual: progressoPercentual,
    etapasConcluidasCount: etapasConcluidasCount,
    statusEtapasMap:
        statusEtapasMap ??
        const {
          'muro': EtapaStatus.concluida,
          'cinza1': EtapaStatus.concluida,
          'cinza2': EtapaStatus.concluida,
          'cinza3': EtapaStatus.emAndamento,
          'branca': EtapaStatus.pendente,
        },
    equipesVinculadas: equipesVinculadas,
    funcionariosVinculados: funcionariosVinculados,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('LoteSummaryCard', () {
    testWidgets(
      'exibe nome, logradouro, medidas, progresso, 5 etapas e alocacoes',
      (tester) async {
        var tapped = false;
        var atribuirTapped = false;

        final lote = _buildLote(
          equipesVinculadas: const [
            {'id': 'eq1', 'name': 'Equipe Alvenaria A'},
          ],
          funcionariosVinculados: const [
            {'id': 'fn1', 'name': 'João Silva', 'role': 'Pedreiro'},
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: SigoTheme.lightTheme,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LoteSummaryCard(
                  lote: lote,
                  isAdmin: true,
                  onTap: () => tapped = true,
                  onAtribuirTap: () => atribuirTapped = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Lote 31'), findsOneWidget);
        expect(find.text('Rua Sandoval Wanderley, s/n'), findsOneWidget);
        expect(find.text('Em andamento • 60%'), findsOneWidget);
        expect(find.text('10m × 20m'), findsOneWidget);
        expect(find.text('Terreno: 200 m²'), findsOneWidget);
        expect(find.text('Construída: 49,96 m²'), findsOneWidget);
        expect(find.text('Conclusão das Etapas (3/5)'), findsOneWidget);
        expect(find.text('60%'), findsOneWidget);

        // Indicadores das 5 etapas
        expect(find.text('Muro'), findsOneWidget);
        expect(find.text('1ª'), findsOneWidget);
        expect(find.text('2ª'), findsOneWidget);
        expect(find.text('3ª'), findsOneWidget);
        expect(find.text('Branca'), findsOneWidget);

        // Resumo de alocações
        expect(
          find.text('Equipe Alvenaria A • João Silva (Pedreiro)'),
          findsOneWidget,
        );

        // Botão + Atribuir visível para admin
        final atribuirBtn = find.byKey(const Key('lote_card_atribuir_lote-31'));
        expect(atribuirBtn, findsOneWidget);
        await tester.tap(atribuirBtn);
        expect(atribuirTapped, isTrue);
        expect(tapped, isFalse);

        // Clique no card aciona onTap
        await tester.tap(find.text('Lote 31'));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'oculta botao Atribuir para nao-admin e exibe estado concluido/pendente',
      (tester) async {
        final lotePendente = _buildLote(
          name: 'Lote 01',
          logradouro: null,
          frenteM: null,
          profundidadeM: null,
          areaTerrenoM2: null,
          areaConstruidaM2: null,
          progressoPercentual: 0,
          etapasConcluidasCount: 0,
          statusEtapasMap: defaultLoteStatusEtapasMap,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: SigoTheme.lightTheme,
            home: Scaffold(
              body: LoteSummaryCard(
                lote: lotePendente,
                isAdmin: false,
                onAtribuirTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Pendente • 0%'), findsOneWidget);
        expect(
          find.text('Sem equipe ou funcionário vinculado'),
          findsOneWidget,
        );
        expect(find.text('Atribuir'), findsNothing);

        final loteConcluido = _buildLote(
          name: 'Lote 99',
          progressoPercentual: 100,
          etapasConcluidasCount: 5,
          statusEtapasMap: const {
            'muro': EtapaStatus.concluida,
            'cinza1': EtapaStatus.concluida,
            'cinza2': EtapaStatus.concluida,
            'cinza3': EtapaStatus.concluida,
            'branca': EtapaStatus.concluida,
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: SigoTheme.lightTheme,
            home: Scaffold(body: LoteSummaryCard(lote: loteConcluido)),
          ),
        );

        expect(find.text('Concluído • 100%'), findsOneWidget);
        expect(find.text('Conclusão das Etapas (5/5)'), findsOneWidget);
      },
    );
  });
}

import 'package:app/src/design_system/sigo_theme.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:app/src/features/quadras/presentation/quadra_summary_card.dart';
import 'package:app/src/features/quadras/presentation/quadra_summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Quadra _makeQuadra({
  String id = 'q1',
  String name = 'Quadra 28',
  String? logradouroPadrao,
}) => Quadra(
  id: id,
  construtoraId: 'c1',
  loteamentoId: 'l1',
  name: name,
  logradouroPadrao: logradouroPadrao,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Widget _wrap(Widget child) => MaterialApp(
  theme: SigoTheme.lightTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('QuadraSummaryCard', () {
    testWidgets('renderiza logradouro, progresso e pílulas de métricas mistas', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          QuadraSummaryCard(
            quadra: _makeQuadra(
              name: 'Quadra 28',
              logradouroPadrao: 'Rua Sandoval Wanderley, s/n',
            ),
            summary: const QuadraSummary(
              totalLotes: 12,
              concluidos: 7,
              emAndamento: 3,
              pendentes: 2,
              progressoMedio: 60,
            ),
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.signpost_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      expect(find.text('Quadra 28'), findsOneWidget);
      expect(find.text('Rua Sandoval Wanderley, s/n'), findsOneWidget);
      expect(find.text('Sem logradouro padrão'), findsNothing);

      expect(find.text('Em andamento • 60%'), findsOneWidget);
      expect(find.text('12 lotes'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, closeTo(0.60, 0.001));
      expect(progressBar.minHeight, 6);

      expect(find.text('7 concl.'), findsOneWidget);
      expect(find.text('3 andam.'), findsOneWidget);
      expect(find.text('2 pend.'), findsOneWidget);
      expect(find.text('Abrir lotes'), findsNothing);
    });

    testWidgets('renderiza estado sem logradouro e sem lotes com fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          QuadraSummaryCard(
            quadra: _makeQuadra(name: 'Quadra 1', logradouroPadrao: '   '),
            summary: null,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Quadra 1'), findsOneWidget);
      expect(find.text('Sem logradouro padrão'), findsOneWidget);
      expect(find.text('Sem lotes'), findsOneWidget);
      expect(find.text('0 lotes cadastrados'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Abrir lotes'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('renderiza estado 100% concluída com contagem singular', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          QuadraSummaryCard(
            quadra: _makeQuadra(
              name: 'Quadra A',
              logradouroPadrao: 'Av. Principal',
            ),
            summary: const QuadraSummary(
              totalLotes: 1,
              concluidos: 1,
              emAndamento: 0,
              pendentes: 0,
              progressoMedio: 100,
            ),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Concluída • 100%'), findsOneWidget);
      expect(find.text('1 lote'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('1 concl.'), findsOneWidget);
      expect(find.textContaining('andam.'), findsNothing);
      expect(find.textContaining('pend.'), findsNothing);
      expect(find.text('Abrir lotes'), findsNothing);
    });

    testWidgets('renderiza estado pendente quando há lotes com 0% progresso', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          QuadraSummaryCard(
            quadra: _makeQuadra(name: 'Quadra B'),
            summary: const QuadraSummary(
              totalLotes: 4,
              concluidos: 0,
              emAndamento: 0,
              pendentes: 4,
              progressoMedio: 0,
            ),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Pendente • 0%'), findsOneWidget);
      expect(find.text('4 lotes'), findsOneWidget);
      expect(find.text('4 pend.'), findsOneWidget);
      expect(find.textContaining('concl.'), findsNothing);
      expect(find.textContaining('andam.'), findsNothing);
    });

    testWidgets('dispara onTap ao clicar no card', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          QuadraSummaryCard(
            quadra: _makeQuadra(name: 'Quadra Clique'),
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(QuadraSummaryCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('aggregateQuadraSummaries', () {
    test('agrupa lotes por quadraId e calcula status e progresso médio', () {
      final result = aggregateQuadraSummaries([
        {
          'quadraId': 'q1',
          'progressoPercentual': 100,
          'etapasConcluidasCount': 5,
          'etapasTotalCount': 5,
        },
        {
          'quadraId': 'q1',
          'progressoPercentual': 50,
          'etapasConcluidasCount': 2,
          'etapasTotalCount': 5,
        },
        {
          'quadraId': 'q1',
          'progressoPercentual': 0,
          'etapasConcluidasCount': 0,
          'etapasTotalCount': 5,
          'statusEtapasMap': {'muro': 'em_andamento'},
        },
        {
          'quadraId': 'q1',
          'progressoPercentual': 0,
          'etapasConcluidasCount': 0,
          'etapasTotalCount': 5,
        },
        {
          'quadraId': 'q2',
          'progressoPercentual': 100,
          'etapasConcluidasCount': 5,
          'etapasTotalCount': 5,
        },
        {'quadraId': '   ', 'progressoPercentual': 80},
      ]);

      expect(result.keys, containsAll(['q1', 'q2']));
      expect(result.length, 2);

      expect(
        result['q1'],
        const QuadraSummary(
          totalLotes: 4,
          concluidos: 1,
          emAndamento: 2,
          pendentes: 1,
          progressoMedio: 38,
        ),
      );
      expect(
        result['q2'],
        const QuadraSummary(
          totalLotes: 1,
          concluidos: 1,
          emAndamento: 0,
          pendentes: 0,
          progressoMedio: 100,
        ),
      );
    });
  });
}

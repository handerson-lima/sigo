import 'dart:async';

import 'package:app/src/common_widgets/sigo_error_state.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/widgets/lote_hierarchy_selector.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget build({
    required Stream<List<Loteamento>> loteamentos,
    Stream<List<Quadra>>? quadras,
    Stream<List<Lote>>? lotes,
    String? loteamentoId,
    String? quadraId,
  }) {
    return ProviderScope(
      overrides: [
        watchLoteamentosProvider.overrideWith((ref, arg) => loteamentos),
        if (quadras != null)
          watchQuadrasProvider.overrideWith((ref, arg) => quadras),
        if (lotes != null) watchLotesProvider.overrideWith((ref, arg) => lotes),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LoteHierarchySelector(
              construtoraId: 'c1',
              loteamentoId: loteamentoId,
              quadraId: quadraId,
              loteId: null,
              onLoteamentoChanged: (_) {},
              onQuadraChanged: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('exibe carregando enquanto o stream não resolve', (tester) async {
    final controller = StreamController<List<Loteamento>>();
    addTearDown(controller.close);

    await tester.pumpWidget(build(loteamentos: controller.stream));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('exibe erro com retry quando o stream falha', (tester) async {
    await tester.pumpWidget(
      build(loteamentos: Stream<List<Loteamento>>.error(Exception('falha'))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SigoErrorState), findsOneWidget);
    expect(
      find.text('Não foi possível carregar os loteamentos.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('exibe o seletor vazio quando o stream resolve sem dados', (
    tester,
  ) async {
    await tester.pumpWidget(build(loteamentos: Stream.value(const [])));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('loteamento-dropdown')), findsOneWidget);
    expect(find.byType(SigoErrorState), findsNothing);
  });

  testWidgets('exibe erro de lotes quando o stream de lotes falha', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        loteamentos: Stream.value(const []),
        quadras: Stream.value(const []),
        lotes: Stream<List<Lote>>.error(Exception('falha')),
        loteamentoId: 'l1',
        quadraId: 'q1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar os lotes.'), findsOneWidget);
  });
}

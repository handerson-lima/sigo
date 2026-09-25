import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/features/etapas/presentation/etapas_list_screen.dart';
import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    final router = GoRouter(
      initialLocation: '/etapas',
      routes: [
        GoRoute(
          path: '/etapas',
          builder: (context, state) => child,
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  testWidgets('Renderiza lista de etapas vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith((ref, arg) => Stream.value([])),
        ],
        child: buildTestWidget(const EtapasListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
          loteId: 'lo1',
        )),
      ),
    );

    await tester.pump(); // Resolve GoRouter
    await tester.pump(); // First frame of EtapasListScreen
    await tester.pump(const Duration(milliseconds: 100)); // Wait for Stream.value
    await tester.pump(); // Render data

    expect(find.text('Nenhuma etapa cadastrada'), findsOneWidget);
  });

  testWidgets('Renderiza lista com etapas', (tester) async {
    final mockEtapa = Etapa(
      id: 'e1',
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lo1',
      nome: 'Muro',
      ordem: 1,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith((ref, arg) => Stream.value([mockEtapa])),
        ],
        child: buildTestWidget(const EtapasListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
          loteId: 'lo1',
        )),
      ),
    );

    await tester.pump(); // Resolve GoRouter
    await tester.pump(); // First frame of EtapasListScreen
    await tester.pump(const Duration(milliseconds: 100)); // Wait for Stream.value
    await tester.pump(); // Render data

    expect(find.text('Muro'), findsOneWidget);
  });

  testWidgets('Renderiza erro e recarrega ao tentar novamente', (tester) async {
    var stream = Stream<List<Etapa>>.error(Exception('falha'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith((ref, arg) => stream),
        ],
        child: buildTestWidget(const EtapasListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
          loteId: 'lo1',
        )),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar as etapas.'),
      findsOneWidget,
    );

    stream = Stream.value([]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma etapa cadastrada'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/features/setores/presentation/setores_list_screen.dart';
import 'package:app/src/features/setores/data/setor_repository.dart';
import 'package:app/src/features/setores/domain/setor.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    final router = GoRouter(
      initialLocation: '/setores',
      routes: [
        GoRoute(
          path: '/setores',
          builder: (context, state) => child,
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  testWidgets('Renderiza lista de setores vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchSetoresProvider.overrideWith((ref, arg) => Stream.value([])),
        ],
        child: buildTestWidget(const SetoresListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
          loteId: 'lo1',
        )),
      ),
    );

    await tester.pump(); // Resolve GoRouter
    await tester.pump(); // First frame of SetoresListScreen
    await tester.pump(const Duration(milliseconds: 100)); // Wait for Stream.value
    await tester.pump(); // Render data

    expect(find.text('Nenhum setor cadastrado'), findsOneWidget);
  });

  testWidgets('Renderiza lista com setores', (tester) async {
    final mockSetor = Setor(
      id: 's1',
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lo1',
      name: 'Setor A',
      createdAt: DateTime(2023, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchSetoresProvider.overrideWith((ref, arg) => Stream.value([mockSetor])),
        ],
        child: buildTestWidget(const SetoresListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
          loteId: 'lo1',
        )),
      ),
    );

    await tester.pump(); // Resolve GoRouter
    await tester.pump(); // First frame of SetoresListScreen
    await tester.pump(const Duration(milliseconds: 100)); // Wait for Stream.value
    await tester.pump(); // Render data

    expect(find.text('Setor A'), findsOneWidget);
  });

  testWidgets('Renderiza erro e recarrega ao tentar novamente', (tester) async {
    var stream = Stream<List<Setor>>.error(Exception('falha'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchSetoresProvider.overrideWith((ref, arg) => stream),
        ],
        child: buildTestWidget(const SetoresListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
          loteId: 'lo1',
        )),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar os setores.'),
      findsOneWidget,
    );

    stream = Stream.value([]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum setor cadastrado'), findsOneWidget);
  });
}

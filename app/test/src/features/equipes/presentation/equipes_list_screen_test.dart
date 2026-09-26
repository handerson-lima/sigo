import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/features/equipes/presentation/equipes_list_screen.dart';
import 'package:app/src/features/equipes/data/equipe_repository.dart';
import 'package:app/src/features/equipes/domain/equipe.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    final router = GoRouter(
      initialLocation: '/equipes',
      routes: [GoRoute(path: '/equipes', builder: (context, state) => child)],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('Renderiza lista de equipes vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEquipesProvider.overrideWith((ref, arg) => Stream.value([])),
        ],
        child: buildTestWidget(
          const EquipesListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
            etapaId: 's1',
          ),
        ),
      ),
    );

    await tester.pump(); // Resolve GoRouter
    await tester.pump(); // First frame of EquipesListScreen
    await tester.pump(
      const Duration(milliseconds: 100),
    ); // Wait for Stream.value
    await tester.pump(); // Render data

    expect(find.text('Nenhuma equipe cadastrada'), findsOneWidget);
  });

  testWidgets('Renderiza lista com equipes', (tester) async {
    final mockEquipe = EquipeLote(
      id: 'e1',
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lo1',
      etapaId: 's1',
      name: 'Equipe A',
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEquipesProvider.overrideWith(
            (ref, arg) => Stream.value([mockEquipe]),
          ),
        ],
        child: buildTestWidget(
          const EquipesListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
            etapaId: 's1',
          ),
        ),
      ),
    );

    await tester.pump(); // Resolve GoRouter
    await tester.pump(); // First frame of EquipesListScreen
    await tester.pump(
      const Duration(milliseconds: 100),
    ); // Wait for Stream.value
    await tester.pump(); // Render data

    expect(find.text('Equipe A'), findsOneWidget);
  });

  testWidgets('Renderiza erro e recarrega ao tentar novamente', (tester) async {
    var stream = Stream<List<EquipeLote>>.error(Exception('falha'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [watchEquipesProvider.overrideWith((ref, arg) => stream)],
        child: buildTestWidget(
          const EquipesListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            loteId: 'lo1',
            etapaId: 's1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar as equipes.'), findsOneWidget);

    stream = Stream.value([]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma equipe cadastrada'), findsOneWidget);
  });
}

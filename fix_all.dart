import 'dart:io';

void main() async {
  // Revert SigoBreadcrumbs
  final bcFile = File('app/lib/src/common_widgets/sigo_breadcrumbs.dart');
  var bcText = await bcFile.readAsString();
  bcText = bcText.replaceFirst(
    '''    final state = GoRouterState.maybeOf(context);
    if (state == null) {
      return const SizedBox.shrink();
    }''',
    '''    final state = GoRouterState.of(context);'''
  );
  await bcFile.writeAsString(bcText);

  // Fix setores test
  final sTest = File('app/test/src/features/setores/presentation/setores_list_screen_test.dart');
  var sText = await sTest.readAsString();
  sText = sText.replaceAll('await tester.pumpAndSettle();', 'await tester.pump(); await tester.pump(const Duration(milliseconds: 100));');
  await sTest.writeAsString(sText);

  // Fix equipes test
  final eTest = File('app/test/src/features/equipes/presentation/equipes_list_screen_test.dart');
  var eText = '''import 'package:flutter_test/flutter_test.dart';
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
      routes: [
        GoRoute(
          path: '/equipes',
          builder: (context, state) => child,
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  testWidgets('Renderiza lista de equipes vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEquipesProvider.overrideWith((ref, arg) => Stream.value([])),
        ],
        child: buildTestWidget(const EquipesListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
          loteId: 'lo1',
          setorId: 's1',
        )),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Nenhum registro encontrado.'), findsOneWidget);
  });

  testWidgets('Renderiza lista com equipes', (tester) async {
    final mockEquipe = Equipe(
      id: 'e1',
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lo1',
      setorId: 's1',
      name: 'Equipe A',
      createdAt: DateTime(2023, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEquipesProvider.overrideWith((ref, arg) => Stream.value([mockEquipe])),
        ],
        child: buildTestWidget(const EquipesListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
          loteId: 'lo1',
          setorId: 's1',
        )),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Equipe A'), findsOneWidget);
  });
}
''';
  await eTest.writeAsString(eText);
}

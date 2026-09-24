import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:app/src/features/quadras/presentation/quadras_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeQuadraRepository implements QuadraRepository {
  final List<Quadra> quadras;
  FakeQuadraRepository(this.quadras);

  @override
  Stream<List<Quadra>> watchQuadras(String construtoraId, String loteamentoId) =>
      Stream.value(quadras);

  @override
  Future<void> createQuadra(Quadra quadra) async {}
}

Quadra makeQuadra(String id) => Quadra(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      name: 'Quadra $id',
      createdAt: DateTime(2026, 1, 1),
    );

Widget buildTestWidget(Widget child) {
  final router = GoRouter(
    initialLocation: '/construtora/c1/loteamentos/l1/quadras',
    routes: [
      GoRoute(
        path: '/construtora/c1/loteamentos/l1/quadras',
        builder: (context, state) => child,
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('Renderiza lista de quadras vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchQuadrasProvider.overrideWith((ref, arg) => Stream.value([])),
        ],
        child: buildTestWidget(
          const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nenhum registro encontrado.'), findsOneWidget);
  });

  testWidgets('Renderiza lista com quadras e breadcrumbs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchQuadrasProvider.overrideWith(
            (ref, arg) => Stream.value([makeQuadra('q1')]),
          ),
        ],
        child: buildTestWidget(
          const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Quadra q1'), findsOneWidget);

    final breadcrumbs = find.byType(SigoBreadcrumbs);
    expect(
      find.descendant(of: breadcrumbs, matching: find.text('Loteamento')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: breadcrumbs, matching: find.text('Quadras')),
      findsOneWidget,
    );
  });

  testWidgets('Renderiza mensagem de erro quando o stream falha',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchQuadrasProvider.overrideWith(
            (ref, arg) => Stream.error(Exception('falha')),
          ),
        ],
        child: buildTestWidget(
          const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar as quadras. Tente novamente.'),
      findsOneWidget,
    );
  });

  testWidgets('Reconstruir a tela não reemite AsyncLoading (Records)',
      (tester) async {
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);
    var buildCount = 0;

    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras',
      routes: [
        GoRoute(
          path: '/construtora/c1/loteamentos/l1/quadras',
          builder: (context, state) => ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, _, _) {
              buildCount++;
              return QuadrasListScreen(
                construtoraId: 'c1',
                loteamentoId: 'l1',
              );
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quadraRepositoryProvider.overrideWithValue(
            FakeQuadraRepository([makeQuadra('q1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Quadra q1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final buildsBefore = buildCount;

    rebuild.value++;
    await tester.pump();

    expect(buildCount, greaterThan(buildsBefore));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Quadra q1'), findsOneWidget);
  });
}

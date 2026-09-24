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
    expect(find.text('Loteamento'), findsOneWidget);
    expect(find.text('Quadras'), findsOneWidget);
  });
}

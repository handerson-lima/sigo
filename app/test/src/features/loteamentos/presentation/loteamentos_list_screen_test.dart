import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/loteamentos/presentation/loteamentos_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeLoteamentoRepository implements LoteamentoRepository {
  final List<Loteamento> loteamentos;
  FakeLoteamentoRepository(this.loteamentos);

  @override
  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) =>
      Stream.value(loteamentos);

  @override
  Future<void> createLoteamento(Loteamento loteamento) async {}
}

Loteamento makeLoteamento(String id) => Loteamento(
      id: id,
      construtoraId: 'c1',
      name: 'Loteamento $id',
      createdAt: DateTime(2026, 1, 1),
    );

Widget buildTestWidget(Widget child) {
  final router = GoRouter(
    initialLocation: '/construtora/c1/loteamentos',
    routes: [
      GoRoute(
        path: '/construtora/c1/loteamentos',
        builder: (context, state) => child,
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('Renderiza lista de loteamentos vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLoteamentosProvider.overrideWith((ref, arg) => Stream.value([])),
        ],
        child: buildTestWidget(
          const LoteamentosListScreen(construtoraId: 'c1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nenhum registro encontrado.'), findsOneWidget);
  });

  testWidgets('Renderiza lista com loteamentos e breadcrumbs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLoteamentosProvider.overrideWith(
            (ref, arg) => Stream.value([makeLoteamento('l1')]),
          ),
        ],
        child: buildTestWidget(
          const LoteamentosListScreen(construtoraId: 'c1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Loteamento l1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SigoBreadcrumbs),
        matching: find.text('Loteamentos'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Reconstruir a tela não reemite AsyncLoading (Records)',
      (tester) async {
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);
    var buildCount = 0;

    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos',
      routes: [
        GoRoute(
          path: '/construtora/c1/loteamentos',
          builder: (context, state) => ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, _, _) {
              buildCount++;
              return LoteamentosListScreen(construtoraId: 'c1');
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loteamentoRepositoryProvider.overrideWithValue(
            FakeLoteamentoRepository([makeLoteamento('l1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Loteamento l1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final buildsBefore = buildCount;

    rebuild.value++;
    await tester.pump();

    expect(buildCount, greaterThan(buildsBefore));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Loteamento l1'), findsOneWidget);
  });
}

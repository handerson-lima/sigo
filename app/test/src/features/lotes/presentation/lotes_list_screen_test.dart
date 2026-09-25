import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/lotes_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeLoteRepository implements LoteRepository {
  final List<Lote> lotes;
  FakeLoteRepository(this.lotes);

  @override
  Stream<List<Lote>> watchLotes(
    String construtoraId,
    String loteamentoId,
    String quadraId,
  ) =>
      Stream.value(lotes);

  @override
  Future<void> createLote(Lote lote) async {}
}

Lote makeLote(String id) => Lote(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      name: 'Lote $id',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Widget buildTestWidget(Widget child) {
  final router = GoRouter(
    initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
    routes: [
      GoRoute(
        path: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
        builder: (context, state) => child,
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('Renderiza lista de lotes vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLotesProvider.overrideWith((ref, arg) => Stream.value([])),
        ],
        child: buildTestWidget(const LotesListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
        )),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nenhum lote cadastrado'), findsOneWidget);
  });

  testWidgets('Renderiza lista com lotes e breadcrumbs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLotesProvider.overrideWith(
            (ref, arg) => Stream.value([makeLote('lo1')]),
          ),
        ],
        child: buildTestWidget(const LotesListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
        )),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Lote lo1'), findsOneWidget);

    final breadcrumbs = find.byType(SigoBreadcrumbs);
    expect(
      find.descendant(of: breadcrumbs, matching: find.text('Loteamento')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: breadcrumbs, matching: find.text('Quadra')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: breadcrumbs, matching: find.text('Lotes')),
      findsOneWidget,
    );
  });

  testWidgets('Renderiza mensagem de erro quando o stream falha',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLotesProvider.overrideWith(
            (ref, arg) => Stream.error(Exception('falha')),
          ),
        ],
        child: buildTestWidget(const LotesListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
        )),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar os lotes.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('Botão Tentar novamente invalida o provider e recarrega',
      (tester) async {
    var stream = Stream<List<Lote>>.error(Exception('falha'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLotesProvider.overrideWith((ref, arg) => stream),
        ],
        child: buildTestWidget(const LotesListScreen(
          construtoraId: 'c1',
          loteamentoId: 'l1',
          quadraId: 'q1',
        )),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os lotes.'),
      findsOneWidget,
    );

    stream = Stream.value([makeLote('lo1')]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Lote lo1'), findsOneWidget);
  });

  testWidgets('Reconstruir a tela não reemite AsyncLoading (Records)',
      (tester) async {
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);
    var buildCount = 0;

    final router = GoRouter(
      initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
      routes: [
        GoRoute(
          path: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
          builder: (context, state) => ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, _, _) {
              buildCount++;
              return LotesListScreen(
                construtoraId: 'c1',
                loteamentoId: 'l1',
                quadraId: 'q1',
              );
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loteRepositoryProvider.overrideWithValue(
            FakeLoteRepository([makeLote('lo1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Lote lo1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final buildsBefore = buildCount;

    rebuild.value++;
    await tester.pump();

    expect(buildCount, greaterThan(buildsBefore));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Lote lo1'), findsOneWidget);
  });
}

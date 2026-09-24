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
      phase: 'Plantas',
      status: LoteStatus.noPrazo,
      createdAt: DateTime(2026, 1, 1),
    );

Widget buildTestWidget(Widget child) {
  final router = GoRouter(
    initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
    routes: [
      GoRoute(
        path: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
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

    expect(find.text('Nenhum registro encontrado.'), findsOneWidget);
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
}

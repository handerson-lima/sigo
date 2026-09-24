import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/construtoras/routing/construtora_routes.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/loteamentos/presentation/loteamentos_list_screen.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/lotes_list_screen.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:app/src/features/quadras/presentation/quadras_list_screen.dart';
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

class FakeQuadraRepository implements QuadraRepository {
  final List<Quadra> quadras;
  FakeQuadraRepository(this.quadras);

  @override
  Stream<List<Quadra>> watchQuadras(String construtoraId, String loteamentoId) =>
      Stream.value(quadras);

  @override
  Future<void> createQuadra(Quadra quadra) async {}
}

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

Loteamento makeLoteamento(String id) => Loteamento(
      id: id,
      construtoraId: 'c1',
      name: 'Loteamento $id',
      createdAt: DateTime(2026, 1, 1),
    );

Quadra makeQuadra(String id) => Quadra(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      name: 'Quadra $id',
      createdAt: DateTime(2026, 1, 1),
    );

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

void main() {
  testWidgets('LoteamentosListScreen navega para a lista de quadras',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos',
      routes: [
        GoRoute(
          path: '/construtora/:cId/loteamentos',
          builder: (context, state) => LoteamentosListScreen(
            construtoraId: state.pathParameters['cId']!,
          ),
          routes: [
            GoRoute(
              path: ':loteamentoId/quadras',
              builder: (context, state) => QuadrasListScreen(
                construtoraId: state.pathParameters['cId']!,
                loteamentoId: state.pathParameters['loteamentoId']!,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loteamentoRepositoryProvider.overrideWithValue(
            FakeLoteamentoRepository([makeLoteamento('l1')]),
          ),
          quadraRepositoryProvider.overrideWithValue(FakeQuadraRepository([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Loteamento l1'), findsOneWidget);

    await tester.tap(find.text('Loteamento l1'));
    await tester.pumpAndSettle();

    expect(find.byType(QuadrasListScreen), findsOneWidget);
  });

  testWidgets('QuadrasListScreen navega para a lista de lotes', (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras',
      routes: [
        GoRoute(
          path: '/construtora/:cId/loteamentos/:loteamentoId/quadras',
          builder: (context, state) => QuadrasListScreen(
            construtoraId: state.pathParameters['cId']!,
            loteamentoId: state.pathParameters['loteamentoId']!,
          ),
          routes: [
            GoRoute(
              path: ':quadraId/lotes',
              builder: (context, state) => LotesListScreen(
                construtoraId: state.pathParameters['cId']!,
                loteamentoId: state.pathParameters['loteamentoId']!,
                quadraId: state.pathParameters['quadraId']!,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quadraRepositoryProvider.overrideWithValue(
            FakeQuadraRepository([makeQuadra('q1')]),
          ),
          loteRepositoryProvider.overrideWithValue(FakeLoteRepository([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Quadra q1'), findsOneWidget);

    await tester.tap(find.text('Quadra q1'));
    await tester.pumpAndSettle();

    expect(find.byType(LotesListScreen), findsOneWidget);
  });

  testWidgets(
      'rotas reais aninhadas renderizam breadcrumbs e ascendem para quadras',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          loteamentoRepositoryProvider.overrideWithValue(
            FakeLoteamentoRepository([makeLoteamento('l1')]),
          ),
          quadraRepositoryProvider.overrideWithValue(
            FakeQuadraRepository([makeQuadra('q1')]),
          ),
          loteRepositoryProvider.overrideWithValue(
            FakeLoteRepository([makeLote('lo1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LotesListScreen), findsOneWidget);
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

    await tester.tap(find.text('Loteamento'));
    await tester.pumpAndSettle();

    expect(find.byType(QuadrasListScreen), findsOneWidget);
    expect(find.text('Quadra q1'), findsOneWidget);
  });

  testWidgets(
      'tocar em Quadra no breadcrumb mantém os IDs pais na URL ao voltar para lotes',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          loteamentoRepositoryProvider.overrideWithValue(
            FakeLoteamentoRepository([makeLoteamento('l1')]),
          ),
          quadraRepositoryProvider.overrideWithValue(
            FakeQuadraRepository([makeQuadra('q1')]),
          ),
          loteRepositoryProvider.overrideWithValue(
            FakeLoteRepository([makeLote('lo1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Quadra'));
    await tester.pumpAndSettle();

    expect(find.byType(LotesListScreen), findsOneWidget);
    expect(
      router.state.uri.path,
      '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
    );
    expect(find.text('Lote lo1'), findsOneWidget);
  });
}

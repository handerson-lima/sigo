import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/construtoras/routing/construtora_routes.dart';
import 'package:app/src/features/equipes/data/equipe_repository.dart';
import 'package:app/src/features/equipes/domain/equipe.dart';
import 'package:app/src/features/equipes/presentation/equipes_list_screen.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/lotes_list_screen.dart';
import 'package:app/src/features/setores/data/setor_repository.dart';
import 'package:app/src/features/setores/domain/setor.dart';
import 'package:app/src/features/setores/presentation/setores_list_screen.dart';
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

class FakeSetorRepository implements SetorRepository {
  final List<Setor> setores;
  FakeSetorRepository(this.setores);

  @override
  Stream<List<Setor>> watchSetores(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
  ) =>
      Stream.value(setores);
}

class FakeEquipeRepository implements EquipeRepository {
  final List<Equipe> equipes;
  FakeEquipeRepository(this.equipes);

  @override
  Stream<List<Equipe>> watchEquipes(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
    String setorId,
  ) =>
      Stream.value(equipes);
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

Setor makeSetor(String id) => Setor(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lote-1',
      name: 'Setor $id',
      createdAt: DateTime(2026, 1, 1),
    );

Equipe makeEquipe(String id) => Equipe(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lote-1',
      setorId: 'setor-1',
      name: 'Equipe $id',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('LotesListScreen navega para a lista de setores ao tocar num lote',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
      routes: [
        GoRoute(
          path: '/construtora/:cId/loteamentos/:loteamentoId/quadras/:quadraId/lotes',
          builder: (context, state) => LotesListScreen(
            construtoraId: state.pathParameters['cId']!,
            loteamentoId: state.pathParameters['loteamentoId']!,
            quadraId: state.pathParameters['quadraId']!,
          ),
          routes: [
            GoRoute(
              path: ':loteId/setores',
              builder: (context, state) => SetoresListScreen(
                construtoraId: state.pathParameters['cId']!,
                loteamentoId: state.pathParameters['loteamentoId']!,
                quadraId: state.pathParameters['quadraId']!,
                loteId: state.pathParameters['loteId']!,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loteRepositoryProvider.overrideWithValue(
            FakeLoteRepository([makeLote('lote-1')]),
          ),
          setorRepositoryProvider.overrideWithValue(FakeSetorRepository([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Lote lote-1'), findsOneWidget);

    await tester.tap(find.text('Lote lote-1'));
    await tester.pumpAndSettle();

    expect(find.byType(SetoresListScreen), findsOneWidget);
  });

  testWidgets('SetoresListScreen navega para a lista de equipes ao tocar num setor',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lote-1/setores',
      routes: [
        GoRoute(
          path: '/construtora/:cId/loteamentos/:loteamentoId/quadras/:quadraId/lotes/:loteId/setores',
          builder: (context, state) => SetoresListScreen(
            construtoraId: state.pathParameters['cId']!,
            loteamentoId: state.pathParameters['loteamentoId']!,
            quadraId: state.pathParameters['quadraId']!,
            loteId: state.pathParameters['loteId']!,
          ),
          routes: [
            GoRoute(
              path: ':setorId/equipes',
              builder: (context, state) => EquipesListScreen(
                construtoraId: state.pathParameters['cId']!,
                loteamentoId: state.pathParameters['loteamentoId']!,
                quadraId: state.pathParameters['quadraId']!,
                loteId: state.pathParameters['loteId']!,
                setorId: state.pathParameters['setorId']!,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setorRepositoryProvider.overrideWithValue(
            FakeSetorRepository([makeSetor('setor-1')]),
          ),
          equipeRepositoryProvider.overrideWithValue(FakeEquipeRepository([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Setor setor-1'), findsOneWidget);

    await tester.tap(find.text('Setor setor-1'));
    await tester.pumpAndSettle();

    expect(find.byType(EquipesListScreen), findsOneWidget);
  });

  testWidgets(
      'rotas reais aninhadas extraem parametros e renderizam EquipesListScreen',
      (tester) async {
    final router = GoRouter(
      initialLocation:
          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lote-1/setores/setor-1/equipes',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          equipeRepositoryProvider.overrideWithValue(
            FakeEquipeRepository([makeEquipe('eq-1')]),
          ),
          setorRepositoryProvider.overrideWithValue(FakeSetorRepository([])),
          loteRepositoryProvider.overrideWithValue(FakeLoteRepository([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(EquipesListScreen), findsOneWidget);
    expect(find.text('Equipe eq-1'), findsOneWidget);
  });
}

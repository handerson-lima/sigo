import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/construtoras/routing/construtora_routes.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/loteamentos/presentation/loteamentos_list_screen.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/add_lote_screen.dart';
import 'package:app/src/features/lotes/presentation/lotes_list_screen.dart';
import 'package:app/src/features/obras/presentation/access_denied_screen.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/obras/presentation/obra_dashboard_screen.dart';
import 'package:app/src/features/equipes/data/equipe_repository.dart';
import 'package:app/src/features/equipes/domain/equipe.dart';
import 'package:app/src/features/equipes/presentation/equipes_list_screen.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:app/src/features/quadras/presentation/quadras_list_screen.dart';
import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:app/src/features/etapas/presentation/etapas_list_screen.dart';
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

class FakeEtapaRepository implements EtapaRepository {
  final List<Etapa> etapas;
  FakeEtapaRepository(this.etapas);

  @override
  Stream<List<Etapa>> watchEtapas(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
  ) =>
      Stream.value(etapas);

  @override
  Future<void> createEtapa(Etapa etapa) async {}

  @override
  Future<void> createDefaultEtapas({
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
  }) async {}
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
    String etapaId,
  ) =>
      Stream.value(equipes);

  @override
  Future<void> createEquipe(Equipe equipe) async {}
}

Loteamento makeLoteamento(String id) => Loteamento(
      id: id,
      construtoraId: 'c1',
      name: 'Loteamento $id',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Quadra makeQuadra(String id) => Quadra(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      name: 'Quadra $id',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Lote makeLote(String id) => Lote(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      name: 'Lote $id',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Etapa makeEtapa(String id) => Etapa(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lo1',
      nome: 'Etapa $id',
      ordem: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Equipe makeEquipe(String id) => Equipe(
      id: id,
      construtoraId: 'c1',
      loteamentoId: 'l1',
      quadraId: 'q1',
      loteId: 'lo1',
      etapaId: 'e1',
      name: 'Equipe $id',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
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
      'rotas reais aninhadas renderizam breadcrumbs e crumb-pai ascende para a lista',
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

    await tester.tap(find.text('Quadra'));
    await tester.pumpAndSettle();

    expect(find.byType(QuadrasListScreen), findsOneWidget);
    expect(find.text('Quadra q1'), findsOneWidget);
    expect(
      router.state.uri.path,
      '/construtora/c1/loteamentos/l1/quadras',
    );
  });

  testWidgets('crumb raiz ascende para a lista de loteamentos', (tester) async {
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

    await tester.tap(find.text('Loteamento'));
    await tester.pumpAndSettle();

    expect(find.byType(LoteamentosListScreen), findsOneWidget);
    expect(
      router.state.uri.path,
      '/construtora/c1/loteamentos',
    );
  });

  testWidgets('deep-link em :loteId redireciona para a lista de etapas',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          etapaRepositoryProvider.overrideWithValue(
            FakeEtapaRepository([makeEtapa('e1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(EtapasListScreen), findsOneWidget);
    expect(find.text('Etapa e1'), findsOneWidget);
    expect(
      router.state.uri.path,
      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas',
    );
  });

  testWidgets('deep-link em :etapaId redireciona para a lista de equipes',
      (tester) async {
    final router = GoRouter(
      initialLocation:
          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/e1',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          etapaRepositoryProvider.overrideWithValue(FakeEtapaRepository([])),
          equipeRepositoryProvider.overrideWithValue(
            FakeEquipeRepository([makeEquipe('e1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(EquipesListScreen), findsOneWidget);
    expect(find.text('Equipe e1'), findsOneWidget);
    expect(
      router.state.uri.path,
      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/e1/equipes',
    );
  });

  testWidgets('crumb de Etapa ascende para a lista de etapas', (tester) async {
    final router = GoRouter(
      initialLocation:
          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/e1/equipes',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          etapaRepositoryProvider.overrideWithValue(
            FakeEtapaRepository([makeEtapa('e1')]),
          ),
          equipeRepositoryProvider.overrideWithValue(
            FakeEquipeRepository([makeEquipe('e1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(EquipesListScreen), findsOneWidget);

    await tester.tap(find.text('Etapa'));
    await tester.pumpAndSettle();

    expect(find.byType(EtapasListScreen), findsOneWidget);
    expect(
      router.state.uri.path,
      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas',
    );
  });

  testWidgets('deep-link em :loteamentoId redireciona para a lista de quadras',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1',
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
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(QuadrasListScreen), findsOneWidget);
    expect(find.text('Quadra q1'), findsOneWidget);
    expect(
      router.state.uri.path,
      '/construtora/c1/loteamentos/l1/quadras',
    );
  });

  testWidgets('deep-link em :quadraId redireciona para a lista de lotes',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
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
    expect(
      router.state.uri.path,
      '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
    );
  });

  testWidgets('redirect preserva query e fragment do deep-link',
      (tester) async {
    final router = GoRouter(
      initialLocation:
          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1?x=1#alvo',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          etapaRepositoryProvider.overrideWithValue(FakeEtapaRepository([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      router.state.uri.path,
      '/construtora/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas',
    );
    expect(router.state.uri.queryParameters['x'], '1');
    expect(router.state.uri.fragment, 'alvo');
  });

  testWidgets('admin toca Novo Lote e abre AddLoteScreen com os ids corretos',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
          ),
          loteRepositoryProvider.overrideWithValue(FakeLoteRepository([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final addScreen = tester.widget<AddLoteScreen>(find.byType(AddLoteScreen));
    expect(addScreen.construtoraId, 'c1');
    expect(addScreen.loteamentoId, 'l1');
    expect(addScreen.quadraId, 'q1');
  });

  testWidgets('membro nao-admin nao acessa a rota lotes/novo', (tester) async {
    final router = GoRouter(
      initialLocation:
          '/construtora/c1/loteamentos/l1/quadras/q1/lotes/novo',
      routes: construtoraRoutes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({
              'isActive': true,
              'isAdmin': false,
              'modules': ['lotes'],
            }),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AccessDeniedScreen), findsOneWidget);
    expect(find.byType(AddLoteScreen), findsNothing);
  });

  testWidgets(
      'card legado de Lotes e Setores navega para a lista de loteamentos',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/construtora/c1/obra/o1',
      routes: [
        GoRoute(
          path: '/construtora/:cId/obra/:oId',
          builder: (context, state) => ObraDashboardScreen(
            construtoraId: state.pathParameters['cId']!,
            obraId: state.pathParameters['oId']!,
          ),
        ),
        GoRoute(
          path: '/construtora/:cId/loteamentos',
          builder: (context, state) => LoteamentosListScreen(
            construtoraId: state.pathParameters['cId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({
              'isActive': true,
              'isAdmin': false,
              'modules': ['lotes'],
            }),
          ),
          currentPermissionsProvider(
            (construtoraId: 'c1', obraId: 'o1'),
          ).overrideWith(
            (ref) => Stream.value(
              ObraMember(
                userId: 'u1',
                isActive: true,
                isAdmin: false,
                modules: ['lotes'],
                joinedAt: DateTime(2025),
              ),
            ),
          ),
          loteamentoRepositoryProvider.overrideWithValue(
            FakeLoteamentoRepository([makeLoteamento('l1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Lotes e Setores'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/construtora/c1/loteamentos');
    expect(find.byType(LoteamentosListScreen), findsOneWidget);
  });
}
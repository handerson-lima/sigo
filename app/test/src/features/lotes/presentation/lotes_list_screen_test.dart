import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:app/src/design_system/sigo_theme.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/construtoras/routing/construtora_routes.dart';
import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/atribuir_lotacao_lote_sheet.dart';
import 'package:app/src/features/lotes/presentation/lote_detail_screen.dart';
import 'package:app/src/features/lotes/presentation/lote_summary_card.dart';
import 'package:app/src/features/lotes/presentation/lotes_list_screen.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/rh/data/rh_repository.dart';
import 'package:app/src/features/rh/domain/equipe.dart';
import 'package:app/src/features/rh/domain/funcionario.dart';
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
  ) => Stream.value(lotes);

  @override
  Stream<Lote?> watchLote(String loteId) {
    final found = lotes.where((l) => l.id == loteId).firstOrNull;
    return Stream.value(found);
  }

  @override
  Future<void> createLoteComEtapas(Lote lote) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEtapaRepository implements EtapaRepository {
  @override
  Stream<List<Etapa>> watchEtapas(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
  ) => Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

Lote _sampleLote(String id, String name) {
  final now = DateTime(2026, 10, 1);
  return Lote(
    id: id,
    construtoraId: 'c1',
    loteamentoId: 'l1',
    quadraId: 'q1',
    name: name,
    logradouro: 'Rua A, 100',
    frenteM: 10,
    profundidadeM: 20,
    areaTerrenoM2: 200,
    progressoPercentual: 40,
    etapasConcluidasCount: 2,
    createdAt: now,
    updatedAt: now,
  );
}

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
        child: buildTestWidget(
          const LotesListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
          ),
        ),
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
        child: buildTestWidget(
          const LotesListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
          ),
        ),
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

  testWidgets('Renderiza mensagem de erro quando o stream falha', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLotesProvider.overrideWith(
            (ref, arg) => Stream.error(Exception('falha')),
          ),
        ],
        child: buildTestWidget(
          const LotesListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar os lotes.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('Botão Tentar novamente invalida o provider e recarrega', (
    tester,
  ) async {
    var stream = Stream<List<Lote>>.error(Exception('falha'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [watchLotesProvider.overrideWith((ref, arg) => stream)],
        child: buildTestWidget(
          const LotesListScreen(
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar os lotes.'), findsOneWidget);

    stream = Stream.value([makeLote('lo1')]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Lote lo1'), findsOneWidget);
  });

  testWidgets('Reconstruir a tela não reemite AsyncLoading (Records)', (
    tester,
  ) async {
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

  group('LotesListScreen — Story 5 (LoteSummaryCard e navegação)', () {
    testWidgets(
      'exibe cards e navega para LoteDetailScreen ao tocar no card preservando breadcrumbs',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
          routes: construtoraRoutes,
        );

        final lote1 = _sampleLote('lo1', 'Lote 01');
        final lote2 = _sampleLote('lo2', 'Lote 02');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trustedDevProvider.overrideWith((ref) => Stream.value(true)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
              ),
              loteRepositoryProvider.overrideWithValue(
                FakeLoteRepository([lote1, lote2]),
              ),
              etapaRepositoryProvider.overrideWithValue(_FakeEtapaRepository()),
            ],
            child: MaterialApp.router(
              theme: SigoTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(LotesListScreen), findsOneWidget);
        expect(find.byType(LoteSummaryCard), findsNWidgets(2));
        expect(find.text('Lote 01'), findsOneWidget);
        expect(find.text('Lote 02'), findsOneWidget);

        await tester.tap(find.text('Lote 01'));
        await tester.pumpAndSettle();

        expect(find.byType(LoteDetailScreen), findsOneWidget);
        expect(
          router.state.uri.path,
          '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/detalhes',
        );
        expect(find.byType(SigoBreadcrumbs), findsOneWidget);
      },
    );

    testWidgets(
      'admin toca + Atribuir no card e abre AtribuirLotacaoLoteSheet',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
          routes: construtoraRoutes,
        );

        final lote1 = _sampleLote('lo1', 'Lote 01');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trustedDevProvider.overrideWith((ref) => Stream.value(true)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
              ),
              loteRepositoryProvider.overrideWithValue(
                FakeLoteRepository([lote1]),
              ),
              equipesStreamProvider('c1').overrideWith(
                (ref) => Stream.value([
                  Equipe(
                    id: 'eq1',
                    construtoraId: 'c1',
                    name: 'Equipe Alfa',
                    isActive: true,
                  ),
                ]),
              ),
              funcionariosStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Funcionario>[])),
            ],
            child: MaterialApp.router(
              theme: SigoTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lote_card_atribuir_lo1')));
        await tester.pumpAndSettle();

        expect(find.byType(AtribuirLotacaoLoteSheet), findsOneWidget);
        expect(find.text('Atribuir ao Lote 01'), findsOneWidget);
        expect(find.text('Equipe Alfa'), findsOneWidget);
      },
    );

    testWidgets('nao-admin nao ve botao Atribuir nem FAB Novo Lote', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
        routes: construtoraRoutes,
      );

      final lote1 = _sampleLote('lo1', 'Lote 01');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({
                'isActive': true,
                'isAdmin': false,
                'isOwner': false,
                'modules': ['lotes'],
              }),
            ),
            loteRepositoryProvider.overrideWithValue(
              FakeLoteRepository([lote1]),
            ),
          ],
          child: MaterialApp.router(
            theme: SigoTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LoteSummaryCard), findsOneWidget);
      expect(find.byKey(const Key('lote_card_atribuir_lo1')), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets(
      'Admin do loteamento ve FAB Novo Lote e botao Atribuir mesmo sendo operario na construtora',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
          routes: construtoraRoutes,
        );

        final lote1 = _sampleLote('lo1', 'Lote 01');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trustedDevProvider.overrideWith((ref) => Stream.value(false)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({
                  'isActive': true,
                  'isAdmin': false,
                  'modules': <String>[],
                }),
              ),
              effectiveLoteamentoObraIdProvider((
                construtoraId: 'c1',
                loteamentoId: 'l1',
              )).overrideWithValue(const AsyncValue.data('l1')),
              currentPermissionsProvider((construtoraId: 'c1', obraId: 'l1'))
                  .overrideWith(
                    (ref) => Stream.value(
                      ObraMember(
                        userId: 'u1',
                        isActive: true,
                        isAdmin: true,
                        modules: const [],
                        joinedAt: DateTime(2026),
                      ),
                    ),
                  ),
              loteRepositoryProvider.overrideWithValue(
                FakeLoteRepository([lote1]),
              ),
            ],
            child: MaterialApp.router(
              theme: SigoTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(LoteSummaryCard), findsOneWidget);
        expect(find.byKey(const Key('lote_card_atribuir_lo1')), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );
  });
}

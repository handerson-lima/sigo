import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:app/src/features/quadras/presentation/quadras_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeQuadraRepository implements QuadraRepository {
  final List<Quadra> quadras;
  final List<Quadra> createdQuadras = [];
  final List<({Quadra quadra, List<Lote> lotes})> createdComLotes = [];

  FakeQuadraRepository(this.quadras);

  @override
  Stream<List<Quadra>> watchQuadras(
    String construtoraId,
    String loteamentoId,
  ) => Stream.value(quadras);

  @override
  Future<void> createQuadra(Quadra quadra) async {
    createdQuadras.add(quadra);
  }

  @override
  Future<void> createQuadraComLotes({
    required Quadra quadra,
    required List<Lote> lotes,
  }) async {
    createdComLotes.add((quadra: quadra, lotes: lotes));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Quadra makeQuadra(String id, {String? logradouroPadrao}) => Quadra(
  id: id,
  construtoraId: 'c1',
  loteamentoId: 'l1',
  name: 'Quadra $id',
  logradouroPadrao: logradouroPadrao,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Widget buildTestWidget(Widget child) {
  final router = GoRouter(
    initialLocation: '/construtoras/c1/loteamentos/l1/quadras',
    routes: [
      GoRoute(
        path: '/construtoras/c1/loteamentos/l1/quadras',
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

    expect(find.text('Nenhuma quadra cadastrada'), findsOneWidget);
  });

  testWidgets('Renderiza lista com quadras, logradouro e breadcrumbs', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchQuadrasProvider.overrideWith(
            (ref, arg) => Stream.value([
              makeQuadra('q1', logradouroPadrao: 'Rua Sandoval Wanderley'),
            ]),
          ),
        ],
        child: buildTestWidget(
          const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Quadra q1'), findsOneWidget);
    expect(find.text('Rua Sandoval Wanderley'), findsOneWidget);

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

  testWidgets('Renderiza mensagem de erro quando o stream falha', (
    tester,
  ) async {
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

    expect(find.text('Não foi possível carregar as quadras.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('Botão Tentar novamente invalida o provider e recarrega', (
    tester,
  ) async {
    var stream = Stream<List<Quadra>>.error(Exception('falha'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [watchQuadrasProvider.overrideWith((ref, arg) => stream)],
        child: buildTestWidget(
          const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar as quadras.'), findsOneWidget);

    stream = Stream.value([makeQuadra('q1')]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Quadra q1'), findsOneWidget);
  });

  testWidgets('Reconstruir a tela não reemite AsyncLoading (Records)', (
    tester,
  ) async {
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);
    var buildCount = 0;

    final router = GoRouter(
      initialLocation: '/construtoras/c1/loteamentos/l1/quadras',
      routes: [
        GoRoute(
          path: '/construtoras/c1/loteamentos/l1/quadras',
          builder: (context, state) => ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, _, _) {
              buildCount++;
              return const QuadrasListScreen(
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

  testWidgets(
    'Oculta botões de criação de quadra para usuário sem permissão admin',
    (tester) async {
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
            quadraRepositoryProvider.overrideWithValue(
              FakeQuadraRepository([]),
            ),
          ],
          child: buildTestWidget(
            const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('Nova Quadra'), findsNothing);
      expect(find.text('Criar Nova Quadra'), findsNothing);
    },
  );

  testWidgets('Admin cria quadra simples sem lotes via createQuadra', (
    tester,
  ) async {
    final fakeRepo = FakeQuadraRepository([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
          ),
          quadraRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: buildTestWidget(
          const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byTooltip('Nova Quadra'), findsOneWidget);
    expect(find.text('Criar Nova Quadra'), findsOneWidget);

    await tester.tap(find.text('Criar Nova Quadra'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('quadra-name-field')),
      'Quadra 10',
    );
    await tester.enterText(
      find.byKey(const Key('quadra-logradouro-field')),
      'Av. Principal',
    );
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(fakeRepo.createdQuadras.length, 1);
    expect(fakeRepo.createdComLotes, isEmpty);
    expect(fakeRepo.createdQuadras.first.name, 'Quadra 10');
    expect(fakeRepo.createdQuadras.first.logradouroPadrao, 'Av. Principal');
  });

  testWidgets(
    'Admin cria quadra com lotes em massa ajustando exceção na prévia via createQuadraComLotes',
    (tester) async {
      final fakeRepo = FakeQuadraRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
            ),
            quadraRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: buildTestWidget(
            const QuadrasListScreen(construtoraId: 'c1', loteamentoId: 'l1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nova Quadra'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('quadra-name-field')),
        'Quadra 28',
      );
      await tester.enterText(
        find.byKey(const Key('quadra-logradouro-field')),
        'Rua Sandoval Wanderley',
      );

      final massTile = find.byKey(const Key('quadra-mass-tile'));
      await tester.ensureVisible(massTile);
      await tester.tap(massTile);
      await tester.pumpAndSettle();

      for (final entry in <Key, String>{
        const Key('mass-gen-quantidade'): '3',
        const Key('mass-gen-frente'): '10',
        const Key('mass-gen-profundidade'): '20',
      }.entries) {
        final finder = find.byKey(entry.key);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, entry.value);
      }
      await tester.pump();

      final previewBtn = find.byKey(const Key('mass-gen-preview-btn'));
      await tester.ensureVisible(previewBtn);
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();

      final lote2Frente = find.byKey(const Key('mass-preview-frente-1'));
      await tester.ensureVisible(lote2Frente);
      await tester.enterText(lote2Frente, '12');
      await tester.pump();

      final lote2Area = tester.widget<TextFormField>(
        find.byKey(const Key('mass-preview-area-terreno-1')),
      );
      expect(lote2Area.controller?.text, '240');

      final createBtn = find.text('Criar');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.createdQuadras, isEmpty);
      expect(fakeRepo.createdComLotes.length, 1);

      final call = fakeRepo.createdComLotes.first;
      expect(call.quadra.name, 'Quadra 28');
      expect(call.quadra.logradouroPadrao, 'Rua Sandoval Wanderley');
      expect(call.lotes.length, 3);
      expect(call.lotes[0].logradouro, 'Rua Sandoval Wanderley');
      expect(call.lotes[0].frenteM, 10.0);
      expect(call.lotes[0].areaTerrenoM2, 200.0);
      expect(call.lotes[1].frenteM, 12.0);
      expect(call.lotes[1].profundidadeM, 20.0);
      expect(call.lotes[1].areaTerrenoM2, 240.0);
      expect(call.lotes[2].frenteM, 10.0);
      expect(call.lotes[2].areaTerrenoM2, 200.0);
    },
  );
}

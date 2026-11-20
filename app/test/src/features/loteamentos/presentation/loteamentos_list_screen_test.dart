import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/loteamentos/presentation/loteamento_summary_card.dart';
import 'package:app/src/features/loteamentos/presentation/loteamento_summary_provider.dart';
import 'package:app/src/features/loteamentos/presentation/loteamentos_list_screen.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeLoteamentoRepository implements LoteamentoRepository {
  final List<Loteamento> loteamentos;
  final List<Loteamento> createdLoteamentos = [];
  final List<Loteamento> updatedLoteamentos = [];
  final List<({Loteamento loteamento, List<Quadra> quadras, List<Lote> lotes})>
  createdEmMassa = [];

  FakeLoteamentoRepository(this.loteamentos);

  @override
  Stream<List<Loteamento>> watchLoteamentos(String construtoraId) =>
      Stream.value(loteamentos);

  @override
  Future<void> createLoteamento(Loteamento loteamento) async {
    createdLoteamentos.add(loteamento);
  }

  @override
  Future<void> updateLoteamento(Loteamento loteamento) async {
    updatedLoteamentos.add(loteamento);
  }

  @override
  Future<void> createLoteamentoEmMassa({
    required Loteamento loteamento,
    required List<Quadra> quadras,
    required List<Lote> lotes,
  }) async {
    createdEmMassa.add((
      loteamento: loteamento,
      quadras: quadras,
      lotes: lotes,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Loteamento makeLoteamento(
  String id, {
  String? bairro,
  String? cidade,
  String? uf,
}) => Loteamento(
  id: id,
  construtoraId: 'c1',
  name: 'Loteamento $id',
  bairro: bairro,
  cidade: cidade,
  uf: uf,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Widget buildTestWidget(Widget child) {
  final router = GoRouter(
    initialLocation: '/construtoras/c1/loteamentos',
    routes: [
      GoRoute(
        path: '/construtoras/c1/loteamentos',
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

    expect(find.text('Nenhum loteamento cadastrado'), findsOneWidget);
  });

  testWidgets('Renderiza lista com loteamentos, localização e breadcrumbs', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLoteamentosProvider.overrideWith(
            (ref, arg) => Stream.value([
              makeLoteamento(
                'l1',
                bairro: 'Estivas',
                cidade: 'Extremoz',
                uf: 'RN',
              ),
            ]),
          ),
        ],
        child: buildTestWidget(
          const LoteamentosListScreen(construtoraId: 'c1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Loteamento l1'), findsOneWidget);
    expect(find.text('Estivas • Extremoz - RN'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SigoBreadcrumbs),
        matching: find.text('Loteamentos'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Renderiza mensagem de erro quando o stream falha', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLoteamentosProvider.overrideWith(
            (ref, arg) => Stream.error(Exception('falha')),
          ),
        ],
        child: buildTestWidget(
          const LoteamentosListScreen(construtoraId: 'c1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar os loteamentos.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('Botão Tentar novamente invalida o provider e recarrega', (
    tester,
  ) async {
    var stream = Stream<List<Loteamento>>.error(Exception('falha'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchLoteamentosProvider.overrideWith((ref, arg) => stream),
        ],
        child: buildTestWidget(
          const LoteamentosListScreen(construtoraId: 'c1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os loteamentos.'),
      findsOneWidget,
    );

    stream = Stream.value([makeLoteamento('l1')]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Loteamento l1'), findsOneWidget);
  });

  testWidgets('Reconstruir a tela não reemite AsyncLoading (Records)', (
    tester,
  ) async {
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);
    var buildCount = 0;

    final router = GoRouter(
      initialLocation: '/construtoras/c1/loteamentos',
      routes: [
        GoRoute(
          path: '/construtoras/c1/loteamentos',
          builder: (context, state) => ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, _, _) {
              buildCount++;
              return const LoteamentosListScreen(construtoraId: 'c1');
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

  testWidgets(
    'Admin cria loteamento simples apenas com nome via createLoteamento',
    (tester) async {
      final fakeRepo = FakeLoteamentoRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
            ),
            loteamentoRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: buildTestWidget(
            const LoteamentosListScreen(construtoraId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Novo Loteamento'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('loteamento-name-field')),
        'Residencial Aurora',
      );
      final createBtn = find.text('Criar');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.createdLoteamentos.length, 1);
      expect(fakeRepo.createdEmMassa, isEmpty);
      expect(fakeRepo.createdLoteamentos.first.name, 'Residencial Aurora');
      expect(fakeRepo.createdLoteamentos.first.construtoraId, 'c1');
    },
  );

  testWidgets(
    'Admin cria loteamento com localização opcional e lotes em massa com exceção na prévia',
    (tester) async {
      final fakeRepo = FakeLoteamentoRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
            ),
            loteamentoRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: buildTestWidget(
            const LoteamentosListScreen(construtoraId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Novo Loteamento'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('loteamento-name-field')),
        'Jardim Botânico',
      );

      await tester.tap(find.byKey(const Key('loteamento-carimbo-tile')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('loteamento-bairro-field')),
        'Estivas',
      );
      await tester.enterText(
        find.byKey(const Key('loteamento-cidade-field')),
        'Extremoz',
      );
      await tester.enterText(
        find.byKey(const Key('loteamento-uf-field')),
        'rn',
      );

      final massTile = find.byKey(const Key('loteamento-mass-tile'));
      await tester.ensureVisible(massTile);
      await tester.tap(massTile);
      await tester.pumpAndSettle();

      for (final entry in <Key, String>{
        const Key('loteamento-quadra-name-field'): 'Quadra A',
        const Key('mass-gen-quantidade'): '3',
        const Key('mass-gen-logradouro'): 'Rua das Flores',
        const Key('mass-gen-frente'): '10',
        const Key('mass-gen-profundidade'): '20',
      }.entries) {
        final finder = find.byKey(entry.key);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, entry.value);
      }
      await tester.pump();

      final areaPadraoField = tester.widget<TextFormField>(
        find.byKey(const Key('mass-gen-area-terreno')),
      );
      expect(areaPadraoField.controller?.text, '200');

      final previewBtn = find.byKey(const Key('mass-gen-preview-btn'));
      await tester.ensureVisible(previewBtn);
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mass-preview-item-0')), findsOneWidget);
      expect(find.byKey(const Key('mass-preview-item-1')), findsOneWidget);
      expect(find.byKey(const Key('mass-preview-item-2')), findsOneWidget);

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

      expect(fakeRepo.createdLoteamentos, isEmpty);
      expect(fakeRepo.createdEmMassa.length, 1);

      final call = fakeRepo.createdEmMassa.first;
      expect(call.loteamento.name, 'Jardim Botânico');
      expect(call.loteamento.bairro, 'Estivas');
      expect(call.loteamento.cidade, 'Extremoz');
      expect(call.loteamento.uf, 'RN');
      expect(call.quadras.length, 1);
      expect(call.quadras.first.name, 'Quadra A');
      expect(call.quadras.first.logradouroPadrao, 'Rua das Flores');
      expect(call.lotes.length, 3);
      expect(call.lotes[0].name, 'Lote 1');
      expect(call.lotes[0].frenteM, 10.0);
      expect(call.lotes[0].areaTerrenoM2, 200.0);
      expect(call.lotes[1].name, 'Lote 2');
      expect(call.lotes[1].frenteM, 12.0);
      expect(call.lotes[1].areaTerrenoM2, 240.0);
      expect(call.lotes[2].name, 'Lote 3');
      expect(call.lotes[2].frenteM, 10.0);
      expect(call.lotes[2].areaTerrenoM2, 200.0);
    },
  );

  testWidgets(
    'Renderiza LoteamentoSummaryCard com métricas e navega para quadras ao clicar',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/construtoras/c1/loteamentos',
        routes: [
          GoRoute(
            path: '/construtoras/c1/loteamentos',
            builder: (context, state) =>
                const LoteamentosListScreen(construtoraId: 'c1'),
          ),
          GoRoute(
            path: '/construtoras/c1/loteamentos/:loteamentoId/quadras',
            builder: (context, state) => Scaffold(
              body: Text('Quadras de ${state.pathParameters['loteamentoId']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchLoteamentosProvider.overrideWith(
              (ref, arg) => Stream.value([
                makeLoteamento(
                  'l1',
                  bairro: 'Centro',
                  cidade: 'Natal',
                  uf: 'RN',
                ),
              ]),
            ),
            loteamentoSummaryMapProvider('c1').overrideWith(
              (ref) => Stream.value(const {
                'l1': LoteamentoSummary(
                  totalQuadras: 3,
                  totalLotes: 24,
                  lotesConcluidos: 10,
                  lotesEmAndamento: 8,
                  lotesPendentes: 6,
                  progressoMedio: 42,
                ),
              }),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LoteamentoSummaryCard), findsOneWidget);
      expect(find.text('Loteamento l1'), findsOneWidget);
      expect(find.text('Centro • Natal - RN'), findsOneWidget);
      expect(find.text('Em andamento • 42%'), findsOneWidget);
      expect(
        find.text('Progresso Geral (3 quadras • 24 lotes)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Loteamento l1'));
      await tester.pumpAndSettle();

      expect(find.text('Quadras de l1'), findsOneWidget);
    },
  );

  testWidgets(
    'Admin do loteamento edita dados do loteamento vinculado e acessa Painel, mas nao cria/importa novos',
    (tester) async {
      final fakeRepo = FakeLoteamentoRepository([
        Loteamento(
          id: 'l1',
          construtoraId: 'c1',
          obraId: 'o1',
          name: 'CAOL VIDA NOVA',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ]);

      final router = GoRouter(
        initialLocation: '/construtoras/c1/loteamentos',
        routes: [
          GoRoute(
            path: '/construtoras/c1/loteamentos',
            builder: (context, state) =>
                const LoteamentosListScreen(construtoraId: 'c1'),
          ),
          GoRoute(
            path: '/construtoras/c1/obra/:oId',
            builder: (context, state) => Scaffold(
              body: Text('Painel obra ${state.pathParameters['oId']}'),
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
                'modules': <String>[],
              }),
            ),
            userActiveObraIdsProvider('c1').overrideWith(
              (ref) => Stream.value(ObraIdSet.fromIterable(['o1'])),
            ),
            currentPermissionsProvider((construtoraId: 'c1', obraId: 'o1'))
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
            loteamentoRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Não pode criar nem importar novo loteamento na construtora
      expect(find.byTooltip('Novo Loteamento'), findsNothing);
      expect(find.byTooltip('Importar DXF/DWF'), findsNothing);

      // Pode editar o próprio loteamento
      await tester.tap(find.byKey(const Key('loteamento_card_edit_l1')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit-loteamento-name-field')),
        'CAOL VIDA NOVA II',
      );
      await tester.tap(find.byKey(const Key('edit-loteamento-save-btn')));
      await tester.pumpAndSettle();

      expect(fakeRepo.updatedLoteamentos.length, 1);
      expect(fakeRepo.updatedLoteamentos.first.name, 'CAOL VIDA NOVA II');

      // Pode navegar para o Painel do Loteamento (/obra/o1)
      await tester.tap(find.byKey(const Key('loteamento_card_painel_l1')));
      await tester.pumpAndSettle();
      expect(find.text('Painel obra o1'), findsOneWidget);
    },
  );
}

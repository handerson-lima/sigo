import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/equipes/presentation/equipes_list_screen.dart';
import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/rh/data/rh_repository.dart';
import 'package:app/src/features/rh/domain/equipe.dart';
import 'package:app/src/features/rh/domain/funcionario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeRhRepository implements RhRepository {
  final List<Equipe> createdEquipes = [];

  @override
  Future<void> createEquipe(Equipe equipe) async {
    createdEquipes.add(equipe);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEtapaRepository implements EtapaRepository {
  String? linkedEtapaId;
  String? linkedEquipeId;
  String? linkedEquipeNome;
  String? unlinkedEtapaId;

  @override
  Future<void> vincularEquipe({
    required String etapaId,
    required String equipeId,
    required String equipeNome,
    String? construtoraId,
    String? loteId,
  }) async {
    linkedEtapaId = etapaId;
    linkedEquipeId = equipeId;
    linkedEquipeNome = equipeNome;
  }

  @override
  Future<void> desvincularEquipe({
    required String etapaId,
    String? construtoraId,
    String? loteId,
  }) async {
    unlinkedEtapaId = etapaId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Etapa _makeEtapa({String? equipeId, String? equipeNome}) => Etapa(
  id: 's1',
  construtoraId: 'c1',
  loteamentoId: 'l1',
  quadraId: 'q1',
  loteId: 'lo1',
  nome: 'Muro',
  ordem: 1,
  equipeId: equipeId,
  equipeNome: equipeNome,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Equipe _makeEquipeRh({
  required String id,
  required String name,
  String? leaderName,
  bool isActive = true,
}) => Equipe(
  id: id,
  construtoraId: 'c1',
  name: name,
  leaderName: leaderName,
  isActive: isActive,
);

Funcionario _makeFuncionario({
  required String id,
  required String name,
  required String role,
  String? teamId,
  bool isActive = true,
}) => Funcionario(
  id: id,
  construtoraId: 'c1',
  name: name,
  cpf: '12345678901',
  role: role,
  teamId: teamId,
  employmentType: 'clt',
  salaryBasis: 'mensal',
  baseSalaryCents: 300000,
  isActive: isActive,
);

void main() {
  Widget buildTestWidget(Widget child) {
    final router = GoRouter(
      initialLocation:
          '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/s1/equipes',
      routes: [
        GoRoute(
          path:
              '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/etapas/s1/equipes',
          builder: (context, state) => child,
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  const screen = EquipesListScreen(
    construtoraId: 'c1',
    loteamentoId: 'l1',
    quadraId: 'q1',
    loteId: 'lo1',
    etapaId: 's1',
  );

  testWidgets(
    'Etapa sem equipe exibe estado vazio e CTA Vincular Equipe do RH para admin',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchEtapasProvider.overrideWith(
              (ref, arg) => Stream.value([_makeEtapa()]),
            ),
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
            ),
          ],
          child: buildTestWidget(screen),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Nenhuma equipe vinculada a esta etapa'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('btn_vincular_equipe_etapa')), findsOneWidget);
      expect(find.text('Vincular Equipe do RH'), findsOneWidget);
    },
  );

  testWidgets('Etapa sem equipe oculta CTA para usuário sem permissão admin', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith(
            (ref, arg) => Stream.value([_makeEtapa()]),
          ),
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({
              'isActive': true,
              'isAdmin': false,
              'modules': ['lotes'],
            }),
          ),
        ],
        child: buildTestWidget(screen),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nenhuma equipe vinculada a esta etapa'), findsOneWidget);
    expect(find.byKey(const Key('btn_vincular_equipe_etapa')), findsNothing);
  });

  testWidgets(
    'Abre seletor de equipes ativas do RH com busca e vincula equipe à etapa',
    (tester) async {
      final fakeRepo = _FakeEtapaRepository();
      final equipesRh = [
        _makeEquipeRh(
          id: 'eq-1',
          name: 'Equipe Alvenaria Alpha',
          leaderName: 'Carlos Silva',
          isActive: true,
        ),
        _makeEquipeRh(
          id: 'eq-2',
          name: 'Equipe Acabamento Beta',
          leaderName: 'Maria Souza',
          isActive: true,
        ),
        _makeEquipeRh(
          id: 'eq-3',
          name: 'Equipe Inativa',
          leaderName: 'Pedro',
          isActive: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchEtapasProvider.overrideWith(
              (ref, arg) => Stream.value([_makeEtapa()]),
            ),
            etapaRepositoryProvider.overrideWithValue(fakeRepo),
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value(null),
            ),
            equipesStreamProvider('c1').overrideWith(
              (ref) => Stream.value(equipesRh),
            ),
          ],
          child: buildTestWidget(screen),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_vincular_equipe_etapa')));
      await tester.pumpAndSettle();

      // Equipes ativas aparecem e inativa fica oculta
      expect(find.text('Equipe Alvenaria Alpha'), findsOneWidget);
      expect(find.text('Equipe Acabamento Beta'), findsOneWidget);
      expect(find.text('Equipe Inativa'), findsNothing);

      // Busca por nome/líder filtra a lista
      await tester.enterText(
        find.byKey(const Key('buscar_equipe_rh_field')),
        'Maria',
      );
      await tester.pumpAndSettle();

      expect(find.text('Equipe Alvenaria Alpha'), findsNothing);
      expect(find.text('Equipe Acabamento Beta'), findsOneWidget);

      // Vincula a equipe filtrada
      await tester.tap(find.text('Vincular'));
      await tester.pumpAndSettle();

      expect(fakeRepo.linkedEtapaId, 's1');
      expect(fakeRepo.linkedEquipeId, 'eq-2');
      expect(fakeRepo.linkedEquipeNome, 'Equipe Acabamento Beta');
      expect(
        find.text('Equipe "Equipe Acabamento Beta" vinculada à etapa.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Exibe card da equipe vinculada com líder, status e lista de colaboradores',
    (tester) async {
      final equipesRh = [
        _makeEquipeRh(
          id: 'eq-1',
          name: 'Equipe Alvenaria Alpha',
          leaderName: 'Carlos Silva',
          isActive: true,
        ),
      ];
      final funcionariosRh = [
        _makeFuncionario(
          id: 'f1',
          name: 'João Pedreiro',
          role: 'Pedreiro',
          teamId: 'eq-1',
        ),
        _makeFuncionario(
          id: 'f2',
          name: 'Ana Servente',
          role: 'Servente',
          teamId: 'eq-1',
        ),
        _makeFuncionario(
          id: 'f3',
          name: 'Outro Colaborador',
          role: 'Eletricista',
          teamId: 'eq-2',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchEtapasProvider.overrideWith(
              (ref, arg) => Stream.value([
                _makeEtapa(
                  equipeId: 'eq-1',
                  equipeNome: 'Equipe Alvenaria Alpha',
                ),
              ]),
            ),
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value(null),
            ),
            equipesStreamProvider('c1').overrideWith(
              (ref) => Stream.value(equipesRh),
            ),
            funcionariosStreamProvider('c1').overrideWith(
              (ref) => Stream.value(funcionariosRh),
            ),
          ],
          child: buildTestWidget(screen),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Equipe Alvenaria Alpha'), findsOneWidget);
      expect(find.text('Líder: Carlos Silva'), findsOneWidget);
      expect(find.text('Ativa'), findsOneWidget);
      expect(find.text('Colaboradores vinculados (2)'), findsOneWidget);
      expect(find.text('João Pedreiro'), findsOneWidget);
      expect(find.text('Ana Servente'), findsOneWidget);
      expect(find.text('Outro Colaborador'), findsNothing);
      expect(find.byKey(const Key('btn_trocar_equipe_etapa')), findsOneWidget);
      expect(
        find.byKey(const Key('btn_desvincular_equipe_etapa')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Desvincula equipe após confirmação no diálogo', (tester) async {
    final fakeRepo = _FakeEtapaRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith(
            (ref, arg) => Stream.value([
              _makeEtapa(
                equipeId: 'eq-1',
                equipeNome: 'Equipe Alvenaria Alpha',
              ),
            ]),
          ),
          etapaRepositoryProvider.overrideWithValue(fakeRepo),
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value(null),
          ),
          equipesStreamProvider('c1').overrideWith(
            (ref) => Stream.value([
              _makeEquipeRh(id: 'eq-1', name: 'Equipe Alvenaria Alpha'),
            ]),
          ),
          funcionariosStreamProvider('c1').overrideWith(
            (ref) => Stream.value([]),
          ),
        ],
        child: buildTestWidget(screen),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn_desvincular_equipe_etapa')));
    await tester.pumpAndSettle();

    expect(find.text('Desvincular equipe'), findsWidgets);
    await tester.tap(find.byKey(const Key('btn_confirmar_desvincular_equipe')));
    await tester.pumpAndSettle();

    expect(fakeRepo.unlinkedEtapaId, 's1');
    expect(find.text('Equipe desvinculada da etapa.'), findsOneWidget);
  });

  testWidgets(
    'Trata graciosamente erro de permissão no RH exibindo etapa.equipeNome',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchEtapasProvider.overrideWith(
              (ref, arg) => Stream.value([
                _makeEtapa(
                  equipeId: 'eq-1',
                  equipeNome: 'Equipe Fallback RH',
                ),
              ]),
            ),
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({
                'isActive': true,
                'isAdmin': false,
                'modules': ['lotes'],
              }),
            ),
            equipesStreamProvider('c1').overrideWith(
              (ref) => Stream<List<Equipe>>.error(
                Exception('permission-denied'),
              ),
            ),
            funcionariosStreamProvider('c1').overrideWith(
              (ref) => Stream<List<Funcionario>>.error(
                Exception('permission-denied'),
              ),
            ),
          ],
          child: buildTestWidget(screen),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Equipe Fallback RH'), findsOneWidget);
      expect(
        find.text('Detalhes completos do RH indisponíveis para o seu perfil.'),
        findsOneWidget,
      );
      expect(
        find.text('Não foi possível carregar os colaboradores do RH.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Renderiza erro ao carregar etapa e recarrega ao tentar novamente', (
    tester,
  ) async {
    var stream = Stream<List<Etapa>>.error(Exception('falha'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchEtapasProvider.overrideWith((ref, arg) => stream),
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value(null),
          ),
        ],
        child: buildTestWidget(screen),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar os dados da etapa.'),
      findsOneWidget,
    );

    stream = Stream.value([_makeEtapa()]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma equipe vinculada a esta etapa'), findsOneWidget);
  });

  testWidgets(
    'Seletor de equipes do RH permite criar nova equipe sob canRh e vincular à etapa',
    (tester) async {
      final fakeEtapaRepo = _FakeEtapaRepository();
      final fakeRhRepo = _FakeRhRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchEtapasProvider.overrideWith(
              (ref, arg) => Stream.value([_makeEtapa()]),
            ),
            etapaRepositoryProvider.overrideWithValue(fakeEtapaRepo),
            rhRepositoryProvider.overrideWithValue(fakeRhRepo),
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
            ),
            equipesStreamProvider(
              'c1',
            ).overrideWith((ref) => Stream.value(const <Equipe>[])),
            funcionariosStreamProvider(
              'c1',
            ).overrideWith((ref) => Stream.value(const <Funcionario>[])),
          ],
          child: buildTestWidget(screen),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_vincular_equipe_etapa')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('btn_nova_equipe_contextual_etapa')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('btn_nova_equipe_contextual_etapa')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('equipe_form_name_input')),
        'Equipe Hidráulica Nova',
      );
      await tester.tap(find.byKey(const Key('btn_save_equipe_form')));
      await tester.pumpAndSettle();

      expect(fakeRhRepo.createdEquipes, hasLength(1));
      expect(fakeRhRepo.createdEquipes.first.name, 'Equipe Hidráulica Nova');
      expect(find.text('Equipe Hidráulica Nova'), findsOneWidget);

      await tester.tap(find.text('Vincular'));
      await tester.pumpAndSettle();

      expect(fakeEtapaRepo.linkedEtapaId, 's1');
      expect(fakeEtapaRepo.linkedEquipeNome, 'Equipe Hidráulica Nova');
    },
  );
}

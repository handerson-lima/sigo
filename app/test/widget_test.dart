import 'package:app/main.dart';
import 'package:app/src/common_widgets/access_guard.dart';
import 'package:app/src/core/contracts.dart';
import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/obra_lotes_provider.dart';
import 'package:app/src/features/obras/domain/obra.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:app/src/features/obras/presentation/construtora_obras_provider.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/obras/presentation/obra_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'initialization routes signed-out user to login without Firebase',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('trusted dev reaches obra without memberships', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: const MaterialApp(
          home: AccessGuard(
            construtoraId: 'A',
            obraId: 'B',
            module: 'diario',
            child: Text('global access'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('global access'), findsOneWidget);
  });

  testWidgets(
    'inactive membership denies central module despite legacy flags',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('A').overrideWith(
              (ref) => Stream.value({
                'isActive': false,
                'isAdmin': true,
                'modules': ['estoque'],
              }),
            ),
          ],
          child: const MaterialApp(
            home: AccessGuard(
              construtoraId: 'A',
              module: 'estoque',
              child: Text('secret'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('secret'), findsNothing);
      expect(find.text('Acesso Negado'), findsOneWidget);
    },
  );

  testWidgets(
    'alternar de Obra A para Obra B no seletor recalcula layout imediatamente',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = GoRouter(
        initialLocation: '/construtora/c1/obra/obraA',
        routes: [
          GoRoute(
            path: '/construtora/:cId/obra/:oId',
            builder: (context, state) {
              final cId = state.pathParameters['cId']!;
              final oId = state.pathParameters['oId']!;
              return ObraDashboardScreen(construtoraId: cId, obraId: oId);
            },
          ),
        ],
      );

      final obrasList = [
        Obra(
          id: 'obraA',
          construtoraId: 'c1',
          name: 'Obra Alfa',
          createdAt: DateTime(2025),
        ),
        Obra(
          id: 'obraB',
          construtoraId: 'c1',
          name: 'Obra Beta',
          createdAt: DateTime(2025),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraObrasProvider('c1').overrideWith(
              (ref) => Future.value(obrasList),
            ),
            currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraA'))
                .overrideWith(
                  (ref) => Stream.value(
                    ObraMember(
                      userId: 'u1',
                      isActive: true,
                      isAdmin: false,
                      modules: ['diario'],
                      joinedAt: DateTime(2025),
                    ),
                  ),
                ),
            currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraB'))
                .overrideWith(
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
            obraLotesProvider((construtoraId: 'c1', obraId: 'obraA'))
                .overrideWith((ref) => Stream.value(<Lote>[])),
            obraLotesProvider((construtoraId: 'c1', obraId: 'obraB'))
                .overrideWith((ref) => Stream.value(<Lote>[])),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Na Obra A: exibe Diário de Obra (na sidebar e no dashboard card), não exibe Lotes
      expect(find.text('Diário de Obra'), findsNWidgets(2));
      expect(find.text('Lotes e Setores'), findsNothing);

      // Abre dropdown do seletor de obra e seleciona Obra Beta
      final dropdown = find.byKey(const Key('obra-switcher-dropdown'));
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final itemB = find.byKey(const Key('obra-switcher-item-obraB')).last;
      await tester.tap(itemB);
      await tester.pumpAndSettle();

      // Na Obra B: atualiza instantaneamente para exibir Lotes e Setores e ocultar Diário
      expect(find.text('Lotes e Setores'), findsNWidgets(2));
      expect(find.text('Diário de Obra'), findsNothing);
    },
  );

  testWidgets(
    'rota direta nao autorizada em obra bloqueia via AccessGuard',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': false}),
            ),
            currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraB'))
                .overrideWith(
                  (ref) => Stream.value(
                    ObraMember(
                      userId: 'u1',
                      isActive: true,
                      isAdmin: false,
                      modules: ['lotes'], // Sem 'diario'
                      joinedAt: DateTime(2025),
                    ),
                  ),
                ),
          ],
          child: const MaterialApp(
            home: AccessGuard(
              construtoraId: 'c1',
              obraId: 'obraB',
              module: 'diario',
              child: Text('area restrita'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('area restrita'), findsNothing);
      expect(find.text('Acesso Negado'), findsOneWidget);
    },
  );

  testWidgets(
    'obra inativa nega acesso para usuario comum',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
            ),
            obraDocProvider((construtoraId: 'c1', obraId: 'obraX'))
                .overrideWith((ref) => Stream.value({'isActive': false})),
          ],
          child: const MaterialApp(
            home: AccessGuard(
              construtoraId: 'c1',
              obraId: 'obraX',
              child: Text('painel secreto'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('painel secreto'), findsNothing);
      expect(find.text('Acesso Negado'), findsOneWidget);
    },
  );

  testWidgets(
    'admin de construtora nao bypassa verificaao de obra inativa',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
            ),
            obraDocProvider((construtoraId: 'c1', obraId: 'obraX'))
                .overrideWith((ref) => Stream.value({'isActive': false})),
          ],
          child: const MaterialApp(
            home: AccessGuard(
              construtoraId: 'c1',
              obraId: 'obraX',
              child: Text('admin area'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('admin area'), findsNothing);
      expect(find.text('Acesso Negado'), findsOneWidget);
    },
  );

  testWidgets(
    'obra inativa preserva acesso de suporte para dev global',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
            ),
            obraDocProvider((construtoraId: 'c1', obraId: 'obraX'))
                .overrideWith((ref) => Stream.value({'isActive': false})),
          ],
          child: const MaterialApp(
            home: AccessGuard(
              construtoraId: 'c1',
              obraId: 'obraX',
              child: Text('painel secreto'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('painel secreto'), findsOneWidget);
    },
  );

  testWidgets(
    'allowedModules como unico campo concede acesso via currentPermissionsProvider',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({'isActive': true, 'isAdmin': false}),
            ),
            currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraY'))
                .overrideWith(
                  (ref) => Stream.value(
                    ObraMember(
                      userId: 'u1',
                      isActive: true,
                      isAdmin: false,
                      modules: ['diario'],
                      joinedAt: DateTime(2025),
                    ),
                  ),
                ),
          ],
          child: const MaterialApp(
            home: AccessGuard(
              construtoraId: 'c1',
              obraId: 'obraY',
              module: 'diario',
              child: Text('modulo diario'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('modulo diario'), findsOneWidget);
    },
  );

  testWidgets(
    'allowedModules normaliza modulos legados e falha fechado se vazio',
    (tester) async {
      // Teste com allowedModules legados (rdo -> diario)
      final rawData = {
        'userId': 'u1',
        'isActive': true,
        'isAdmin': false,
        'allowedModules': ['rdo'],
        'joinedAt': DateTime(2025).toIso8601String(),
      };
      final modules = ((rawData['modules'] ?? rawData['allowedModules']) as List)
          .map((m) => normalizeModule(m.toString()))
          .toList();
      final member = ObraMember.fromJson({...rawData, 'modules': modules});

      expect(member.modules, contains('diario'));
      expect(member.modules, isNot(contains('rdo')));

      // Teste com allowedModules vazio falha fechado (sem permissões)
      final emptyData = {
        'userId': 'u2',
        'isActive': true,
        'isAdmin': false,
        'allowedModules': [],
        'joinedAt': DateTime(2025).toIso8601String(),
      };
      final emptyModules =
          ((emptyData['modules'] ?? emptyData['allowedModules']) as List)
              .map((m) => normalizeModule(m.toString()))
              .toList();
      final emptyMember = ObraMember.fromJson({
        ...emptyData,
        'modules': emptyModules,
      });

      expect(emptyMember.modules, isEmpty);
    },
  );
}

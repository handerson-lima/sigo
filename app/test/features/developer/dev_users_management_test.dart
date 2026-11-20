import 'package:app/src/common_widgets/sigo_top_bar.dart';
import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/authentication/domain/app_user.dart';
import 'package:app/src/features/developer/data/dev_users_repository.dart';
import 'package:app/src/features/developer/presentation/user_details_screen.dart';
import 'package:app/src/features/developer/presentation/users_list_screen.dart';
import 'package:app/src/features/notifications/data/notifications_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeUser implements User {
  @override
  final String uid;
  @override
  final String? email;

  _FakeUser({required this.uid, required this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  String? lastCurrentPassword;
  String? lastNewPassword;
  Exception? errorToThrow;

  @override
  User? get currentUser => _FakeUser(uid: 'dev-1', email: 'dev@sigo.test');

  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class _RecordedCall {
  final String name;
  final Map<String, dynamic> data;
  _RecordedCall(this.name, this.data);
}

void main() {
  group('AppUser.isActive', () {
    test('trata ausência de isActive como true e respeita false', () {
      final legacy = AppUser.fromJson({
        'id': 'u1',
        'email': 'u1@test.com',
        'displayName': 'Legacy',
      });
      expect(legacy.isActive, isTrue);

      final disabled = AppUser.fromJson({
        'id': 'u2',
        'email': 'u2@test.com',
        'displayName': 'Disabled',
        'isActive': false,
      });
      expect(disabled.isActive, isFalse);
    });
  });

  group('DevUsersRepository', () {
    test('bloqueia chamadas offline com mensagem pt-br', () async {
      var called = false;
      final repo = DevUsersRepository(
        null,
        checkConnectivity: () async => [ConnectivityResult.none],
        callFunction: (name, data) async {
          called = true;
        },
      );

      await expectLater(
        () => repo.adminDeleteUser('u1'),
        throwsA(
          predicate((e) => e.toString().contains(mensagemSemConexaoDevUsers)),
        ),
      );
      await expectLater(
        () => repo.adminSetUserActive('u1', false),
        throwsA(
          predicate((e) => e.toString().contains(mensagemSemConexaoDevUsers)),
        ),
      );
      await expectLater(
        () => repo.adminResetUserPassword('u1', 'Mudar@1234'),
        throwsA(
          predicate((e) => e.toString().contains(mensagemSemConexaoDevUsers)),
        ),
      );
      expect(called, isFalse);
    });

    test('envia payloads corretos e traduz erros FirebaseFunctionsException',
        () async {
      final calls = <_RecordedCall>[];
      final repo = DevUsersRepository(
        null,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        callFunction: (name, data) async {
          calls.add(_RecordedCall(name, data));
        },
      );

      await repo.adminSetUserActive('u2', false);
      await repo.adminResetUserPassword('u2', 'Nova@1234');
      await repo.adminDeleteUser('u2');
      await repo.setDevRole('u2', true);
      await repo.setMembership(
        construtoraId: 'c1',
        userId: 'u2',
        role: 'owner',
        isOwner: true,
        isActive: false,
      );

      expect(calls.map((c) => c.name).toList(), [
        'adminSetUserActive',
        'adminResetUserPassword',
        'adminDeleteUser',
        'setDevRole',
        'setMembership',
      ]);
      expect(calls[0].data, {'userId': 'u2', 'isActive': false});
      expect(calls[1].data, {'userId': 'u2', 'password': 'Nova@1234'});
      expect(calls[2].data, {'userId': 'u2'});
      expect(calls[4].data['isOwner'], isTrue);
      expect(calls[4].data['isActive'], isFalse);

      final failingRepo = DevUsersRepository(
        null,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        callFunction: (name, data) async {
          throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Dev confiável obrigatório',
          );
        },
      );
      await expectLater(
        () => failingRepo.adminDeleteUser('u2'),
        throwsA(
          predicate(
            (e) => e
                .toString()
                .contains('Você não tem permissão para executar esta operação.'),
          ),
        ),
      );
    });
  });

  group('UsersListScreen', () {
    testWidgets(
        'filtra por status Ativos/Inativos, exibe badge INATIVO e executa ações do menu',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final calls = <_RecordedCall>[];
      final repo = DevUsersRepository(
        null,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        callFunction: (name, data) async {
          calls.add(_RecordedCall(name, data));
        },
      );

      final users = [
        AppUser(
          id: 'dev-1',
          email: 'dev@sigo.test',
          displayName: 'Dev Atual',
          globalRole: 'dev',
          isActive: true,
        ),
        AppUser(
          id: 'u-active',
          email: 'ativo@sigo.test',
          displayName: 'Usuário Ativo',
          isActive: true,
        ),
        AppUser(
          id: 'u-inactive',
          email: 'inativo@sigo.test',
          displayName: 'Usuário Inativo',
          isActive: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangesProvider.overrideWith(
              (ref) => Stream.value(
                _FakeUser(uid: 'dev-1', email: 'dev@sigo.test'),
              ),
            ),
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            unreadNotificationsCountProvider.overrideWith((ref) => 0),
            allUsersStreamProvider.overrideWith((ref) => Stream.value(users)),
            allConstrutorasMapProvider.overrideWith((ref) => Stream.value({})),
            allUserMembershipsProvider.overrideWith((ref) => Stream.value({})),
            allPendingRequestsProvider.overrideWith((ref) => Stream.value([])),
            devUsersRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: UsersListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Badge INATIVO aparece apenas no usuário inativo
      expect(find.text('INATIVO'), findsOneWidget);
      expect(find.text('Usuário Ativo'), findsOneWidget);
      expect(find.text('Usuário Inativo'), findsOneWidget);

      // Filtro: Inativos
      await tester.tap(find.text('Inativos'));
      await tester.pumpAndSettle();
      expect(find.text('Usuário Inativo'), findsOneWidget);
      expect(find.text('Usuário Ativo'), findsNothing);

      // Filtro: Ativos
      await tester.tap(find.text('Ativos'));
      await tester.pumpAndSettle();
      expect(find.text('Usuário Ativo'), findsOneWidget);
      expect(find.text('Usuário Inativo'), findsNothing);

      // Abrir menu de ações de u-active e redefinir senha com padrão Mudar@1234
      await tester.tap(find.byKey(const Key('user-actions-menu-u-active')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redefinir senha'));
      await tester.pumpAndSettle();

      expect(find.text('Mudar@1234'), findsOneWidget);
      expect(
        find.byKey(const Key('copy-provisional-password-btn')),
        findsOneWidget,
      );

      await tester.tap(find.text('Confirmar Redefinição'));
      await tester.pumpAndSettle();

      expect(calls.length, 1);
      expect(calls.first.name, 'adminResetUserPassword');
      expect(calls.first.data, {'userId': 'u-active', 'password': 'Mudar@1234'});
    });
  });

  group('UserDetailsScreen', () {
    testWidgets(
        'oculta vínculos inativos, preserva owner ao remover, exibe erro traduzido e executa exclusão',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('users').doc('u-target').set({
        'id': 'u-target',
        'email': 'target@sigo.test',
        'displayName': 'Alvo Teste',
        'globalRole': 'user',
        'isActive': true,
      });
      await fakeDb.collection('construtoras').doc('c1').set({
        'id': 'c1',
        'name': 'Construtora Alfa',
      });
      await fakeDb.collection('construtoras').doc('c2').set({
        'id': 'c2',
        'name': 'Construtora Beta',
      });
      // Vínculo ativo como owner
      await fakeDb
          .collection('construtoras')
          .doc('c1')
          .collection('construtora_members')
          .doc('u-target')
          .set({
        'userId': 'u-target',
        'construtoraId': 'c1',
        'role': 'owner',
        'isOwner': true,
        'isActive': true,
        'modules': <String>[],
      });
      // Vínculo inativo que deve ser ocultado
      await fakeDb
          .collection('construtoras')
          .doc('c2')
          .collection('construtora_members')
          .doc('u-target')
          .set({
        'userId': 'u-target',
        'construtoraId': 'c2',
        'role': 'member',
        'isOwner': false,
        'isActive': false,
        'modules': <String>[],
      });

      final calls = <_RecordedCall>[];
      var shouldFailMembership = true;
      final repo = DevUsersRepository(
        null,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        callFunction: (name, data) async {
          calls.add(_RecordedCall(name, data));
          if (name == 'setMembership' && shouldFailMembership) {
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'Negado',
            );
          }
        },
      );

      final router = GoRouter(
        initialLocation: '/dev/users/u-target',
        routes: [
          GoRoute(
            path: '/dev/users',
            builder: (_, _) => const Scaffold(body: Text('Lista')),
          ),
          GoRoute(
            path: '/dev/users/:id',
            builder: (_, state) => UserDetailsScreen(
              userId: state.pathParameters['id']!,
              firestore: fakeDb,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangesProvider.overrideWith(
              (ref) => Stream.value(
                _FakeUser(uid: 'dev-1', email: 'dev@sigo.test'),
              ),
            ),
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            unreadNotificationsCountProvider.overrideWith((ref) => 0),
            devUsersRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Apenas Construtora Alfa (ativa) aparece; Beta (inativa) fica oculta
      expect(find.text('Construtora Alfa'), findsOneWidget);
      expect(find.text('Construtora Beta'), findsNothing);

      // Remover vínculo com falha exibe SnackBar traduzida e preserva role owner
      await tester.tap(find.byKey(const Key('remove-membership-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();

      expect(calls.last.name, 'setMembership');
      expect(calls.last.data['role'], 'owner');
      expect(calls.last.data['isOwner'], isTrue);
      expect(calls.last.data['isActive'], isFalse);
      expect(
        find.text('Você não tem permissão para executar esta operação.'),
        findsOneWidget,
      );

      // Excluir usuário navega para trás após sucesso
      shouldFailMembership = false;
      await tester.tap(find.byKey(const Key('user-details-delete-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(calls.last.name, 'adminDeleteUser');
      expect(calls.last.data, {'userId': 'u-target'});
    });
  });

  group('SigoTopBar alterar senha', () {
    testWidgets('abre diálogo no menu do avatar, valida e chama changePassword',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeAuth = _FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            authStateChangesProvider.overrideWith(
              (ref) => Stream.value(fakeAuth.currentUser),
            ),
            unreadNotificationsCountProvider.overrideWith((ref) => 0),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: SigoTopBar(title: 'Painel', activeRoute: '/dev'),
              body: SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sigo-avatar-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alterar senha'));
      await tester.pumpAndSettle();

      // Tentar senha curta (< 8) e divergente
      await tester.enterText(
        find.byKey(const Key('change-password-current')),
        'Atual@123',
      );
      await tester.enterText(
        find.byKey(const Key('change-password-new')),
        'curta',
      );
      await tester.enterText(
        find.byKey(const Key('change-password-confirm')),
        'outra',
      );
      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('A nova senha deve ter no mínimo 8 caracteres.'),
        findsOneWidget,
      );
      expect(find.text('As senhas não coincidem.'), findsOneWidget);
      expect(fakeAuth.lastNewPassword, isNull);

      // Preencher corretamente e submeter
      await tester.enterText(
        find.byKey(const Key('change-password-new')),
        'NovaSenha@123',
      );
      await tester.enterText(
        find.byKey(const Key('change-password-confirm')),
        'NovaSenha@123',
      );
      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();

      expect(fakeAuth.lastCurrentPassword, 'Atual@123');
      expect(fakeAuth.lastNewPassword, 'NovaSenha@123');
      expect(find.text('Senha alterada com sucesso!'), findsOneWidget);
    });
  });
}

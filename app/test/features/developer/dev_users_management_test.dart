import 'package:app/main.dart';
import 'package:app/src/common_widgets/sigo_top_bar.dart';
import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/authentication/domain/app_user.dart';
import 'package:app/src/features/construtoras/data/membros_repository.dart';
import 'package:app/src/features/developer/data/dev_users_repository.dart';
import 'package:app/src/features/developer/presentation/user_details_screen.dart';
import 'package:app/src/features/developer/presentation/users_list_screen.dart';
import 'package:app/src/features/notifications/data/notifications_repository.dart';
import 'package:app/src/routing/app_router.dart';
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

  AuthCredential? lastReauthCredential;
  String? lastUpdatedPassword;
  FirebaseAuthException? reauthError;
  FirebaseAuthException? updatePasswordError;

  _FakeUser({required this.uid, required this.email});

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    if (reauthError != null) throw reauthError!;
    lastReauthCredential = credential;
    return _FakeUserCredential();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    if (updatePasswordError != null) throw updatePasswordError!;
    lastUpdatedPassword = newPassword;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeUser? user;
  FirebaseAuthException? signInError;
  String? signedInEmail;
  String? signedInPassword;
  bool signedOut = false;

  _FakeFirebaseAuth({this.user});

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => Stream.value(user);

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    signedInEmail = email;
    signedInPassword = password;
    return _FakeUserCredential();
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    user = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  String? lastCurrentPassword;
  String? lastNewPassword;
  Exception? errorToThrow;
  bool signOutCalled = false;
  User? _currentUser = _FakeUser(uid: 'dev-1', email: 'dev@sigo.test');

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => Stream.value(_currentUser);

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
  Future<void> signOut() async {
    signOutCalled = true;
    _currentUser = null;
  }
}

class _FakeMembrosRepository extends MembrosRepository {
  String? approvedRequestId;
  String? approvedPassword;

  _FakeMembrosRepository() : super(null, null);

  @override
  Future<void> approveAccessRequest(String requestId, String password) async {
    approvedRequestId = requestId;
    approvedPassword = password;
  }
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

  group('AuthRepository real', () {
    test('signInWithEmailAndPassword traduz FirebaseAuthException user-disabled e credenciais inválidas',
        () async {
      final fakeAuth = _FakeFirebaseAuth(
        user: _FakeUser(uid: 'u1', email: 'u1@sigo.test'),
      );
      final repo = AuthRepository(fakeAuth);

      fakeAuth.signInError = FirebaseAuthException(code: 'user-disabled');
      await expectLater(
        () => repo.signInWithEmailAndPassword('u1@sigo.test', '12345678'),
        throwsA(
          predicate(
            (e) => e.toString().contains('Esta conta foi desativada.'),
          ),
        ),
      );

      fakeAuth.signInError = FirebaseAuthException(code: 'wrong-password');
      await expectLater(
        () => repo.signInWithEmailAndPassword('u1@sigo.test', 'errada'),
        throwsA(
          predicate(
            (e) => e.toString().contains('E-mail ou senha incorretos.'),
          ),
        ),
      );

      fakeAuth.signInError = null;
      await repo.signInWithEmailAndPassword('u1@sigo.test', 'Correta@123');
      expect(fakeAuth.signedInEmail, 'u1@sigo.test');
      expect(fakeAuth.signedInPassword, 'Correta@123');
    });

    test('changePassword valida entrada, reautentica, atualiza senha e traduz erros',
        () async {
      final fakeUser = _FakeUser(uid: 'u1', email: 'u1@sigo.test');
      final fakeAuth = _FakeFirebaseAuth(user: fakeUser);
      final repo = AuthRepository(fakeAuth);

      await expectLater(
        () => repo.changePassword(
          currentPassword: '',
          newPassword: 'Nova@1234',
        ),
        throwsA(
          predicate((e) => e.toString().contains('Informe sua senha atual.')),
        ),
      );

      await expectLater(
        () => repo.changePassword(
          currentPassword: 'Atual@123',
          newPassword: 'curta',
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('mínimo 8 caracteres'),
          ),
        ),
      );

      fakeUser.reauthError = FirebaseAuthException(code: 'invalid-credential');
      await expectLater(
        () => repo.changePassword(
          currentPassword: 'Errada',
          newPassword: 'Nova@1234',
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('E-mail ou senha incorretos.'),
          ),
        ),
      );

      fakeUser.reauthError = null;
      await repo.changePassword(
        currentPassword: 'Atual@123',
        newPassword: 'Nova@1234',
      );
      expect(fakeUser.lastReauthCredential, isNotNull);
      expect(fakeUser.lastUpdatedPassword, 'Nova@1234');

      fakeAuth.user = null;
      await expectLater(
        () => repo.changePassword(
          currentPassword: 'Atual@123',
          newPassword: 'Nova@1234',
        ),
        throwsA(
          predicate((e) => e.toString().contains('Usuário não autenticado.')),
        ),
      );
    });
  });

  group('MyApp sessão inativa', () {
    testWidgets('executa signOut quando currentAppUserProvider emite isActive=false',
        (tester) async {
      final fakeAuth = _FakeAuthRepository();
      final testRouter = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routerProvider.overrideWithValue(testRouter),
            authRepositoryProvider.overrideWithValue(fakeAuth),
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(
                AppUser(
                  id: 'dev-1',
                  email: 'dev@sigo.test',
                  displayName: 'Dev',
                  isActive: false,
                ),
              ),
            ),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCalled, isTrue);
    });
  });

  group('DevUsersRepository', () {
    test('bloqueia chamadas offline e trata lista vazia de conectividade como online',
        () async {
      var called = false;
      final offlineRepo = DevUsersRepository(
        null,
        checkConnectivity: () async => [ConnectivityResult.none],
        callFunction: (name, data) async {
          called = true;
        },
      );

      await expectLater(
        () => offlineRepo.adminDeleteUser('u1'),
        throwsA(
          predicate((e) => e.toString().contains(mensagemSemConexaoDevUsers)),
        ),
      );
      await expectLater(
        () => offlineRepo.adminSetUserActive('u1', false),
        throwsA(
          predicate((e) => e.toString().contains(mensagemSemConexaoDevUsers)),
        ),
      );
      await expectLater(
        () => offlineRepo.adminResetUserPassword('u1', 'Mudar@1234'),
        throwsA(
          predicate((e) => e.toString().contains(mensagemSemConexaoDevUsers)),
        ),
      );
      expect(called, isFalse);

      // Lista vazia do connectivity_plus é tratada como conectada
      final emptyConnRepo = DevUsersRepository(
        null,
        checkConnectivity: () async => <ConnectivityResult>[],
        callFunction: (name, data) async {
          called = true;
        },
      );
      await emptyConnRepo.adminDeleteUser('u1');
      expect(called, isTrue);
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
      expect(
        traduzirErroDevUsers(
          FirebaseFunctionsException(code: 'internal', message: 'internal [0]'),
        ),
        contains('Cloud Functions'),
      );
    });
  });

  group('UsersListScreen', () {
    testWidgets(
        'filtra por status, executa toggle_active, protege isSelf, cria usuário e aprova solicitação (>= 8 chars)',
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
      final fakeMembros = _FakeMembrosRepository();

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

      final pendingRequests = [
        {
          'id': 'req-1',
          'email': 'solicitado@sigo.test',
          'displayName': 'Solicitado',
          'construtoraId': 'c1',
          'role': 'member',
        },
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
            allConstrutorasMapProvider
                .overrideWith((ref) => Stream.value({'c1': 'Construtora C1'})),
            allUserMembershipsProvider.overrideWith((ref) => Stream.value({})),
            allPendingRequestsProvider
                .overrideWith((ref) => Stream.value(pendingRequests)),
            devUsersRepositoryProvider.overrideWithValue(repo),
            membrosRepositoryProvider.overrideWithValue(fakeMembros),
          ],
          child: const MaterialApp(home: UsersListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INATIVO'), findsOneWidget);

      // Filtro: Inativos / Ativos / Todos
      await tester.tap(find.text('Inativos'));
      await tester.pumpAndSettle();
      expect(find.text('Usuário Inativo'), findsOneWidget);
      expect(find.text('Usuário Ativo'), findsNothing);

      await tester.tap(find.text('Ativos'));
      await tester.pumpAndSettle();
      expect(find.text('Usuário Ativo'), findsOneWidget);
      expect(find.text('Usuário Inativo'), findsNothing);

      // Guarda isSelf no menu do próprio dev logado
      await tester.tap(find.byKey(const Key('user-actions-menu-dev-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desativar conta'));
      await tester.pumpAndSettle();
      // Menu permaneceu aberto pois o item está desabilitado; fecha menu
      expect(calls, isEmpty);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Ação toggle_active em outro usuário
      await tester.tap(find.byKey(const Key('user-actions-menu-u-active')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desativar conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Desativar'));
      await tester.pumpAndSettle();
      expect(calls.last.name, 'adminSetUserActive');
      expect(calls.last.data, {'userId': 'u-active', 'isActive': false});

      // Redefinir senha com padrão Mudar@1234
      await tester.tap(find.byKey(const Key('user-actions-menu-u-active')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redefinir senha'));
      await tester.pumpAndSettle();
      expect(find.text('Mudar@1234'), findsOneWidget);
      await tester.tap(find.text('Confirmar Redefinição'));
      await tester.pumpAndSettle();
      expect(calls.last.name, 'adminResetUserPassword');
      expect(calls.last.data, {'userId': 'u-active', 'password': 'Mudar@1234'});

      // _CreateUserDialog: valida < 8 caracteres e cria com >= 8
      await tester.tap(find.text('Novo Usuário'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('create-user-name')),
        'Novo Teste',
      );
      await tester.enterText(
        find.byKey(const Key('create-user-email')),
        'novo@sigo.test',
      );
      await tester.enterText(
        find.byKey(const Key('create-user-password')),
        '1234567',
      );
      await tester.tap(find.byKey(const Key('create-user-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('A senha deve ter no mínimo 8 caracteres.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('create-user-password')),
        'Mudar@1234',
      );
      await tester.tap(find.byKey(const Key('create-user-submit')));
      await tester.pumpAndSettle();
      expect(calls.last.name, 'adminCreateUser');
      expect(calls.last.data['email'], 'novo@sigo.test');
      expect(calls.last.data['password'], 'Mudar@1234');

      // _ApproveRequestDialog: rejeita < 8 chars e aprova com >= 8 chars
      ScaffoldMessenger.of(
        tester.element(find.byType(UsersListScreen)),
      ).clearSnackBars();
      await tester.pump();
      await tester.tap(find.text('Aprovar e Criar Acesso'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '1234567');
      await tester.tap(find.text('Confirmar e Criar'));
      await tester.pumpAndSettle();
      expect(
        find.text('A senha deve ter pelo menos 8 caracteres'),
        findsOneWidget,
      );
      expect(fakeMembros.approvedRequestId, isNull);

      await tester.enterText(find.byType(TextField).last, 'Aprovada@123');
      await tester.tap(find.text('Confirmar e Criar'));
      await tester.pumpAndSettle();
      expect(fakeMembros.approvedRequestId, 'req-1');
      expect(fakeMembros.approvedPassword, 'Aprovada@123');
    });
  });

  group('UserDetailsScreen', () {
    testWidgets(
        'oculta vínculos inativos, preserva owner e isAdmin legado ao remover, exibe erro traduzido, vincula construtora, alterna devRole e exclui com fallback de rota',
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
      await fakeDb.collection('construtoras').doc('c3').set({
        'id': 'c3',
        'name': 'Construtora Gama',
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
      // Vínculo ativo legado: role='member' com isAdmin=true
      await fakeDb
          .collection('construtoras')
          .doc('c3')
          .collection('construtora_members')
          .doc('u-target')
          .set({
        'userId': 'u-target',
        'construtoraId': 'c3',
        'role': 'member',
        'isAdmin': true,
        'isOwner': false,
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
      var failFirstMembership = true;
      final repo = DevUsersRepository(
        null,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        callFunction: (name, data) async {
          calls.add(_RecordedCall(name, data));
          if (name == 'setMembership' && failFirstMembership) {
            failFirstMembership = false;
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
            builder: (_, _) => const Scaffold(body: Text('Lista Destino')),
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

      // Alfa e Gama (isAdmin legado exibido como Administrador) aparecem; Beta inativa oculta
      expect(find.text('Construtora Alfa'), findsOneWidget);
      expect(find.text('Construtora Gama'), findsOneWidget);
      expect(find.textContaining('Papel: Administrador'), findsOneWidget);
      expect(find.text('Construtora Beta'), findsNothing);

      // Remover vínculo owner com erro exibe SnackBar traduzida e preserva owner
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

      // Remover vínculo legado (role='member', isAdmin=true) preserva role='admin'
      await tester.tap(find.byKey(const Key('remove-membership-c3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      expect(calls.last.name, 'setMembership');
      expect(calls.last.data['construtoraId'], 'c3');
      expect(calls.last.data['role'], 'admin');
      expect(calls.last.data['isActive'], isFalse);

      // Switch Acesso de Desenvolvedor chama setDevRole
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(calls.last.name, 'setDevRole');
      expect(calls.last.data, {'userId': 'u-target', 'isActive': true});

      // _LinkConstrutoraDialog vincula construtora via setMembership
      await tester.tap(find.text('Adicionar Vínculo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Construtora Beta').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
      await tester.pumpAndSettle();
      expect(calls.last.name, 'setMembership');
      expect(calls.last.data['construtoraId'], 'c2');
      expect(calls.last.data['isActive'], isTrue);

      // Excluir usuário sem back stack redireciona para /dev/users sem GoError
      await tester.tap(find.byKey(const Key('user-details-delete-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(calls.any((c) => c.name == 'adminDeleteUser'), isTrue);
      expect(find.text('Lista Destino'), findsOneWidget);
    });

    testWidgets('bloqueia auto-alteração de devRole, desativação e exclusão (isSelf)',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('users').doc('dev-1').set({
        'id': 'dev-1',
        'email': 'dev@sigo.test',
        'displayName': 'Dev Atual',
        'globalRole': 'dev',
        'isActive': true,
      });

      final repo = DevUsersRepository(
        null,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        callFunction: (name, data) async {},
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
          child: MaterialApp(
            home: UserDetailsScreen(userId: 'dev-1', firestore: fakeDb),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.onChanged, isNull);

      final toggleBtn = tester.widget<OutlinedButton>(
        find.byKey(const Key('user-details-toggle-active-btn')),
      );
      expect(toggleBtn.onPressed, isNull);

      final deleteBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('user-details-delete-btn')),
      );
      expect(deleteBtn.onPressed, isNull);
    });
  });

  group('SigoTopBar alterar senha', () {
    testWidgets(
        'abre diálogo no menu do avatar, exibe erro inline em falha e salva em sucesso',
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

      // Validação local (< 8 e divergente)
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

      // Erro retornado por AuthRepository aparece inline no diálogo aberto
      fakeAuth.errorToThrow = Exception('Senha atual incorreta.');
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

      expect(find.text('Senha atual incorreta.'), findsOneWidget);
      expect(find.text('Alterar Senha'), findsOneWidget);

      // Sucesso fecha diálogo e exibe SnackBar
      fakeAuth.errorToThrow = null;
      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();

      expect(fakeAuth.lastCurrentPassword, 'Atual@123');
      expect(fakeAuth.lastNewPassword, 'NovaSenha@123');
      expect(find.text('Senha alterada com sucesso!'), findsOneWidget);
    });
  });
}

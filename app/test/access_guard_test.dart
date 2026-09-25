import 'package:app/src/common_widgets/access_guard.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('rota direta nao autorizada em obra bloqueia via AccessGuard', (
    tester,
  ) async {
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
                    modules: ['lotes'],
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
  });

  testWidgets('obra inativa nega acesso para usuario comum', (tester) async {
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
  });

  testWidgets('admin de construtora nao bypassa verificaao de obra inativa', (
    tester,
  ) async {
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
  });

  testWidgets('obra inativa preserva acesso de suporte para dev global', (
    tester,
  ) async {
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
  });

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
    'AccessGuard construtora-level module check with allowedModules fallback',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({
                'isActive': true,
                'isAdmin': false,
                'allowedModules': ['diario'],
              }),
            ),
          ],
          child: const MaterialApp(
            home: AccessGuard(
              construtoraId: 'c1',
              obraId: null,
              module: 'diario',
              child: Text('allowed via fallback'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('allowed via fallback'), findsOneWidget);
    },
  );

  testWidgets('admin de construtora com obra ativa recebe acesso', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
          ),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraA'))
              .overrideWith(
                (ref) => Stream.value(
                  ObraMember(
                    userId: 'u1',
                    isActive: true,
                    isAdmin: true,
                    modules: ['diario', 'lotes', 'estoque'],
                    joinedAt: DateTime(2025),
                  ),
                ),
              ),
        ],
        child: const MaterialApp(
          home: AccessGuard(
            construtoraId: 'c1',
            obraId: 'obraA',
            child: Text('painel admin'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('painel admin'), findsOneWidget);
  });

  testWidgets('admin de construtora sem doc de obra recebe acesso (fallback)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({'isActive': true, 'isOwner': true}),
          ),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraB'))
              .overrideWith(
                (ref) => Stream.value(
                  ObraMember(
                    userId: 'u1',
                    isActive: true,
                    isAdmin: true,
                    modules: ['diario', 'lotes', 'estoque'],
                    joinedAt: DateTime(2025),
                  ),
                ),
              ),
        ],
        child: const MaterialApp(
          home: AccessGuard(
            construtoraId: 'c1',
            obraId: 'obraB',
            child: Text('painel owner'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('painel owner'), findsOneWidget);
  });

  testWidgets('membro central com modules libera modulo sem allowedModules', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({
              'isActive': true,
              'isAdmin': false,
              'modules': ['diario'],
            }),
          ),
        ],
        child: const MaterialApp(
          home: AccessGuard(
            construtoraId: 'c1',
            module: 'diario',
            child: Text('central diario'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('central diario'), findsOneWidget);
  });

  testWidgets(
    'adminOnly+module lotes nega membro ativo nao-admin mesmo com o modulo',
    (tester) async {
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
          child: const MaterialApp(
            home: AccessGuard(
              construtoraId: 'c1',
              module: 'lotes',
              adminOnly: true,
              child: Text('novo lote'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('novo lote'), findsNothing);
      expect(find.text('Acesso Negado'), findsOneWidget);
    },
  );

  testWidgets('module lotes sem o modulo central nega membro ativo nao-admin', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({
              'isActive': true,
              'isAdmin': false,
              'modules': ['diario'],
            }),
          ),
        ],
        child: const MaterialApp(
          home: AccessGuard(
            construtoraId: 'c1',
            module: 'lotes',
            child: Text('lotes'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('lotes'), findsNothing);
    expect(find.text('Acesso Negado'), findsOneWidget);
  });

  testWidgets(
    'module lotes com o modulo central permite membro ativo nao-admin',
    (tester) async {
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
          child: const MaterialApp(
            home: AccessGuard(
              construtoraId: 'c1',
              module: 'lotes',
              child: Text('lotes'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('lotes'), findsOneWidget);
    },
  );

  testWidgets('adminOnly+module lotes permite admin de construtora', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          construtoraPermissionProvider('c1').overrideWith(
            (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
          ),
        ],
        child: const MaterialApp(
          home: AccessGuard(
            construtoraId: 'c1',
            module: 'lotes',
            adminOnly: true,
            child: Text('novo lote'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('novo lote'), findsOneWidget);
  });
}

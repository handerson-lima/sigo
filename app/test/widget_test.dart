import 'package:app/main.dart';
import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/common_widgets/access_guard.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

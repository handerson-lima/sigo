import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/construtoras/domain/construtora.dart';
import 'package:app/src/features/construtoras/presentation/user_construtoras_provider.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/chamada_form_fixture.dart';

void main() {
  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        authStateChangesProvider.overrideWithValue(
          AsyncValue.data(TestUser('u1', 'User Name', 'u1@example.com')),
        ),
        trustedDevProvider.overrideWithValue(const AsyncValue.data(false)),
        userConstrutorasProvider.overrideWith((ref) async => <Construtora>[]),
        watchLoteamentosProvider.overrideWith(
          (ref, arg) => Stream.value(const []),
        ),
        construtoraPermissionProvider('c1')
            .overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    return router;
  }

  testWidgets('redirect legado /construtora usa o routerProvider real', (
    tester,
  ) async {
    final router = await pumpRouter(tester);

    Future<String> go(String location) async {
      router.go(location);
      await tester.pump(const Duration(milliseconds: 50));
      return router.state.uri.toString();
    }

    expect(
      await go('/construtora/c1/loteamentos?q=1#frag'),
      '/construtoras/c1/loteamentos?q=1#frag',
    );
    expect(await go('/construtora/c1/membros'), '/construtoras/c1/membros');
    expect(
      await go('/construtoras/c1/loteamentos'),
      '/construtoras/c1/loteamentos',
    );
  });
}

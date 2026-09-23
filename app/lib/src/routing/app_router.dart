import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/data/user_repository.dart';

import '../features/authentication/routing/auth_routes.dart';
import '../features/developer/routing/dev_routes.dart';
import '../features/construtoras/routing/construtora_routes.dart';
import '../features/obras/routing/obra_routes.dart';
import '../features/lotes/routing/lotes_routes.dart';
import '../features/almoxarifado/routing/almoxarifado_routes.dart';
import '../features/diario/routing/diario_routes.dart';
import '../features/rh/routing/rh_routes.dart';
import '../features/epi/routing/epi_routes.dart';
import '../features/financeiro/routing/financeiro_routes.dart';
import '../features/validacao/routing/validacao_routes.dart';
import '../features/despesas_adm/routing/despesas_adm_routes.dart';
import '../features/fornecedores/routing/fornecedores_routes.dart';
import '../features/compras_parcelas/routing/compras_routes.dart';
import '../features/custos_360/routing/custos_360_routes.dart';

// Opcional: Uma tela 404 padrão
import 'package:flutter/material.dart';

class ErrorScreen extends StatelessWidget {
  final Exception? error;
  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Página não encontrada')),
      body: Center(
        child: Text(error?.toString() ?? 'A rota solicitada não existe.'),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final devState = ref.watch(trustedDevProvider);

  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
    redirect: (context, state) {
      final isLoading = authState.isLoading || devState.isLoading;
      if (isLoading) return null;

      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuth) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return '/';
      }

      if (state.matchedLocation.startsWith('/dev')) {
        final isDev = devState.value == true;
        if (!isDev) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      ...authRoutes,
      ...devRoutes,
      ...construtoraRoutes, // Modificado internamente
    ],
  );
});

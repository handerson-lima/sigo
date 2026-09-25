import 'package:go_router/go_router.dart';

import '../presentation/login_screen.dart';

/// Constantes de path para autenticação.
abstract class AuthPaths {
  static const login = '/login';
}

/// Rotas do módulo de autenticação.
List<RouteBase> get authRoutes => [
  GoRoute(
    path: AuthPaths.login,
    builder: (context, state) => const LoginScreen(),
  ),
];

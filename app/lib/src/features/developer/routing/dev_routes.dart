import 'package:go_router/go_router.dart';

import '../presentation/dev_panel_screen.dart';
import '../presentation/users_list_screen.dart';
import '../presentation/user_details_screen.dart';
import '../presentation/dev_construtoras_list_screen.dart';

/// Constantes de path para o painel de desenvolvedor.
abstract class DevPaths {
  static const panel = '/dev';
  static const users = '/dev/users';
  static const userDetails = '/dev/users/:uid';
  static const construtoras = '/dev/construtoras';

  static String userDetailsFor(String uid) => '/dev/users/$uid';
}

/// Rotas do módulo de desenvolvedor.
List<RouteBase> get devRoutes => [
  GoRoute(
    path: DevPaths.panel,
    builder: (context, state) => const DevPanelScreen(),
  ),
  GoRoute(
    path: DevPaths.users,
    builder: (context, state) => const UsersListScreen(),
  ),
  GoRoute(
    path: DevPaths.userDetails,
    builder: (context, state) {
      final uid = state.pathParameters['uid']!;
      return UserDetailsScreen(userId: uid);
    },
  ),
  GoRoute(
    path: DevPaths.construtoras,
    builder: (context, state) => const DevConstrutorasListScreen(),
  ),
];

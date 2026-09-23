import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/financeiro_list_screen.dart';
import '../presentation/add_despesa_screen.dart';

/// Constantes de path para financeiro.
abstract class FinanceiroPaths {
  static const list = 'financeiro';
  static const novo = 'financeiro/novo';

  static String listFor(String cId) => '/construtora/$cId/financeiro';
  static String novoFor(String cId) => '/construtora/$cId/financeiro/novo';
}

/// Rotas do módulo financeiro.
List<RouteBase> get financeiroRoutes => [
      GoRoute(
        path: FinanceiroPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'financeiro',
            adminOnly: true,
            child: FinanceiroListScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: FinanceiroPaths.novo,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'financeiro',
            adminOnly: true,
            child: AddDespesaScreen(construtoraId: cId),
          );
        },
      ),
    ];

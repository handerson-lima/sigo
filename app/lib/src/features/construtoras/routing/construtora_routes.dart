import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/construtoras_list_screen.dart';
import '../../obras/presentation/obras_list_screen.dart';
import '../presentation/membros_screen.dart';

import '../../obras/routing/obra_routes.dart';
import '../../lotes/routing/lotes_routes.dart';
import '../../almoxarifado/routing/almoxarifado_routes.dart';
import '../../diario/routing/diario_routes.dart';
import '../../rh/routing/rh_routes.dart';
import '../../epi/routing/epi_routes.dart';
import '../../financeiro/routing/financeiro_routes.dart';
import '../../validacao/routing/validacao_routes.dart';
import '../../despesas_adm/routing/despesas_adm_routes.dart';
import '../../fornecedores/routing/fornecedores_routes.dart';
import '../../compras_parcelas/routing/compras_routes.dart';
import '../../custos_360/routing/custos_360_routes.dart';

/// Constantes de path para construtoras.
abstract class ConstrutoraPaths {
  static const list = '/';
  static const detail = '/construtora/:cId';
  static const membros = 'membros';

  static String detailFor(String cId) => '/construtora/$cId';
  static String membrosFor(String cId) => '/construtora/$cId/membros';
}

/// Rotas do módulo de construtoras.
List<RouteBase> get construtoraRoutes => [
      GoRoute(
        path: ConstrutoraPaths.list,
        builder: (context, state) => const ConstrutorasListScreen(),
      ),
      GoRoute(
        path: ConstrutoraPaths.detail,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            child: ObrasListScreen(construtoraId: cId),
          );
        },
        routes: [
          GoRoute(
            path: ConstrutoraPaths.membros,
            builder: (context, state) {
              final cId = state.pathParameters['cId']!;
              return AccessGuard(
                construtoraId: cId,
                adminOnly: true,
                child: MembrosScreen(construtoraId: cId),
              );
            },
          ),
          ...obraRoutes,
          ...lotesRoutes,
          ...almoxarifadoRoutes,
          ...diarioRoutes,
          ...rhRoutes,
          ...epiRoutes,
          ...financeiroRoutes,
          ...validacaoRoutes,
          ...fornecedoresRoutes,
          ...comprasRoutes,
          ...custos360Routes,
          ...despesasAdmRoutes,
        ],
      ),
    ];

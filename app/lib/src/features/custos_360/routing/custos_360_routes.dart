import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/visao_360_custos_screen.dart';
import '../presentation/lote_custo_detalhe_screen.dart';

/// Constantes de path para custos 360.
abstract class Custos360Paths {
  static const visao360 = 'obra/:oId/custos-360';
  static const loteCusto =
      'obra/:oId/custos-360/lotes/:loteId';

  static String visao360For(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/custos-360';
  static String loteCustoFor(String cId, String oId, String loteId) =>
      '/construtora/$cId/obra/$oId/custos-360/lotes/$loteId';
}

/// Rotas do módulo de custos 360.
List<RouteBase> get custos360Routes => [
      GoRoute(
        path: Custos360Paths.visao360,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'adm',
            child: Visao360CustosScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
      GoRoute(
        path: Custos360Paths.loteCusto,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          final loteId = state.pathParameters['loteId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'adm',
            child: LoteCustoDetalheScreen(
              construtoraId: cId,
              obraId: oId,
              loteId: loteId,
            ),
          );
        },
      ),
    ];

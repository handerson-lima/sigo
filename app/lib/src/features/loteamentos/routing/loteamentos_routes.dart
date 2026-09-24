import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/loteamentos_list_screen.dart';
import '../../../common_widgets/access_guard.dart';
import '../../quadras/routing/quadras_routes.dart';

abstract class LoteamentosPaths {
  static const list = 'loteamentos';
  static const detail = 'loteamentos/:loteamentoId';
}

List<RouteBase> get loteamentosRoutes => [
      GoRoute(
        path: LoteamentosPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            child: LoteamentosListScreen(
              construtoraId: cId,
            ),
          );
        },
        routes: [
          GoRoute(
            path: ':loteamentoId',
            builder: (context, state) {
              // Just a placeholder or QuadrasListScreen
              // In nested routing, usually we want a Dashboard or redirect to Quadras
              // Let's just return a placeholder or direct builder if needed.
              // Actually, quadrasRoutes will be attached here.
              return const SizedBox(); // Not directly accessed, we access quadras
            },
            routes: [
              ...quadrasRoutes,
            ],
          )
        ],
      ),
    ];

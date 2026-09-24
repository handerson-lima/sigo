import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/quadras_list_screen.dart';
import '../../../common_widgets/access_guard.dart';
import '../../lotes/routing/lotes_routes.dart';

abstract class QuadrasPaths {
  static const list = 'quadras';
  static const detail = 'quadras/:quadraId';
}

List<RouteBase> get quadrasRoutes => [
      GoRoute(
        path: QuadrasPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final loteamentoId = state.pathParameters['loteamentoId']!;
          return AccessGuard(
            construtoraId: cId,
            child: QuadrasListScreen(
              construtoraId: cId,
              loteamentoId: loteamentoId,
            ),
          );
        },
        routes: [
          GoRoute(
            path: ':quadraId',
            builder: (context, state) {
              return const SizedBox();
            },
            routes: [
              ...lotesRoutes,
            ],
          )
        ],
      ),
    ];

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/setores_list_screen.dart';
import '../../../common_widgets/access_guard.dart';
import '../../equipes/routing/equipes_routes.dart';

abstract class SetoresPaths {
  static const list = 'setores';
  static const detail = 'setores/:setorId';
}

List<RouteBase> get setoresRoutes => [
      GoRoute(
        path: SetoresPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final loteamentoId = state.pathParameters['loteamentoId']!;
          final quadraId = state.pathParameters['quadraId']!;
          final loteId = state.pathParameters['loteId']!;
          return AccessGuard(
            construtoraId: cId,
            child: SetoresListScreen(
              construtoraId: cId,
              loteamentoId: loteamentoId,
              quadraId: quadraId,
              loteId: loteId,
            ),
          );
        },
        routes: [
          GoRoute(
            path: ':setorId',
            builder: (context, state) {
              return const SizedBox();
            },
            routes: [
              ...equipesRoutes,
            ],
          )
        ],
      ),
    ];

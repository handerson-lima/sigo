import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/data/auth_repository.dart';
import '../features/notifications/presentation/notifications_button.dart';
import '../features/loteamentos/data/loteamento_repository.dart';
import '../sync/sync_indicator.dart';
import '../design_system/sigo_theme.dart';
import 'sidebar_state.dart';

class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final String? activeRoute;

  const SigoTopBar({
    super.key,
    required this.title,
    this.actions,
    this.activeRoute,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  String? _resolveRoute(BuildContext context) {
    if (activeRoute != null && activeRoute!.isNotEmpty) return activeRoute;
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return null;
    }
  }

  bool _canPop(BuildContext context) {
    try {
      return context.canPop();
    } catch (_) {
      try {
        return Navigator.of(context).canPop();
      } catch (_) {
        return false;
      }
    }
  }

  void _pop(BuildContext context) {
    try {
      context.pop();
    } catch (_) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final user = authState.value;
    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    final route = _resolveRoute(context);
    String? cId;
    String? oId;
    if (route != null) {
      final uri = Uri.tryParse(route);
      final segments = uri?.pathSegments ?? [];
      if (segments.length >= 2 && segments[0] == 'construtoras') {
        cId = segments[1];
        if (segments.length >= 4 &&
            (segments[2] == 'obra' || segments[2] == 'loteamentos')) {
          oId = segments[3];
        }
      }
    }

    final hasBack = _canPop(context);
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final isSidebarCollapsed = ref.watch(sidebarCollapsedProvider);

    void handleMenuPressed() {
      if (hasDrawer) {
        Scaffold.of(context).openDrawer();
      } else {
        ref.read(sidebarCollapsedProvider.notifier).toggle();
      }
    }

    final theme = Theme.of(context).extension<SigoThemeExtension>();

    return AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme?.headerStart ?? const Color(0xFF0D47A1),
              theme?.headerEnd ?? const Color(0xFF1565C0),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 8,
      iconTheme: IconThemeData(color: theme?.focusHeader ?? Colors.white),
      leadingWidth: hasBack ? 96 : 56,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('sigo-hamburger-button'),
            icon: Icon(Icons.menu, color: theme?.focusHeader ?? Colors.white),
            tooltip: hasDrawer
                ? 'Abrir menu'
                : (isSidebarCollapsed ? 'Expandir menu' : 'Recolher menu'),
            onPressed: handleMenuPressed,
          ),
          if (hasBack)
            IconButton(
              key: const Key('sigo-back-button'),
              icon: Icon(
                Icons.arrow_back,
                color: theme?.focusHeader ?? Colors.white70,
              ),
              tooltip: 'Voltar',
              onPressed: () => _pop(context),
            ),
        ],
      ),
      title: cId != null && oId != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (hasBack)
                          TextSpan(
                            text: 'Voltar • ',
                            style: TextStyle(
                              color:
                                  theme?.focusHeader.withValues(alpha: 0.8) ??
                                  Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        TextSpan(
                          text: title,
                          style: TextStyle(
                            color: theme?.focusHeader ?? Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                LoteamentoSwitcher(
                  construtoraId: cId,
                  currentLoteamentoId: oId,
                ),
              ],
            )
          : Text.rich(
              TextSpan(
                children: [
                  if (hasBack)
                    TextSpan(
                      text: 'Voltar • ',
                      style: TextStyle(
                        color:
                            theme?.focusHeader.withValues(alpha: 0.8) ??
                            Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  TextSpan(
                    text: title,
                    style: TextStyle(
                      color: theme?.focusHeader ?? Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
      actions: [
        ...?actions,
        SyncIndicator(construtoraId: cId, obraId: oId),
        const SizedBox(width: 6),
        const NotificationsButton(),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: Colors.amber[100],
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.amber[900],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

class LoteamentoSwitcher extends ConsumerWidget {
  final String construtoraId;
  final String currentLoteamentoId;

  const LoteamentoSwitcher({
    super.key,
    required this.construtoraId,
    required this.currentLoteamentoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loteamentosAsync = ref.watch(
      watchLoteamentosProvider((construtoraId: construtoraId)),
    );
    return loteamentosAsync.maybeWhen(
      data: (loteamentos) {
        if (loteamentos.isEmpty) return const SizedBox.shrink();
        final isSelectedPresent = loteamentos.any(
          (l) => l.id == currentLoteamentoId,
        );
        final selectedValue = isSelectedPresent ? currentLoteamentoId : null;

        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('loteamento-switcher-dropdown'),
              value: selectedValue,
              hint: const Text(
                'Selecionar Loteamento',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              icon: const Icon(Icons.swap_horiz, size: 18, color: Colors.amber),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: loteamentos.map((l) {
                return DropdownMenuItem<String>(
                  key: Key('loteamento-switcher-item-${l.id}'),
                  value: l.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business,
                        size: 14,
                        color: l.id == currentLoteamentoId
                            ? Colors.amber[900]
                            : Colors.black45,
                      ),
                      const SizedBox(width: 6),
                      Text(l.name, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newLoteamentoId) {
                if (newLoteamentoId != null &&
                    newLoteamentoId != currentLoteamentoId) {
                  context.go(
                    '/construtoras/$construtoraId/obra/$newLoteamentoId',
                  );
                }
              },
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

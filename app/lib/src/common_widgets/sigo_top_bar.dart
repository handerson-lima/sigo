import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/data/auth_repository.dart';
import '../features/obras/presentation/construtora_obras_provider.dart';
import '../sync/sync_indicator.dart';
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
      if (segments.length >= 2 && segments[0] == 'construtora') {
        cId = segments[1];
        if (segments.length >= 4 && segments[2] == 'obra') {
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

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 8,
      iconTheme: const IconThemeData(
        color: Colors.black87,
      ),
      leadingWidth: hasBack ? 96 : 56,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('sigo-hamburger-button'),
            icon: const Icon(Icons.menu, color: Colors.black87),
            tooltip: hasDrawer
                ? 'Abrir menu'
                : (isSidebarCollapsed ? 'Expandir menu' : 'Recolher menu'),
            onPressed: handleMenuPressed,
          ),
          if (hasBack)
            IconButton(
              key: const Key('sigo-back-button'),
              icon: const Icon(Icons.arrow_back, color: Colors.black54),
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
                          const TextSpan(
                            text: 'Voltar • ',
                            style:
                                TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                        TextSpan(
                          text: title,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 14),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                ObraSwitcher(
                  construtoraId: cId,
                  currentObraId: oId,
                ),
              ],
            )
          : Text.rich(
              TextSpan(
                children: [
                  if (hasBack)
                    const TextSpan(
                      text: 'Voltar • ',
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  TextSpan(
                    text: title,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
      actions: [
        ...?actions,
        SyncIndicator(
          construtoraId: cId,
          obraId: oId,
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black54),
          onPressed: () {},
        ),
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

class ObraSwitcher extends ConsumerWidget {
  final String construtoraId;
  final String currentObraId;

  const ObraSwitcher({
    super.key,
    required this.construtoraId,
    required this.currentObraId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obrasAsync = ref.watch(construtoraObrasProvider(construtoraId));
    return obrasAsync.maybeWhen(
      data: (obras) {
        if (obras.isEmpty) return const SizedBox.shrink();
        final isSelectedPresent = obras.any((o) => o.id == currentObraId);
        final selectedValue = isSelectedPresent ? currentObraId : null;

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
              key: const Key('obra-switcher-dropdown'),
              value: selectedValue,
              hint: const Text(
                'Selecionar Obra',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              icon: const Icon(Icons.swap_horiz, size: 18, color: Colors.amber),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: obras.map((o) {
                return DropdownMenuItem<String>(
                  key: Key('obra-switcher-item-${o.id}'),
                  value: o.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business,
                        size: 14,
                        color: o.id == currentObraId
                            ? Colors.amber[900]
                            : Colors.black45,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        o.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newObraId) {
                if (newObraId != null && newObraId != currentObraId) {
                  context.go('/construtora/$construtoraId/obra/$newObraId');
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

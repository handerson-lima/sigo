import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/data/user_repository.dart';
import '../features/obras/presentation/current_permissions_provider.dart';
import '../features/obras/presentation/access_denied_screen.dart';
import '../core/contracts.dart';

class AccessGuard extends ConsumerWidget {
  final String? construtoraId, obraId, module;
  final bool adminOnly, devOnly;
  final Widget child;
  const AccessGuard({
    super.key,
    this.construtoraId,
    this.obraId,
    this.module,
    this.adminOnly = false,
    this.devOnly = false,
    required this.child,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dev = ref.watch(trustedDevProvider);
    if (dev.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (dev.value == true) return child;
    if (devOnly || construtoraId == null) return const AccessDeniedScreen();
    final cm = ref.watch(construtoraPermissionProvider(construtoraId!));
    if (cm.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final member = cm.value;
    if (cm.hasError || member?['isActive'] != true) {
      return const AccessDeniedScreen();
    }
    final admin = member?['isAdmin'] == true || member?['isOwner'] == true;
    if (admin) return child;
    if (obraId != null) {
      final om = ref.watch(
        currentPermissionsProvider((
          construtoraId: construtoraId!,
          obraId: obraId!,
        )),
      );
      if (om.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final obra = om.value;
      if (obra == null ||
          !obra.isActive ||
          adminOnly && !obra.isAdmin ||
          module != null &&
              !obra.isAdmin &&
              !obra.modules.contains(normalizeModule(module!))) {
        return const AccessDeniedScreen();
      }
      return child;
    }
    if (adminOnly ||
        module == 'financeiro' ||
        module != null &&
            !(member?['modules'] as List? ?? [])
                .map((m) => normalizeModule(m as String))
                .contains(normalizeModule(module!))) {
      return const AccessDeniedScreen();
    }
    return child;
  }
}

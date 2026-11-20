import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/data/user_repository.dart';
import '../features/obras/presentation/current_permissions_provider.dart';
import '../features/obras/presentation/access_denied_screen.dart';
import '../core/contracts.dart';

class AccessGuard extends ConsumerWidget {
  final String? construtoraId, obraId, loteamentoId, module;
  final bool adminOnly, devOnly;
  final Widget child;
  const AccessGuard({
    super.key,
    this.construtoraId,
    this.obraId,
    this.loteamentoId,
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
    final admin = isConstrutoraAdminMember(member);
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

    final centralModules = normalizeRawModules(
      member?['modules'],
      member?['allowedModules'],
    );

    if (loteamentoId != null) {
      final resolvedAsync = ref.watch(
        effectiveLoteamentoObraIdProvider((
          construtoraId: construtoraId!,
          loteamentoId: loteamentoId!,
        )),
      );
      if (resolvedAsync.isLoading && !resolvedAsync.hasValue) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final effectiveObraId = resolvedAsync.value ?? loteamentoId!;
      final obraDocAsync = ref.watch(
        obraDocProvider((
          construtoraId: construtoraId!,
          obraId: effectiveObraId,
        )),
      );
      if (obraDocAsync.value != null &&
          obraDocAsync.value!['isActive'] == false) {
        return const AccessDeniedScreen();
      }

      final om = ref.watch(
        currentPermissionsProvider((
          construtoraId: construtoraId!,
          obraId: effectiveObraId,
        )),
      );
      if (om.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final obra = om.value;
      if (obra != null) {
        if (!obra.isActive ||
            (adminOnly && !obra.isAdmin) ||
            (module != null &&
                !obra.isAdmin &&
                !obra.modules.contains(normalizeModule(module!)))) {
          return const AccessDeniedScreen();
        }
        return child;
      }

      if (admin) return child;
      if (!adminOnly &&
          module != null &&
          centralModules.contains(normalizeModule(module!))) {
        return child;
      }
      return const AccessDeniedScreen();
    }

    if (admin) return child;
    if (adminOnly ||
        module == 'financeiro' ||
        module != null && !centralModules.contains(normalizeModule(module!))) {
      return const AccessDeniedScreen();
    }
    return child;
  }
}

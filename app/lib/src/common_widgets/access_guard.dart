import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/data/user_repository.dart';
import '../features/loteamentos/data/loteamento_repository.dart';
import '../features/loteamentos/domain/loteamento.dart';
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
      final loteamentosAsync = ref.watch(
        watchLoteamentosProvider((construtoraId: construtoraId!)),
      );
      if (loteamentosAsync.isLoading && !loteamentosAsync.hasValue) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (loteamentosAsync.hasError) {
        return Scaffold(
          body: Center(
            child: Text('Erro de validação: ${loteamentosAsync.error}'),
          ),
        );
      }
      final matchedLoteamento = (loteamentosAsync.value ?? const <Loteamento>[])
          .where((l) => l.id == loteamentoId && l.construtoraId == construtoraId)
          .firstOrNull;
      if (matchedLoteamento == null) {
        return const AccessDeniedScreen();
      }
      final effectiveObraId = matchedLoteamento.effectiveObraId;

      final om = ref.watch(
        currentPermissionsProvider((
          construtoraId: construtoraId!,
          obraId: effectiveObraId,
        )),
      );
      if (om.isLoading && !om.hasValue) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (om.hasError) {
        return Scaffold(
          body: Center(child: Text('Erro de validação: ${om.error}')),
        );
      }
      final obra = om.value;

      if (admin || obra != null) {
        final obraDocAsync = ref.watch(
          obraDocProvider((
            construtoraId: construtoraId!,
            obraId: effectiveObraId,
          )),
        );
        if (obraDocAsync.isLoading && !obraDocAsync.hasValue) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (obraDocAsync.value != null &&
            obraDocAsync.value!['isActive'] == false) {
          return const AccessDeniedScreen();
        }
      }

      if (admin) return child;
      if (obra != null) {
        if (!obra.isActive || (adminOnly && !obra.isAdmin)) {
          return const AccessDeniedScreen();
        }
        if (module == null ||
            obra.isAdmin ||
            obra.modules.contains(normalizeModule(module!)) ||
            (!adminOnly &&
                centralModules.contains(normalizeModule(module!)))) {
          return child;
        }
        return const AccessDeniedScreen();
      }

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

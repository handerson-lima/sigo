import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/data/auth_repository.dart';
import '../features/notifications/presentation/notifications_button.dart';
import '../features/loteamentos/data/loteamento_repository.dart';
import '../features/obras/presentation/current_permissions_provider.dart';
import '../sync/sync_indicator.dart';
import '../design_system/sigo_theme.dart';
import 'sidebar_state.dart';

enum _SigoAvatarMenuAction { changePassword }

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
    String? switcherScopeId;
    var isObraContext = false;
    if (route != null) {
      final uri = Uri.tryParse(route);
      final segments = uri?.pathSegments ?? [];
      if (segments.length >= 2 && segments[0] == 'construtoras') {
        cId = segments[1];
        if (segments.length >= 4 && segments[2] == 'obra') {
          isObraContext = true;
          oId = segments[3];
          switcherScopeId = oId;
        } else if (segments.length >= 4 &&
            segments[2] == 'loteamentos' &&
            segments[3] != 'import' &&
            segments[3] != 'draft') {
          switcherScopeId = segments[3];
          oId =
              ref
                  .watch(
                    effectiveLoteamentoObraIdProvider((
                      construtoraId: cId,
                      loteamentoId: switcherScopeId,
                    )),
                  )
                  .value ??
              switcherScopeId;
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
      title: cId != null && switcherScopeId != null
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
                const SizedBox(width: 8),
                Flexible(
                  flex: 2,
                  child: LoteamentoSwitcher(
                    construtoraId: cId,
                    currentLoteamentoId: switcherScopeId,
                    isObraContext: isObraContext,
                  ),
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
        PopupMenuButton<_SigoAvatarMenuAction>(
          key: const Key('sigo-avatar-menu'),
          tooltip: 'Conta',
          enabled: user != null,
          onSelected: (value) {
            if (value == _SigoAvatarMenuAction.changePassword) {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const _ChangePasswordDialog(),
              );
            }
          },
          itemBuilder: (ctx) => [
            if (email.isNotEmpty) ...[
              PopupMenuItem<_SigoAvatarMenuAction>(
                enabled: false,
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const PopupMenuDivider(),
            ],
            const PopupMenuItem<_SigoAvatarMenuAction>(
              value: _SigoAvatarMenuAction.changePassword,
              child: Row(
                children: [
                  Icon(Icons.lock_reset, size: 18),
                  SizedBox(width: 8),
                  Flexible(child: Text('Alterar senha')),
                ],
              ),
            ),
          ],
          child: CircleAvatar(
            backgroundColor: Colors.amber[100],
            child: Text(
              initial,
              style: TextStyle(
                color: Colors.amber[900],
                fontWeight: FontWeight.bold,
              ),
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
  final bool isObraContext;

  const LoteamentoSwitcher({
    super.key,
    required this.construtoraId,
    required this.currentLoteamentoId,
    this.isObraContext = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loteamentosAsync = ref.watch(
      watchLoteamentosProvider((construtoraId: construtoraId)),
    );
    return loteamentosAsync.maybeWhen(
      data: (loteamentos) {
        if (loteamentos.isEmpty) return const SizedBox.shrink();
        String? selectedValue;
        for (final l in loteamentos) {
          if (l.id == currentLoteamentoId) {
            selectedValue = l.id;
            break;
          }
        }
        selectedValue ??= loteamentos
            .where((l) => l.effectiveObraId == currentLoteamentoId)
            .map((l) => l.id)
            .firstOrNull;

        return Container(
          constraints: const BoxConstraints(maxWidth: 210),
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
              isExpanded: true,
              value: selectedValue,
              hint: const Text(
                'Selecionar Loteamento',
                overflow: TextOverflow.ellipsis,
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
                        color: l.id == selectedValue
                            ? Colors.amber[900]
                            : Colors.black45,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(l.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newLoteamentoId) {
                if (newLoteamentoId != null &&
                    newLoteamentoId != selectedValue) {
                  if (isObraContext) {
                    final target = loteamentos
                        .where((l) => l.id == newLoteamentoId)
                        .firstOrNull;
                    final targetObraId =
                        target?.effectiveObraId ?? newLoteamentoId;
                    context.go(
                      '/construtoras/$construtoraId/obra/$targetObraId',
                    );
                  } else {
                    context.go(
                      '/construtoras/$construtoraId/loteamentos/$newLoteamentoId',
                    );
                  }
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

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isSaving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _currentPassCtrl.text,
            newPassword: _newPassCtrl.text,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: const Text('Senha alterada com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().startsWith('Exception: ')
            ? e.toString().substring(11)
            : e.toString();
        setState(() => _errorMessage = msg);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_reset, color: Colors.orange),
          SizedBox(width: 8),
          Text('Alterar Senha'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('change-password-current'),
                  controller: _currentPassCtrl,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Senha atual',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Informe sua senha atual.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('change-password-new'),
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nova senha',
                    helperText: 'Mínimo de 8 caracteres.',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 8) {
                      return 'A nova senha deve ter no mínimo 8 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('change-password-confirm'),
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmar nova senha',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (val) {
                    if (val != _newPassCtrl.text) {
                      return 'As senhas não coincidem.';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('change-password-submit'),
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar Nova Senha'),
        ),
      ],
    );
  }
}

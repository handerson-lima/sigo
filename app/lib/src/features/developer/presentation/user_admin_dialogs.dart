import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../authentication/domain/app_user.dart';

/// Senha padrão sugerida em diálogos de senha provisória para o perfil Dev.
const defaultProvisionalPassword = 'Mudar@1234';

/// Exibe o diálogo de redefinição de senha provisória (mínimo 8 caracteres,
/// pré-preenchido com [defaultProvisionalPassword] e com botão de copiar).
Future<String?> showResetPasswordDialog(
  BuildContext context, {
  required String userLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _ResetPasswordDialog(userLabel: userLabel),
  );
}

/// Exibe confirmação para ativar ou desativar a conta do [user].
Future<bool?> showConfirmToggleUserActiveDialog(
  BuildContext context, {
  required AppUser user,
}) {
  final deactivating = user.isActive;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(deactivating ? 'Desativar usuário?' : 'Ativar usuário?'),
      content: Text(
        deactivating
            ? 'O usuário ${user.displayName} (${user.email}) será bloqueado no Auth e no Firestore, com sessões ativas revogadas. Os vínculos em construtoras e obras serão preservados.'
            : 'O usuário ${user.displayName} (${user.email}) terá o acesso reativado no Auth e no Firestore com seus vínculos preservados.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: deactivating ? Colors.orange.shade700 : Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: Text(deactivating ? 'Desativar' : 'Ativar'),
        ),
      ],
    ),
  );
}

/// Exibe confirmação de exclusão global permanente do [user].
Future<bool?> showConfirmDeleteUserDialog(
  BuildContext context, {
  required AppUser user,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Excluir usuário permanentemente?'),
      content: Text(
        'A conta de ${user.displayName} (${user.email}) será removida do Auth, além do perfil, notificações e vínculos em construtoras e obras, liberando o e-mail para novo cadastro.\n\nRegistros históricos (auditoria, despesas, diários, movimentações e funcionários) serão preservados.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
}

class _ResetPasswordDialog extends StatefulWidget {
  final String userLabel;

  const _ResetPasswordDialog({required this.userLabel});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController(text: defaultProvisionalPassword);
  bool _copied = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyPassword() async {
    await Clipboard.setData(ClipboardData(text: _passCtrl.text));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Senha provisória copiada para a área de transferência.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_reset, color: Colors.orange),
          SizedBox(width: 8),
          Flexible(child: Text('Redefinir Senha Provisória')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                decoration: InputDecoration(
                  labelText: 'Nova senha provisória',
                  border: const OutlineInputBorder(),
                  helperText:
                      'Mínimo de 8 caracteres. Sem expiração ou bloqueio de login.',
                  prefixIcon: const Icon(Icons.password),
                  suffixIcon: IconButton(
                    key: const Key('copy-provisional-password-btn'),
                    icon: Icon(_copied ? Icons.check : Icons.copy),
                    tooltip: 'Copiar senha',
                    onPressed: _copyPassword,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.length < 8) {
                    return 'A senha deve ter no mínimo 8 caracteres.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              Navigator.pop(context, _passCtrl.text);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirmar Redefinição'),
        ),
      ],
    );
  }
}

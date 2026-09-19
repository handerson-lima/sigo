import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/user_repository.dart';
import '../data/membros_repository.dart';

class AddMembroDialog extends ConsumerStatefulWidget {
  final String construtoraId;

  const AddMembroDialog({super.key, required this.construtoraId});

  @override
  ConsumerState<AddMembroDialog> createState() => _AddMembroDialogState();
}

class _AddMembroDialogState extends ConsumerState<AddMembroDialog> {
  final _emailController = TextEditingController();
  String _selectedRole = 'operario';
  bool _isLoading = false;

  Future<void> _salvar() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(membrosRepositoryProvider);
      await repo.concederAcesso(
        email,
        _selectedRole,
        widget.construtoraId,
        isOwner: _selectedRole == 'owner',
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acesso concedido com sucesso!')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDev = ref.watch(trustedDevProvider).value == true;

    return AlertDialog(
      title: const Text('Adicionar Membro'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'E-mail do Funcionário',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(labelText: 'Cargo'),
            items: [
              const DropdownMenuItem(value: 'operario', child: Text('Operário')),
              const DropdownMenuItem(value: 'admin', child: Text('Administrador')),
              if (isDev)
                const DropdownMenuItem(value: 'owner', child: Text('Proprietário')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedRole = val);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _salvar,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Conceder Acesso'),
        ),
      ],
    );
  }
}

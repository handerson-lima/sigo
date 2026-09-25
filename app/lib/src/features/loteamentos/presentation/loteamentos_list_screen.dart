import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/loteamento_repository.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';
import 'package:uuid/uuid.dart';
import '../domain/loteamento.dart';

class LoteamentosListScreen extends ConsumerWidget {
  final String construtoraId;

  const LoteamentosListScreen({
    super.key,
    required this.construtoraId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (construtoraId: construtoraId);
    final loteamentosAsync = ref.watch(watchLoteamentosProvider(params));

    return SigoLayout(
      title: 'Loteamentos',
      activeRoute: '/construtoras/$construtoraId/loteamentos',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_business, color: Colors.black54),
          tooltip: 'Novo Loteamento',
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => _AddLoteamentoDialog(construtoraId: construtoraId),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: loteamentosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar os loteamentos.',
                cause: err,
                onRetry: () => ref.invalidate(watchLoteamentosProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SigoEmptyState(
                    message: 'Nenhum loteamento cadastrado',
                    icon: Icons.map_outlined,
                    action: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => _AddLoteamentoDialog(construtoraId: construtoraId),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Criar Novo Loteamento'),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        context.go(
                          '/construtoras/$construtoraId/loteamentos/${item.id}/quadras',
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddLoteamentoDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  const _AddLoteamentoDialog({required this.construtoraId});

  @override
  ConsumerState<_AddLoteamentoDialog> createState() => _AddLoteamentoDialogState();
}

class _AddLoteamentoDialogState extends ConsumerState<_AddLoteamentoDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo Loteamento'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          decoration: const InputDecoration(
            labelText: 'Nome do Loteamento',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Nome é obrigatório' : null,
          onSaved: (v) => _name = v!,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  _formKey.currentState!.save();
                  setState(() => _isLoading = true);
                  try {
                    final loteamento = Loteamento(
                      id: const Uuid().v4(),
                      construtoraId: widget.construtoraId,
                      name: _name,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    await ref.read(loteamentoRepositoryProvider).createLoteamento(loteamento);
                    if (mounted) Navigator.of(context).pop();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          child: _isLoading ? const CircularProgressIndicator() : const Text('Criar'),
        ),
      ],
    );
  }
}

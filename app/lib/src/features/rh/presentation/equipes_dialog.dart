import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/rh_repository.dart';
import '../domain/equipe.dart';

class EquipesDialog extends ConsumerStatefulWidget {
  final String construtoraId;

  const EquipesDialog({super.key, required this.construtoraId});

  @override
  ConsumerState<EquipesDialog> createState() => _EquipesDialogState();
}

class _EquipesDialogState extends ConsumerState<EquipesDialog> {
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateEquipe() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final equipe = Equipe(
        id: const Uuid().v4(),
        construtoraId: widget.construtoraId,
        name: name,
        createdAt: DateTime.now(),
      );

      await ref.read(rhRepositoryProvider).createEquipe(equipe);
      _nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Equipe "$name" cadastrada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao cadastrar equipe: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipesAsync = ref.watch(equipesStreamProvider(widget.construtoraId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gerenciar Equipes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('equipe_name_input'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Equipe',
                        hintText: 'Ex: Equipe Alvenaria 1',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _handleCreateEquipe(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('btn_add_equipe'),
                    onPressed: _isCreating ? null : _handleCreateEquipe,
                    child: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Adicionar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: equipesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                  data: (equipes) {
                    if (equipes.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma equipe cadastrada ainda.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: equipes.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final eq = equipes[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: eq.isActive
                                ? Colors.indigo.shade100
                                : Colors.grey.shade200,
                            child: Icon(
                              Icons.groups,
                              color: eq.isActive ? Colors.indigo : Colors.grey,
                            ),
                          ),
                          title: Text(
                            eq.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: eq.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                              color: eq.isActive ? null : Colors.grey,
                            ),
                          ),
                          subtitle: eq.leaderName != null
                              ? Text('Líder: ${eq.leaderName}')
                              : null,
                          trailing: IconButton(
                            icon: Icon(
                              eq.isActive ? Icons.toggle_on : Icons.toggle_off,
                              color: eq.isActive ? Colors.green : Colors.grey,
                              size: 32,
                            ),
                            tooltip: eq.isActive
                                ? 'Inativar equipe'
                                : 'Reativar equipe',
                            onPressed: () async {
                              await ref
                                  .read(rhRepositoryProvider)
                                  .setEquipeActive(
                                    widget.construtoraId,
                                    eq.id,
                                    !eq.isActive,
                                  );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

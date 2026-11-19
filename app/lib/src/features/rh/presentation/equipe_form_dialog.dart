import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/rh_repository.dart';
import '../domain/equipe.dart';
import '../domain/funcionario.dart';

/// Abre o diálogo de criação ou edição de uma [Equipe].
///
/// Retorna a [Equipe] criada ou atualizada, ou `null` se o usuário cancelar.
Future<Equipe?> showEquipeFormDialog(
  BuildContext context, {
  required String construtoraId,
  Equipe? equipe,
}) {
  return showDialog<Equipe>(
    context: context,
    builder: (_) => EquipeFormDialog(
      construtoraId: construtoraId,
      equipe: equipe,
    ),
  );
}

class EquipeFormDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  final Equipe? equipe;

  const EquipeFormDialog({
    super.key,
    required this.construtoraId,
    this.equipe,
  });

  @override
  ConsumerState<EquipeFormDialog> createState() => _EquipeFormDialogState();
}

class _EquipeFormDialogState extends ConsumerState<EquipeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _selectedLeaderId;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.equipe != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.equipe?.name ?? '');
    _selectedLeaderId = widget.equipe?.leaderId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _isDuplicateName(String trimmedName, List<Equipe> existingEquipes) {
    final normalized = trimmedName.toLowerCase();
    return existingEquipes.any(
      (e) =>
          e.id != widget.equipe?.id &&
          e.name.trim().toLowerCase() == normalized,
    );
  }

  String? _resolveLeaderName(
    String? leaderId,
    List<Funcionario> activeFuncionarios,
  ) {
    if (leaderId == null) return null;
    for (final f in activeFuncionarios) {
      if (f.id == leaderId) return f.name;
    }
    if (widget.equipe?.leaderId == leaderId) {
      return widget.equipe?.leaderName;
    }
    return null;
  }

  Future<void> _handleSave(
    List<Equipe> existingEquipes,
    List<Funcionario> activeFuncionarios,
  ) async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final trimmedName = _nameController.text.trim();
    if (_isDuplicateName(trimmedName, existingEquipes)) {
      setState(() {
        _errorMessage = 'Já existe uma equipe cadastrada com este nome.';
      });
      return;
    }

    final leaderName = _resolveLeaderName(_selectedLeaderId, activeFuncionarios);

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(rhRepositoryProvider);
      final now = DateTime.now();

      if (_isEditing) {
        final atualizada = widget.equipe!.copyWith(
          name: trimmedName,
          leaderId: _selectedLeaderId,
          leaderName: leaderName,
          clearLeader: _selectedLeaderId == null,
          updatedAt: now,
        );
        await repo.updateEquipe(atualizada);
        if (mounted) {
          Navigator.of(context).pop(atualizada);
        }
      } else {
        final novaEquipe = Equipe(
          id: const Uuid().v4(),
          construtoraId: widget.construtoraId,
          name: trimmedName,
          leaderId: _selectedLeaderId,
          leaderName: leaderName,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createEquipe(novaEquipe);
        if (mounted) {
          Navigator.of(context).pop(novaEquipe);
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = 'Erro ao salvar equipe: $e';
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipesAsync = ref.watch(equipesStreamProvider(widget.construtoraId));
    final funcionariosAsync = ref.watch(
      funcionariosStreamProvider(widget.construtoraId),
    );

    final existingEquipes = equipesAsync.value ?? const <Equipe>[];
    final activeFuncionarios = (funcionariosAsync.value ?? const <Funcionario>[])
        .where((f) => f.isActive)
        .toList();

    final hasSelectedLeaderInActive =
        _selectedLeaderId != null &&
        activeFuncionarios.any((f) => f.id == _selectedLeaderId);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.groups, color: Colors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isEditing ? 'Editar Equipe' : 'Nova Equipe',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('equipe_form_name_input'),
                  controller: _nameController,
                  autofocus: !_isEditing,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Equipe *',
                    hintText: 'Ex: Equipe Alvenaria 1',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final trimmed = val?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Nome da equipe é obrigatório';
                    }
                    if (_isDuplicateName(trimmed, existingEquipes)) {
                      return 'Já existe uma equipe com este nome';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) =>
                      _handleSave(existingEquipes, activeFuncionarios),
                ),
                const SizedBox(height: 16),
                funcionariosAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (_) => DropdownButtonFormField<String?>(
                    key: const Key('equipe_form_leader_select'),
                    isExpanded: true,
                    initialValue: _selectedLeaderId,
                    decoration: const InputDecoration(
                      labelText: 'Líder / Encarregado (Opcional)',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sem líder definido'),
                      ),
                      if (_selectedLeaderId != null && !hasSelectedLeaderInActive)
                        DropdownMenuItem<String?>(
                          value: _selectedLeaderId,
                          child: Text(
                            '${widget.equipe?.leaderName ?? 'Líder anterior'} (inativo)',
                          ),
                        ),
                      ...activeFuncionarios.map(
                        (f) => DropdownMenuItem<String?>(
                          value: f.id,
                          child: Text('${f.name} — ${f.role}'),
                        ),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (val) => setState(() => _selectedLeaderId = val),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                      ),
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          key: const Key('btn_save_equipe_form'),
          onPressed: _isSaving
              ? null
              : () => _handleSave(existingEquipes, activeFuncionarios),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: Text(
            _isSaving
                ? 'Salvando...'
                : (_isEditing ? 'Salvar Alterações' : 'Criar Equipe'),
          ),
        ),
      ],
    );
  }
}

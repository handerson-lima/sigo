import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../obras/data/obra_members_repository.dart';
import '../../../obras/domain/obra.dart';
import '../../domain/membro.dart';
import '../membros_providers.dart';

/// Diálogo de atribuição de operário ou admin da obra (Epic 9.1/9.2 / UX-DR4).
class AtribuirObraDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  final Membro membro;

  static const Key obraDropdownKey = Key('atribuir-obra-dropdown');
  static const Key papelDropdownKey = Key('atribuir-papel-dropdown');

  const AtribuirObraDialog({
    super.key,
    required this.construtoraId,
    required this.membro,
  });

  static Future<void> show({
    required BuildContext context,
    required String construtoraId,
    required Membro membro,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AtribuirObraDialog(
        construtoraId: construtoraId,
        membro: membro,
      ),
    );
  }

  @override
  ConsumerState<AtribuirObraDialog> createState() => _AtribuirObraDialogState();
}

class _AtribuirObraDialogState extends ConsumerState<AtribuirObraDialog> {
  String? _selectedObraId;
  String _selectedRole = 'operario';
  bool _isSubmitting = false;
  String? _errorMessage;

  final Map<String, bool> _modules = {
    'diario': true,
    'lotes': false,
    'estoque': false,
  };

  static const Map<String, String> _moduleLabels = {
    'diario': 'Diário de Loteamento',
    'lotes': 'Lotes',
    'estoque': 'Estoque',
  };

  static const Map<String, String> _moduleSummaryLabels = {
    'diario': 'Diário',
    'lotes': 'Lotes',
    'estoque': 'Estoque',
  };

  static const Map<String, String> _roleLabels = {
    'operario': 'Operário',
    'admin': 'Admin do loteamento',
  };

  String get _rotuloPapel => _roleLabels[_selectedRole] ?? 'Operário';

  String get _identificadorMembro {
    final email = widget.membro.email.trim();
    return email.isNotEmpty ? email : 'UID: ${widget.membro.uid}';
  }

  String _gerarResumo(List<Obra> obras) {
    if (_selectedObraId == null) {
      return 'Selecione um loteamento para ver o resumo da atribuição.';
    }
    final obra = obras.firstWhere(
      (o) => o.id == _selectedObraId,
      orElse: () => Obra(
        id: _selectedObraId!,
        construtoraId: widget.construtoraId,
        name: 'Loteamento',
        createdAt: DateTime.now(),
      ),
    );
    final obraNome = obra.name.trim().isNotEmpty ? obra.name : 'Loteamento ${obra.id}';

    final selecionados = _modules.entries
        .where((e) => e.value)
        .map((e) => _moduleSummaryLabels[e.key] ?? e.key)
        .toList();

    final modulosTexto =
        selecionados.isEmpty ? 'nenhum módulo' : selecionados.join(', ');

    return '$_identificadorMembro será $_rotuloPapel em $obraNome com acesso a $modulosTexto';
  }

  Future<void> _confirmar(String obraNome) async {
    if (_selectedObraId == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final selectedModules = _modules.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    try {
      await ref.read(obraMembersRepositoryProvider).setMembership(
            construtoraId: widget.construtoraId,
            obraId: _selectedObraId!,
            userId: widget.membro.uid,
            role: _selectedRole,
            modules: selectedModules,
            isActive: true,
          );

      // Invalidação completa dos providers de membros para refletir o novo vínculo
      final cid = widget.construtoraId;
      final uid = widget.membro.uid;
      final oid = _selectedObraId!;

      ref.invalidate(membrosProvider(cid));
      ref.invalidate(contagemObrasPorMembroProvider(cid));
      ref.invalidate(contagemObrasMetaProvider(cid));
      ref.invalidate(memberDetalheProvider((construtoraId: cid, uid: uid)));
      ref.invalidate(obrasVinculadasProvider((construtoraId: cid, uid: uid)));
      ref.invalidate(obraMembersProvider((construtoraId: cid, obraId: oid)));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Atribuído a $obraNome como $_rotuloPapel.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obrasAsync = ref.watch(obrasAtivasProvider(widget.construtoraId));
    final key = (construtoraId: widget.construtoraId, uid: widget.membro.uid);
    final obrasVinculadas = ref.watch(obrasVinculadasProvider(key));

    final idsJaVinculados = obrasVinculadas.map((e) => e.obra.id).toSet();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: obrasAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Erro ao carregar obras.',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
            data: (todasObrasAtivas) {
              final obrasDisponiveis = todasObrasAtivas
                  .where((o) => !idsJaVinculados.contains(o.id))
                  .toList();

              final obraSelecionadaObj = _selectedObraId == null
                  ? null
                  : todasObrasAtivas.cast<Obra?>().firstWhere(
                        (o) => o?.id == _selectedObraId,
                        orElse: () => null,
                      );

              final obraSelecionadaNome =
                  (obraSelecionadaObj?.name.trim().isNotEmpty == true)
                      ? obraSelecionadaObj!.name
                      : (_selectedObraId != null
                            ? 'Loteamento $_selectedObraId'
                            : 'Loteamento');
              final temObras = obrasDisponiveis.isNotEmpty;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Atribuir ao loteamento',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Membro: $_identificadorMembro',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loteamento',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!temObras)
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        'Nenhum loteamento ativo',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                isExpanded: true,
                      key: AtribuirObraDialog.obraDropdownKey,
                      initialValue: _selectedObraId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: 'Selecione o loteamento',
                      ),
                      items: obrasDisponiveis.map((obra) {
                        final label = obra.name.trim().isNotEmpty
                            ? obra.name
                            : 'Loteamento ${obra.id}';
                        return DropdownMenuItem<String>(
                          value: obra.id,
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (val) {
                              setState(() {
                                _selectedObraId = val;
                              });
                            },
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Papel no loteamento',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    key: AtribuirObraDialog.papelDropdownKey,
                    initialValue: _selectedRole,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _roleLabels.entries
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (val) {
                            if (val == null) return;
                            setState(() {
                              _selectedRole = val;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Módulos de acesso',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ..._modules.keys.map((modKey) {
                    final label = _moduleLabels[modKey] ?? modKey;
                    final isChecked = _modules[modKey] ?? false;
                    return CheckboxListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      title: Text(label),
                      value: isChecked,
                      onChanged: _isSubmitting
                          ? null
                          : (bool? val) {
                              setState(() {
                                _modules[modKey] = val ?? false;
                              });
                            },
                    );
                  }),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo da atribuição',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _gerarResumo(todasObrasAtivas),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: (_selectedObraId != null &&
                                temObras &&
                                !_isSubmitting)
                            ? () => _confirmar(obraSelecionadaNome)
                            : null,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Confirmar atribuição'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

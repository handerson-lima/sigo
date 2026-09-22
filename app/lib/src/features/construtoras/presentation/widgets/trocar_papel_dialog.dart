import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../obras/data/obra_members_repository.dart';
import '../membros_providers.dart';

/// Dialog pré-preenchida para trocar papel e módulos de um vínculo obra (Epic 10.1).
///
/// Recebe o estado atual do vínculo ([isAdminAtual], [modulesAtuais]) e permite
/// ao admin/owner alterar papel (Operário ↔ Admin da obra) e módulos de acesso,
/// chamando `setMembership` via [ObraMembersRepository].
class TrocarPapelDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;
  final String obraNome;
  final String userId;
  final String membroIdentificador;
  final bool isAdminAtual;
  final List<String> modulesAtuais;

  static const Key papelDropdownKey = Key('trocar-papel-dropdown');
  static const Key moduloDiarioKey = Key('modulo-diario');
  static const Key moduloLotesKey = Key('modulo-lotes');
  static const Key moduloEstoqueKey = Key('modulo-estoque');

  const TrocarPapelDialog({
    super.key,
    required this.construtoraId,
    required this.obraId,
    required this.obraNome,
    required this.userId,
    required this.membroIdentificador,
    required this.isAdminAtual,
    required this.modulesAtuais,
  });

  static Future<void> show({
    required BuildContext context,
    required String construtoraId,
    required String obraId,
    required String obraNome,
    required String userId,
    required String membroIdentificador,
    required bool isAdminAtual,
    required List<String> modulesAtuais,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TrocarPapelDialog(
        construtoraId: construtoraId,
        obraId: obraId,
        obraNome: obraNome,
        userId: userId,
        membroIdentificador: membroIdentificador,
        isAdminAtual: isAdminAtual,
        modulesAtuais: modulesAtuais,
      ),
    );
  }

  @override
  ConsumerState<TrocarPapelDialog> createState() => _TrocarPapelDialogState();
}

class _TrocarPapelDialogState extends ConsumerState<TrocarPapelDialog> {
  late String _selectedRole;
  late Map<String, bool> _modules;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const Map<String, String> _roleLabels = {
    'operario': 'Operário',
    'admin': 'Admin da obra',
  };

  static const Map<String, String> _moduleLabels = {
    'diario': 'Diário de Obras',
    'lotes': 'Lotes',
    'estoque': 'Estoque',
  };

  static const Map<String, String> _moduleSummaryLabels = {
    'diario': 'Diário',
    'lotes': 'Lotes',
    'estoque': 'Estoque',
  };

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.isAdminAtual ? 'admin' : 'operario';
    _modules = {
      'diario': widget.modulesAtuais.contains('diario'),
      'lotes': widget.modulesAtuais.contains('lotes'),
      'estoque': widget.modulesAtuais.contains('estoque'),
    };
  }

  String get _rotuloPapel => _roleLabels[_selectedRole] ?? 'Operário';

  String _gerarResumo() {
    final selecionados = _modules.entries
        .where((e) => e.value)
        .map((e) => _moduleSummaryLabels[e.key] ?? e.key)
        .toList();
    final modulosTexto =
        selecionados.isEmpty ? 'nenhum módulo' : selecionados.join(', ');
    final obraNome = widget.obraNome.trim().isNotEmpty
        ? widget.obraNome
        : 'Obra ${widget.obraId}';
    return '${widget.membroIdentificador} será $_rotuloPapel em $obraNome com acesso a $modulosTexto';
  }

  Future<void> _confirmar() async {
    if (_isSubmitting) return;

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
            obraId: widget.obraId,
            userId: widget.userId,
            role: _selectedRole,
            modules: selectedModules,
            isActive: true,
          );

      // Invalidar providers para refletir a mudança
      ref.invalidate(membrosProvider(widget.construtoraId));
      ref.invalidate(
        obraMembersProvider(
          (construtoraId: widget.construtoraId, obraId: widget.obraId),
        ),
      );

      if (mounted) {
        final obraNome = widget.obraNome.trim().isNotEmpty
            ? widget.obraNome
            : 'Obra ${widget.obraId}';
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Papel atualizado em $obraNome.')),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Trocar papel',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Membro: ${widget.membroIdentificador}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              // Papel
              Text(
                'Papel na obra',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                key: TrocarPapelDialog.papelDropdownKey,
                initialValue: _selectedRole,
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
                        setState(() => _selectedRole = val);
                      },
              ),
              const SizedBox(height: 12),

              // Módulos
              Text(
                'Módulos de acesso',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              FilterChip(
                key: TrocarPapelDialog.moduloDiarioKey,
                label: Text(_moduleLabels['diario']!),
                selected: _modules['diario'] ?? false,
                onSelected: _isSubmitting
                    ? null
                    : (val) => setState(() => _modules['diario'] = val),
              ),
              FilterChip(
                key: TrocarPapelDialog.moduloLotesKey,
                label: Text(_moduleLabels['lotes']!),
                selected: _modules['lotes'] ?? false,
                onSelected: _isSubmitting
                    ? null
                    : (val) => setState(() => _modules['lotes'] = val),
              ),
              FilterChip(
                key: TrocarPapelDialog.moduloEstoqueKey,
                label: Text(_moduleLabels['estoque']!),
                selected: _modules['estoque'] ?? false,
                onSelected: _isSubmitting
                    ? null
                    : (val) => setState(() => _modules['estoque'] = val),
              ),
              const SizedBox(height: 8),

              // Resumo ao vivo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumo',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _gerarResumo(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              // Erro
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

              // Ações
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
                    onPressed: _isSubmitting ? null : _confirmar,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

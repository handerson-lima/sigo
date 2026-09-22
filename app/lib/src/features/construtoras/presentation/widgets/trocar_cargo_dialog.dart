import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/membros_repository.dart';
import '../membros_providers.dart';

/// Dialog para trocar o cargo de um membro na construtora (Epic 10.3).
///
/// Exibe dropdown Operário / Administrador (+ Proprietário se [isDev]).
/// Pré-seleciona o cargo atual. Chama [MembrosRepository.setCargo] ao confirmar.
/// Em erro, mantém o dialog aberto com mensagem mapeada pt-br.
class TrocarCargoDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  final String userId;
  final String membroIdentificador;

  /// Cargo atual: `'operario'`, `'admin'` ou `'owner'`.
  final String cargoAtual;

  /// Se `true`, exibe a opção Proprietário no dropdown.
  final bool isDev;

  static const Key cargoDropdownKey = Key('trocar-cargo-dropdown');

  const TrocarCargoDialog({
    super.key,
    required this.construtoraId,
    required this.userId,
    required this.membroIdentificador,
    required this.cargoAtual,
    required this.isDev,
  });

  /// Abre o dialog e retorna `true` em caso de sucesso.
  static Future<bool?> show({
    required BuildContext context,
    required String construtoraId,
    required String userId,
    required String membroIdentificador,
    required String cargoAtual,
    required bool isDev,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => TrocarCargoDialog(
        construtoraId: construtoraId,
        userId: userId,
        membroIdentificador: membroIdentificador,
        cargoAtual: cargoAtual,
        isDev: isDev,
      ),
    );
  }

  @override
  ConsumerState<TrocarCargoDialog> createState() => _TrocarCargoDialogState();
}

class _TrocarCargoDialogState extends ConsumerState<TrocarCargoDialog> {
  late String _selectedRole;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const Map<String, String> _roleLabels = {
    'operario': 'Operário',
    'admin': 'Administrador',
    'owner': 'Proprietário',
  };

  List<String> get _rolesDisponiveis => [
        'operario',
        'admin',
        if (widget.isDev) 'owner',
      ];

  @override
  void initState() {
    super.initState();
    // Se o cargo atual não é reconhecido, cai em 'operario' como fallback.
    final roles = _rolesDisponiveis;
    _selectedRole =
        roles.contains(widget.cargoAtual) ? widget.cargoAtual : 'operario';
  }

  Future<void> _confirmar() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(membrosRepositoryProvider).setCargo(
            widget.construtoraId,
            widget.userId,
            _selectedRole,
          );

      // Invalida providers para refletir a mudança.
      ref.invalidate(membrosProvider(widget.construtoraId));
      ref.invalidate(
        memberDetalheProvider(
          (construtoraId: widget.construtoraId, uid: widget.userId),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
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
    final rotuloSelecionado =
        _roleLabels[_selectedRole] ?? 'Operário';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
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
                      'Trocar cargo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
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
              const SizedBox(height: 16),

              // Cargo
              Text(
                'Cargo na construtora',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: TrocarCargoDialog.cargoDropdownKey,
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _rolesDisponiveis
                    .map(
                      (role) => DropdownMenuItem<String>(
                        value: role,
                        child: Text(_roleLabels[role] ?? role),
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

              // Resumo
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
                      '${widget.membroIdentificador} será $rotuloSelecionado na construtora.',
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
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
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

import 'package:flutter/material.dart';
import '../../../../core/contracts.dart';

class RetificacaoChamadaDialog extends StatefulWidget {
  final int totalCostCentsAnterior;
  final int totalCostCentsNovo;

  const RetificacaoChamadaDialog({
    super.key,
    required this.totalCostCentsAnterior,
    required this.totalCostCentsNovo,
  });

  @override
  State<RetificacaoChamadaDialog> createState() =>
      _RetificacaoChamadaDialogState();
}

class _RetificacaoChamadaDialogState extends State<RetificacaoChamadaDialog> {
  final _motivoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  bool get _isMotivoValido => _motivoController.text.trim().length >= 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diffCents = widget.totalCostCentsNovo - widget.totalCostCentsAnterior;
    final diffFormatted =
        '${diffCents >= 0 ? '+' : ''}${formatCents(diffCents)}';

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.history_edu, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Retificação de Chamada'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta chamada já se encontra encerrada no sistema. Qualquer alteração exigirá justificativa formal para a trilha de auditoria contábil.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // Comparativo de custos
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Custo Anterior:'),
                        Text(
                          formatCents(widget.totalCostCentsAnterior),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Novo Custo:'),
                        Text(
                          formatCents(widget.totalCostCentsNovo),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Diferença (Δ):'),
                        Text(
                          diffFormatted,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: diffCents > 0
                                ? Colors.orange.shade800
                                : (diffCents < 0 ? Colors.green.shade800 : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motivoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo da Retificação *',
                  hintText: 'Ex.: Correção de apontamento do colaborador X...',
                  border: OutlineInputBorder(),
                  helperText: 'Mínimo de 10 caracteres',
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'Justificativa obrigatória (mínimo 10 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Esta ação será registrada permanentemente na trilha de auditoria contábil.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Confirmar Retificação'),
          onPressed: _isMotivoValido
              ? () {
                  if (_formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(_motivoController.text.trim());
                  }
                }
              : null,
        ),
      ],
    );
  }
}

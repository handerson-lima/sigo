import 'package:flutter/material.dart';
import '../../domain/compra_nf.dart';

class ReceberMateriaisDialog extends StatefulWidget {
  final CompraNf compra;

  const ReceberMateriaisDialog({
    super.key,
    required this.compra,
  });

  @override
  State<ReceberMateriaisDialog> createState() => _ReceberMateriaisDialogState();
}

class _ReceberMateriaisDialogState extends State<ReceberMateriaisDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.compra.itens) {
      final pendente = item.quantidadePendente;
      _controllers[item.id] = TextEditingController(
        text: pendente > 0 ? pendente.toStringAsFixed(pendente.truncateToDouble() == pendente ? 0 : 2) : '0',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _receberTudo() {
    for (final item in widget.compra.itens) {
      final pendente = item.quantidadePendente;
      _controllers[item.id]?.text = pendente.toStringAsFixed(pendente.truncateToDouble() == pendente ? 0 : 2);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final itensPendentes = widget.compra.itens.where((i) => !i.isTotalmenteRecebido).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Receber Materiais no Almoxarifado',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NF ${widget.compra.numeroNf} - ${widget.compra.fornecedorNome}',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Itens faturados a receber:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      onPressed: _receberTudo,
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('Receber Saldo Total'),
                    ),
                  ],
                ),
                const Divider(),
                if (itensPendentes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Todos os itens desta compra já foram recebidos no canteiro.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
                else
                  ...widget.compra.itens.map((item) {
                    final ctrl = _controllers[item.id];
                    final pendente = item.quantidadePendente;
                    final jaRecebido = item.quantidadeRecebida;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.isTotalmenteRecebido
                              ? Colors.grey.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: item.isTotalmenteRecebido
                                ? Colors.grey.shade300
                                : Colors.blue.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.materialNome,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (item.isTotalmenteRecebido)
                                  const Chip(
                                    label: Text('Concluído', style: TextStyle(fontSize: 11, color: Colors.green)),
                                    backgroundColor: Color(0xFFE8F5E9),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Faturado: ${item.quantidade} ${item.unidadeMedida} | Já Recebido: $jaRecebido | Saldo Pendente: $pendente',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                            if (!item.isTotalmenteRecebido) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: ctrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Quantidade a receber agora (${item.unidadeMedida})',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Informe a quantidade';
                                  final numVal = double.tryParse(val.replaceAll(',', '.'));
                                  if (numVal == null || numVal < 0) return 'Valor inválido';
                                  if (numVal > pendente) {
                                    return 'Máximo permitido para entrega: $pendente';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (itensPendentes.isNotEmpty)
          FilledButton.icon(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final resultado = <String, double>{};
                for (final item in widget.compra.itens) {
                  final ctrl = _controllers[item.id];
                  if (ctrl != null) {
                    final val = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
                    if (val > 0) {
                      resultado[item.id] = val;
                    }
                  }
                }
                if (resultado.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe ao menos um item com quantidade a receber.')),
                  );
                  return;
                }
                Navigator.of(context).pop(resultado);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Confirmar Entrada no Estoque'),
          ),
      ],
    );
  }
}

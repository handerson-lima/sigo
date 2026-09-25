import 'package:flutter/material.dart';

import '../../domain/parcela_compra.dart';

class LiquidarParcelaDialog extends StatefulWidget {
  final ParcelaCompra parcela;
  final String fornecedorNome;

  const LiquidarParcelaDialog({
    super.key,
    required this.parcela,
    required this.fornecedorNome,
  });

  @override
  State<LiquidarParcelaDialog> createState() => _LiquidarParcelaDialogState();
}

class _LiquidarParcelaDialogState extends State<LiquidarParcelaDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _dataPagamento;
  MetodoPagamentoCompra _metodoPagamento = MetodoPagamentoCompra.pix;
  final _obsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataPagamento = DateTime.now();
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataPagamento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _dataPagamento = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Liquidar Parcela ${widget.parcela.numero}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
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
                'Fornecedor: ${widget.fornecedorNome}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Valor a Pagar:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'R\$ ${widget.parcela.valor.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Data do Pagamento
              InkWell(
                onTap: _selecionarData,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data do Pagamento *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_dataPagamento.day.toString().padLeft(2, '0')}/${_dataPagamento.month.toString().padLeft(2, '0')}/${_dataPagamento.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Método de Pagamento
              DropdownButtonFormField<MetodoPagamentoCompra>(
                initialValue: _metodoPagamento,
                decoration: const InputDecoration(
                  labelText: 'Forma de Pagamento *',
                  border: OutlineInputBorder(),
                ),
                items: MetodoPagamentoCompra.values.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m.label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _metodoPagamento = val);
                },
              ),
              const SizedBox(height: 16),
              // Observações
              TextFormField(
                controller: _obsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observação / Referência do Pagamento',
                  hintText: 'Ex.: Chave Pix CNPJ, comprovante nº 9876...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'dataPagamento': _dataPagamento,
                'metodoPagamento': _metodoPagamento,
                'observacao': _obsController.text.trim().isEmpty
                    ? null
                    : _obsController.text.trim(),
              });
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('Confirmar Liquidação'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
        ),
      ],
    );
  }
}

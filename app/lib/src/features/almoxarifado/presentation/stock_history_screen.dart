import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../sync/operation_queue.dart';
import '../domain/material.dart' as mat;

class StockHistoryScreen extends StatelessWidget {
  final String c;
  final mat.Material material;
  final bool canManage;
  final List<Map<String, dynamic>>? mockMovements;
  final OperationQueue? queue;

  const StockHistoryScreen({
    super.key,
    required this.c,
    required this.material,
    required this.canManage,
    this.mockMovements,
    this.queue,
  });
  Future<void> correction(
    BuildContext context,
    String type, {
    String? reversalId,
  }) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _CorrectionDialog(
        type: type,
        material: material,
        reversalId: reversalId,
      ),
    );
    if (result != null) {
      try {
        await (queue ?? OperationQueue.instance).enqueue('stockCommand', {
          'operationId': const Uuid().v4(),
          'construtoraId': c,
          'materialId': material.id,
          'type': type,
          'quantity': result['quantity']!,
          'reason': result['reason']!,
          'evidence': result['evidence']!,
          'reversalId': ?reversalId,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Correção salva no dispositivo. Aguarde confirmação.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível registrar: $e')),
          );
        }
      }
    }
  }

  Widget _buildMovementTile(
    BuildContext context,
    Map<String, dynamic> d,
    String docId,
  ) {
    final isAjuste = d['commandType'] == 'ajuste';
    final reversible =
        ['entrada', 'saida', 'ajuste'].contains(d['commandType']) &&
        d['reversedBy'] == null;
    final nf = d['nfNumber'] as String?;
    final fornecedor = d['fornecedor'] as String?;
    final evidence = d['evidence'] as String?;
    final obraId = d['obraId'] as String?;
    final loteId = d['loteId'] as String?;
    final solicitante = d['solicitante'] as String?;
    final apropriacaoLote = d['apropriacaoLote'] == true;
    final obs = (d['observacao'] ?? d['reason'] ?? '') as String;
    final details = <String>[];
    if (obraId != null && obraId.isNotEmpty) {
      details.add('Obra: $obraId');
    }
    if (loteId != null && loteId.isNotEmpty) {
      details.add('Lote: $loteId');
    }
    if (apropriacaoLote) {
      details.add('[Apropriação Lote]');
    }
    if (solicitante != null && solicitante.isNotEmpty) {
      details.add('Solicitante: $solicitante');
    }
    if (nf != null && nf.isNotEmpty) details.add('NF: $nf');
    if (fornecedor != null && fornecedor.isNotEmpty) {
      details.add('Fornecedor: $fornecedor');
    }
    if (evidence != null && evidence.isNotEmpty) {
      details.add('Evidência: $evidence');
    }
    if (obs.isNotEmpty) {
      details.add(isAjuste ? 'Motivo: $obs' : obs);
    }
    if (d['reversedBy'] != null) details.add('(Estornado)');

    Widget titleWidget;
    if (isAjuste) {
      final deltaUnits = d['deltaUnits'] as num?;
      final scale = (d['quantityScale'] as num?) ?? 1000;
      final double signedQty = deltaUnits != null
          ? deltaUnits / scale
          : (d['type'] == 'saida'
              ? -(num.tryParse(d['quantity'].toString())?.toDouble() ?? 0)
              : (num.tryParse(d['quantity'].toString())?.toDouble() ?? 0));
      final signStr = signedQty > 0 ? '+' : '';
      final qtyStr = signedQty % 1 == 0
          ? signedQty.toInt().toString()
          : signedQty.toString();
      final displayVariation = '$signStr$qtyStr ${material.unit}';

      titleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Text(
              '[Ajuste Auditado]',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            displayVariation,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else {
      titleWidget = Text(
        '${d['type']} · ${d['quantity']} ${material.unit}',
      );
    }

    return ListTile(
      title: titleWidget,
      subtitle: details.isEmpty ? null : Text(details.join(' • ')),
      trailing: canManage && reversible
          ? TextButton(
              onPressed: () => correction(
                context,
                'estorno',
                reversalId: docId,
              ),
              child: const Text('Estornar'),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Histórico · ${material.name}')),
    body: Column(
      children: [
        if (canManage)
          Wrap(
            spacing: 12,
            children: [
              if (material.quantityUnits == null)
                TextButton(
                  onPressed: () => correction(context, 'abertura'),
                  child: const Text('Conferir saldo inicial'),
                ),
              if (material.quantityUnits != null)
                TextButton(
                  onPressed: () => correction(context, 'ajuste'),
                  child: const Text('Ajustar quantidade'),
                ),
            ],
          ),
        Expanded(
          child: mockMovements != null
              ? ListView(
                  children: mockMovements!
                      .map((d) => _buildMovementTile(
                            context,
                            d,
                            d['id'] as String? ?? 'mov-1',
                          ))
                      .toList(),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(
                        'construtoras/$c/materiais/${material.id}/movimentacoes',
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Não foi possível carregar o histórico.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView(
                      children: snapshot.data!.docs
                          .map((doc) => _buildMovementTile(
                                context,
                                doc.data(),
                                doc.id,
                              ))
                          .toList(),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _CorrectionDialog extends StatefulWidget {
  final String type;
  final mat.Material material;
  final String? reversalId;

  const _CorrectionDialog({
    required this.type,
    required this.material,
    this.reversalId,
  });

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  late final TextEditingController _quantity;
  late final TextEditingController _reason;
  late final TextEditingController _evidence;
  final _form = GlobalKey<FormState>();
  late String _predictedBalanceDisplay;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: widget.type == 'abertura'
          ? widget.material.currentQuantity.toString()
          : '',
    );
    _reason = TextEditingController();
    _evidence = TextEditingController();

    final currentBalance = widget.material.currentQuantity;
    final balanceDisplay = currentBalance % 1 == 0
        ? currentBalance.toInt().toString()
        : currentBalance.toString();
    _predictedBalanceDisplay = '$balanceDisplay ${widget.material.unit}';
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    _evidence.dispose();
    super.dispose();
  }

  void _updatePredicted(String valText) {
    final currentBalance = widget.material.currentQuantity;
    final balanceDisplay = currentBalance % 1 == 0
        ? currentBalance.toInt().toString()
        : currentBalance.toString();
    final clean = valText.replaceAll(',', '.').replaceAll('+', '').trim();
    final val = num.tryParse(clean);
    setState(() {
      if (val != null) {
        final predicted = currentBalance + val;
        final pStr = predicted % 1 == 0
            ? predicted.toInt().toString()
            : predicted.toString();
        _predictedBalanceDisplay = '$pStr ${widget.material.unit}';
      } else {
        _predictedBalanceDisplay = '$balanceDisplay ${widget.material.unit}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentBalance = widget.material.currentQuantity;
    final balanceDisplay = currentBalance % 1 == 0
        ? currentBalance.toInt().toString()
        : currentBalance.toString();

    return AlertDialog(
      title: Text(
        widget.type == 'estorno'
            ? 'Estornar movimentação'
            : widget.type == 'abertura'
            ? 'Conferir saldo inicial'
            : 'Ajustar quantidade',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.type == 'ajuste') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo atual: $balanceDisplay ${widget.material.unit}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saldo previsto: $_predictedBalanceDisplay',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.type != 'estorno')
                TextFormField(
                  controller: _quantity,
                  decoration: InputDecoration(
                    labelText: widget.type == 'ajuste'
                        ? 'Variação (+ entrada / − saída)'
                        : 'Saldo conferido',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: _updatePredicted,
                  validator: (v) {
                    if (widget.type == 'ajuste') {
                      final raw = v?.replaceAll(',', '.').trim() ?? '';
                      if (raw.isEmpty) {
                        return 'Informe uma variação diferente de zero';
                      }
                      final cleanForDecimals = raw
                          .replaceAll('+', '')
                          .replaceAll('-', '');
                      if (cleanForDecimals.contains('.')) {
                        final parts = cleanForDecimals.split('.');
                        if (parts.length > 1 && parts[1].length > 3) {
                          return 'Use até 3 casas decimais';
                        }
                      }
                      final clean = raw.replaceAll('+', '');
                      final val = num.tryParse(clean);
                      if (val == null || val == 0) {
                        return 'Informe uma variação diferente de zero';
                      }
                      if (currentBalance + val < 0) {
                        return 'Ajuste negativo excede o saldo atual ($balanceDisplay)';
                      }
                      return null;
                    }
                    return num.tryParse(v?.replaceAll(',', '.') ?? '') == null
                        ? 'Informe uma quantidade'
                        : null;
                  },
                ),
              TextFormField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Motivo da correção',
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 5
                        ? 'Descreva o motivo (mínimo 5 caracteres)'
                        : null,
              ),
              TextFormField(
                controller: _evidence,
                decoration: const InputDecoration(
                  labelText: 'Referência da evidência ou documento',
                ),
                validator: (v) => (v?.trim().isEmpty ?? true)
                    ? 'Informe a referência da evidência ou documento'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              final cleanQuantity = _quantity.text
                  .replaceAll(',', '.')
                  .replaceAll('+', '')
                  .trim();
              Navigator.pop(context, {
                'quantity': cleanQuantity,
                'reason': _reason.text.trim(),
                'evidence': _evidence.text.trim(),
              });
            }
          },
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}

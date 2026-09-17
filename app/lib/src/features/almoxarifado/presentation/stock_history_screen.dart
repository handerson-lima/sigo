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
    Map<String, dynamic>? originalMovement,
  }) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _CorrectionDialog(
        type: type,
        material: material,
        reversalId: reversalId,
        originalMovement: originalMovement,
      ),
    );
    if (result != null) {
      try {
        final reversalDeltaNum = result['reversalDelta'] != null
            ? num.tryParse(result['reversalDelta']!)
            : null;
        await (queue ?? OperationQueue.instance).enqueue('stockCommand', {
          'operationId': const Uuid().v4(),
          'construtoraId': c,
          'materialId': material.id,
          'type': type,
          'quantity': result['quantity'] ?? '0',
          'reason': result['reason']!,
          'evidence': result['evidence']!,
          'reversalId': ?reversalId,
          'reversalDelta': ?reversalDeltaNum,
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
    final isEstorno = d['commandType'] == 'estorno';
    final isReversed = d['reversedBy'] != null;
    final reversible =
        ['entrada', 'saida', 'ajuste'].contains(d['commandType']) &&
        !isReversed;
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
      details.add((isAjuste || isEstorno) ? 'Motivo: $obs' : obs);
    }
    if (isEstorno && d['reversalId'] != null) {
      details.add('Ref: ${d['reversalId']}');
    }
    if (isReversed) {
      details.add('(Estornado)');
    }

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
    } else if (isEstorno) {
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
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.purple.shade700),
            ),
            child: Text(
              '[Estorno Auditado]',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade900,
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
      final baseText = '${d['type']} · ${d['quantity']} ${material.unit}';
      if (isReversed) {
        titleWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              baseText,
              style: TextStyle(
                color: Colors.grey.shade600,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Text(
                '[Estornado]',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        );
      } else {
        titleWidget = Text(baseText);
      }
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
                originalMovement: d,
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
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma movimentação registrada.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final d = docs[index].data();
                        return _buildMovementTile(context, d, docs[index].id);
                      },
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
  final Map<String, dynamic>? originalMovement;

  const _CorrectionDialog({
    required this.type,
    required this.material,
    this.reversalId,
    this.originalMovement,
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

    final currentBalance = widget.material.quantityUnits != null
        ? widget.material.quantityUnits! / 1000
        : widget.material.currentQuantity;
    final balanceDisplay = currentBalance % 1 == 0
        ? currentBalance.toInt().toString()
        : currentBalance.toString();

    if (widget.type == 'estorno') {
      final revDelta = _calculateReversalDelta();
      final predicted = currentBalance + revDelta;
      final pStr = predicted % 1 == 0
          ? predicted.toInt().toString()
          : predicted.toString();
      _predictedBalanceDisplay = '$pStr ${widget.material.unit}';
    } else {
      _predictedBalanceDisplay = '$balanceDisplay ${widget.material.unit}';
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    _evidence.dispose();
    super.dispose();
  }

  double _calculateReversalDelta() {
    if (widget.originalMovement == null) return 0.0;
    final orig = widget.originalMovement!;
    final deltaUnits = orig['deltaUnits'] as num?;
    final scale = (orig['quantityScale'] as num?) ?? 1000;
    if (deltaUnits != null) {
      return -(deltaUnits.toDouble() / scale);
    }
    final q = num.tryParse(orig['quantity']?.toString() ?? '')?.toDouble() ?? 0.0;
    final origType = orig['type'] as String? ?? (orig['commandType'] == 'entrada' ? 'entrada' : 'saida');
    if (origType == 'saida') {
      return q;
    } else {
      return -q;
    }
  }

  String _formatOrigType(Map<String, dynamic> orig) {
    final cmd = orig['commandType'] as String?;
    if (cmd == 'ajuste') return 'Ajuste';
    if (cmd == 'entrada' || orig['type'] == 'entrada') return 'Entrada';
    if (cmd == 'saida' || orig['type'] == 'saida') return 'Saída';
    return orig['type']?.toString() ?? 'Movimentação';
  }

  String _formatOrigQuantity(Map<String, dynamic> orig) {
    final deltaUnits = orig['deltaUnits'] as num?;
    final scale = (orig['quantityScale'] as num?) ?? 1000;
    if (deltaUnits != null) {
      final q = deltaUnits.abs() / scale;
      return q % 1 == 0 ? q.toInt().toString() : q.toString();
    }
    final q = num.tryParse(orig['quantity']?.toString() ?? '')?.toDouble() ?? 0.0;
    return q % 1 == 0 ? q.toInt().toString() : q.toString();
  }

  String _origDetails(Map<String, dynamic> orig) {
    final parts = <String>[];
    final nf = orig['nfNumber'] as String?;
    final forn = orig['fornecedor'] as String?;
    final resp = orig['responsavelId'] as String?;
    final obs = (orig['observacao'] ?? orig['reason'] ?? '') as String;
    if (nf != null && nf.isNotEmpty) parts.add('NF: $nf');
    if (forn != null && forn.isNotEmpty) parts.add('Fornecedor: $forn');
    if (resp != null && resp.isNotEmpty) parts.add('Resp: $resp');
    if (obs.isNotEmpty) parts.add('Obs: $obs');
    return parts.join(' • ');
  }

  void _updatePredicted(String valText) {
    final currentBalance = widget.material.quantityUnits != null
        ? widget.material.quantityUnits! / 1000
        : widget.material.currentQuantity;
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
    final currentBalance = widget.material.quantityUnits != null
        ? widget.material.quantityUnits! / 1000
        : widget.material.currentQuantity;
    final balanceDisplay = currentBalance % 1 == 0
        ? currentBalance.toInt().toString()
        : currentBalance.toString();

    final revDelta = widget.type == 'estorno' ? _calculateReversalDelta() : 0.0;
    final predictedBalance = currentBalance + revDelta;
    final isNegativeBalance = widget.type == 'estorno' && predictedBalance < 0;

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
              if (widget.type == 'estorno' && widget.originalMovement != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Movimentação original:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tipo: ${_formatOrigType(widget.originalMovement!)} · Quantidade: ${_formatOrigQuantity(widget.originalMovement!)} ${widget.material.unit}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (_origDetails(widget.originalMovement!).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _origDetails(widget.originalMovement!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      const Divider(height: 16),
                      Text(
                        'Saldo atual: $balanceDisplay ${widget.material.unit}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saldo previsto pós-estorno: $_predictedBalanceDisplay',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isNegativeBalance
                              ? Colors.red.shade900
                              : Colors.purple.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isNegativeBalance) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Saldo insuficiente para estornar esta entrada (saldo atual: $balanceDisplay ${widget.material.unit}, estorno retiraria: ${_formatOrigQuantity(widget.originalMovement!)} ${widget.material.unit}).',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
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
          onPressed: (widget.type == 'estorno' && isNegativeBalance)
              ? null
              : () {
                  if (_form.currentState!.validate()) {
                    final cleanQuantity = widget.type == 'estorno'
                        ? '0'
                        : _quantity.text
                            .replaceAll(',', '.')
                            .replaceAll('+', '')
                            .trim();
                    Navigator.pop(context, {
                      'quantity': cleanQuantity,
                      'reason': _reason.text.trim(),
                      'evidence': _evidence.text.trim(),
                      if (widget.type == 'estorno')
                        'reversalDelta': revDelta.toString(),
                    });
                  }
                },
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}

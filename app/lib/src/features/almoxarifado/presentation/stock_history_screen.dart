import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../sync/operation_queue.dart';
import '../domain/material.dart' as mat;

class StockHistoryScreen extends StatelessWidget {
  final String c;
  final mat.Material material;
  final bool canManage;
  const StockHistoryScreen({
    super.key,
    required this.c,
    required this.material,
    required this.canManage,
  });
  Future<void> correction(
    BuildContext context,
    String type, {
    String? reversalId,
  }) async {
    final quantity = TextEditingController(
      text: type == 'abertura' ? material.currentQuantity.toString() : '',
    );
    final reason = TextEditingController(), evidence = TextEditingController();
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          type == 'estorno'
              ? 'Estornar movimentação'
              : type == 'abertura'
              ? 'Conferir saldo inicial'
              : 'Ajustar quantidade',
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type != 'estorno')
                  TextFormField(
                    controller: quantity,
                    decoration: InputDecoration(
                      labelText: type == 'ajuste'
                          ? 'Variação (+ entrada / − saída)'
                          : 'Saldo conferido',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) =>
                        num.tryParse(v?.replaceAll(',', '.') ?? '') == null
                        ? 'Informe uma quantidade'
                        : null,
                  ),
                TextFormField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da correção',
                  ),
                  validator: (v) =>
                      (v?.trim().length ?? 0) < 5 ? 'Descreva o motivo' : null,
                ),
                TextFormField(
                  controller: evidence,
                  decoration: const InputDecoration(
                    labelText: 'Referência da evidência ou documento',
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Informe a evidência'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await OperationQueue.instance.enqueue('stockCommand', {
          'operationId': const Uuid().v4(),
          'construtoraId': c,
          'materialId': material.id,
          'type': type,
          'quantity': quantity.text.replaceAll(',', '.'),
          'reason': reason.text.trim(),
          'evidence': evidence.text.trim(),
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
    quantity.dispose();
    reason.dispose();
    evidence.dispose();
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
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                children: snapshot.data!.docs.map((doc) {
                  final d = doc.data();
                  final reversible =
                      [
                        'entrada',
                        'saida',
                        'ajuste',
                      ].contains(d['commandType']) &&
                      d['reversedBy'] == null;
                  return ListTile(
                    title: Text(
                      '${d['type']} · ${d['quantity']} ${material.unit}',
                    ),
                    subtitle: Text(d['observacao'] ?? ''),
                    trailing: canManage && reversible
                        ? TextButton(
                            onPressed: () => correction(
                              context,
                              'estorno',
                              reversalId: doc.id,
                            ),
                            child: const Text('Estornar'),
                          )
                        : null,
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../../../core/contracts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/almoxarifado_repository.dart';
import '../domain/material.dart' as mat;
import '../domain/movimentacao.dart';

class MovimentacaoScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final mat.Material material;
  final MovimentacaoType type;

  const MovimentacaoScreen({
    super.key,
    required this.construtoraId,
    required this.material,
    required this.type,
  });

  @override
  ConsumerState<MovimentacaoScreen> createState() => _MovimentacaoScreenState();
}

class _MovimentacaoScreenState extends ConsumerState<MovimentacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _obsController = TextEditingController();
  final _obraController = TextEditingController();
  final _loteController = TextEditingController();
  final _nfController = TextEditingController();
  final _fornecedorController = TextEditingController();
  final _evidenceController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _obsController.dispose();
    _obraController.dispose();
    _loteController.dispose();
    _nfController.dispose();
    _fornecedorController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final q = double.tryParse(_quantityController.text) ?? 0;
    if (!q.isFinite || q <= 0) return;

    final isSaida = widget.type == MovimentacaoType.saida;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final mov = Movimentacao(
        id: const Uuid().v4(),
        materialId: widget.material.id,
        type: widget.type,
        quantity: q,
        date: DateTime.now(),
        responsavelId: uid,
        obraId: _obraController.text.trim().isEmpty
            ? null
            : _obraController.text.trim(),
        loteId: _loteController.text.trim().isEmpty
            ? null
            : _loteController.text.trim(),
        observacao: _obsController.text.trim(),
        nfNumber: !isSaida && _nfController.text.trim().isNotEmpty
            ? _nfController.text.trim()
            : null,
        fornecedor: !isSaida && _fornecedorController.text.trim().isNotEmpty
            ? _fornecedorController.text.trim()
            : null,
        evidence: !isSaida && _evidenceController.text.trim().isNotEmpty
            ? _evidenceController.text.trim()
            : null,
      );

      await ref
          .read(almoxarifadoRepositoryProvider)
          .registrarMovimentacao(widget.construtoraId, mov);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Operação pendente de confirmação. O saldo oficial muda após aceite do servidor.',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaida = widget.type == MovimentacaoType.saida;
    return Scaffold(
      appBar: AppBar(
        title: Text(isSaida ? 'Saída de Material' : 'Entrada de Material'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Material: ${widget.material.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Estoque Atual: ${widget.material.currentQuantity} ${widget.material.unit}',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Quantidade (${widget.material.unit})',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Informe a quantidade';
                  final v = double.tryParse(val);
                  if (v == null || !v.isFinite || v <= 0) {
                    return 'Valor inválido';
                  }
                  try {
                    decimalUnits(val, 3);
                  } catch (_) {
                    return 'Use até 3 casas decimais';
                  }
                  if (isSaida && v > widget.material.currentQuantity) {
                    return 'Estoque insuficiente';
                  }
                  return null;
                },
              ),
              if (isSaida) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _obraController,
                  decoration: const InputDecoration(
                    labelText: 'ID da Obra de Destino',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe a obra de destino'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _loteController,
                  decoration: const InputDecoration(
                    labelText: 'Lote de Destino (Opcional)',
                  ),
                ),
              ],
              if (!isSaida) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nfController,
                  decoration: const InputDecoration(
                    labelText: 'Número da Nota Fiscal (NF)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fornecedorController,
                  decoration: const InputDecoration(
                    labelText: 'Fornecedor',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _evidenceController,
                  decoration: const InputDecoration(
                    labelText: 'Evidência / Comprovante (URL ou Referência)',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _obsController,
                decoration: const InputDecoration(
                  labelText: 'Observação (Ex: Motivo, Entregador)',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text('Confirmar ${isSaida ? 'Saída' : 'Entrada'}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

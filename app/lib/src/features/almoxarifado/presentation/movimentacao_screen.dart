import 'package:flutter/material.dart';

import '../../../core/contracts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/almoxarifado_repository.dart';
import '../domain/material.dart' as mat;
import '../domain/movimentacao.dart';
import '../../obras/presentation/construtora_obras_provider.dart';
import '../../lotes/presentation/obra_lotes_provider.dart';

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
  final _solicitanteController = TextEditingController();
  final _nfController = TextEditingController();
  final _fornecedorController = TextEditingController();
  final _evidenceController = TextEditingController();
  String? _selectedObraId;
  String? _selectedLoteId;
  bool _apropriacaoLote = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _obsController.dispose();
    _obraController.dispose();
    _loteController.dispose();
    _solicitanteController.dispose();
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
      final finalObraId = _selectedObraId ??
          (_obraController.text.trim().isEmpty ? null : _obraController.text.trim());
      final finalLoteId = _selectedLoteId ??
          (_loteController.text.trim().isEmpty ? null : _loteController.text.trim());

      if (isSaida && _apropriacaoLote && (finalLoteId == null || finalLoteId.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione o lote para apropriação')),
        );
        return;
      }

      final mov = Movimentacao(
        id: const Uuid().v4(),
        materialId: widget.material.id,
        type: widget.type,
        quantity: q,
        date: DateTime.now(),
        responsavelId: uid,
        obraId: finalObraId,
        loteId: finalLoteId,
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
        apropriacaoLote: isSaida ? _apropriacaoLote : null,
        solicitante: isSaida && _solicitanteController.text.trim().isNotEmpty
            ? _solicitanteController.text.trim()
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                ref.watch(construtoraObrasProvider(widget.construtoraId)).when(
                  data: (obras) {
                    if (obras.isNotEmpty) {
                      return DropdownButtonFormField<String>(
                        key: const Key('obra-dropdown'),
                        initialValue: _selectedObraId,
                        decoration: const InputDecoration(
                          labelText: 'Obra de Destino',
                        ),
                        items: obras
                            .map((o) => DropdownMenuItem(
                                  value: o.id,
                                  child: Text(o.name),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedObraId = val;
                            _selectedLoteId = null;
                            _obraController.text = val ?? '';
                            _loteController.clear();
                          });
                        },
                        validator: (v) =>
                            (v == null || v.isEmpty) &&
                            _obraController.text.trim().isEmpty
                                ? 'Informe a obra de destino'
                                : null,
                      );
                    }
                    return TextFormField(
                      controller: _obraController,
                      decoration: const InputDecoration(
                        labelText: 'ID da Obra de Destino',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Informe a obra de destino'
                          : null,
                    );
                  },
                  loading: () => TextFormField(
                    controller: _obraController,
                    decoration: const InputDecoration(
                      labelText: 'ID da Obra de Destino',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe a obra de destino'
                        : null,
                  ),
                  error: (_, _) => TextFormField(
                    controller: _obraController,
                    decoration: const InputDecoration(
                      labelText: 'ID da Obra de Destino',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe a obra de destino'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                if ((_selectedObraId ?? _obraController.text.trim()).isNotEmpty)
                  ref
                      .watch(obraLotesProvider((
                        construtoraId: widget.construtoraId,
                        obraId: _selectedObraId ?? _obraController.text.trim()
                      )))
                      .when(
                        data: (lotes) {
                          if (lotes.isNotEmpty) {
                            return DropdownButtonFormField<String>(
                              key: const Key('lote-dropdown'),
                              initialValue: _selectedLoteId,
                              decoration: const InputDecoration(
                                labelText: 'Lote de Destino (Opcional)',
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Nenhum lote específico (Geral da Obra)'),
                                ),
                                ...lotes.map((l) => DropdownMenuItem(
                                      value: l.id,
                                      child: Text('${l.name} (${l.phase})'),
                                    )),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedLoteId = val;
                                  _loteController.text = val ?? '';
                                });
                              },
                              validator: (val) {
                                if (_apropriacaoLote &&
                                    (val == null || val.isEmpty) &&
                                    _loteController.text.trim().isEmpty) {
                                  return 'Selecione o lote para apropriação';
                                }
                                return null;
                              },
                            );
                          }
                          return TextFormField(
                            controller: _loteController,
                            decoration: const InputDecoration(
                              labelText: 'Lote de Destino (Opcional)',
                            ),
                            validator: (v) {
                              if (_apropriacaoLote &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Selecione o lote para apropriação';
                              }
                              return null;
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => TextFormField(
                          controller: _loteController,
                          decoration: const InputDecoration(
                            labelText: 'Lote de Destino (Opcional)',
                          ),
                          validator: (v) {
                            if (_apropriacaoLote &&
                                (v == null || v.trim().isEmpty)) {
                              return 'Selecione o lote para apropriação';
                            }
                            return null;
                          },
                        ),
                      )
                else
                  TextFormField(
                    controller: _loteController,
                    decoration: const InputDecoration(
                      labelText: 'Lote de Destino (Opcional)',
                    ),
                    validator: (v) {
                      if (_apropriacaoLote && (v == null || v.trim().isEmpty)) {
                        return 'Selecione o lote para apropriação';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 10),
                SwitchListTile(
                  key: const Key('apropriacao-lote-switch'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apropriar diretamente ao Lote'),
                  subtitle: const Text(
                    'Vincula o consumo do material à unidade',
                  ),
                  value: _apropriacaoLote,
                  onChanged: (val) {
                    setState(() => _apropriacaoLote = val);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _solicitanteController,
                  decoration: const InputDecoration(
                    labelText: 'Solicitante / Retirado por (Opcional)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ],
              if (!isSaida) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nfController,
                  decoration: const InputDecoration(
                    labelText: 'Número da Nota Fiscal (NF)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _fornecedorController,
                  decoration: const InputDecoration(
                    labelText: 'Fornecedor',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _evidenceController,
                  decoration: const InputDecoration(
                    labelText: 'Evidência / Comprovante (URL ou Referência)',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _obsController,
                decoration: const InputDecoration(
                  labelText: 'Observação (Ex: Motivo, Entregador)',
                ),
              ),
              const SizedBox(height: 16),
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

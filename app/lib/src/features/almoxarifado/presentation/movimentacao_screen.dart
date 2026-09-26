import 'package:flutter/material.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../../core/contracts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/almoxarifado_repository.dart';
import '../domain/material.dart' as mat;
import '../domain/movimentacao.dart';
import '../../obras/presentation/construtora_obras_provider.dart';
import '../../lotes/presentation/widgets/lote_hierarchy_selector.dart';
import '../../fornecedores/presentation/widgets/fornecedor_autocomplete_field.dart';

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
  final _valorItensController = TextEditingController();
  final _freteController = TextEditingController();
  final _despesasController = TextEditingController();
  final _descontoController = TextEditingController();
  final _custoUnitarioSaidaController = TextEditingController();
  final _custoTotalSaidaController = TextEditingController();
  String? _selectedObraId;
  String? _selectedLoteId;
  String? _loteamentoId;
  String? _quadraId;
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
    _valorItensController.dispose();
    _freteController.dispose();
    _despesasController.dispose();
    _descontoController.dispose();
    _custoUnitarioSaidaController.dispose();
    _custoTotalSaidaController.dispose();
    super.dispose();
  }

  int? _parseCents(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      return parseCurrencyToCents(text);
    } catch (_) {
      return null;
    }
  }

  String _formatCents(int cents) => formatCents(cents);

  String? _validateMoneyField(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final cents = _parseCents(val);
    if (cents == null || cents < 0) {
      return 'Informe um valor monetário válido';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final int qUnits;
    try {
      qUnits = parseQuantityUnits(_quantityController.text, scale: 1000);
    } catch (_) {
      return;
    }
    if (qUnits <= 0) return;
    final q = qUnits / 1000.0;

    final isSaida = widget.type == MovimentacaoType.saida;

    setState(() => _isLoading = true);

    try {
      String uid = 'unknown';
      try {
        uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      } catch (_) {}
      final finalObraId =
          _selectedObraId ??
          (_obraController.text.trim().isEmpty
              ? null
              : _obraController.text.trim());
      final finalLoteId =
          _selectedLoteId ??
          (_loteController.text.trim().isEmpty
              ? null
              : _loteController.text.trim());

      if (isSaida &&
          _apropriacaoLote &&
          (finalLoteId == null || finalLoteId.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione o lote para apropriação')),
        );
        return;
      }

      int? valorItensCentavos;
      int? freteCentavos;
      int? despesasCentavos;
      int? descontoCentavos;
      int? custoTotalCentavos;
      int? custoUnitarioCentavos;

      if (!isSaida) {
        final hasFinancialInfo =
            _valorItensController.text.trim().isNotEmpty ||
            _freteController.text.trim().isNotEmpty ||
            _despesasController.text.trim().isNotEmpty ||
            _descontoController.text.trim().isNotEmpty;

        if (hasFinancialInfo) {
          final vItens = _parseCents(_valorItensController.text) ?? 0;
          final vFrete = _parseCents(_freteController.text) ?? 0;
          final vDesp = _parseCents(_despesasController.text) ?? 0;
          final vDesc = _parseCents(_descontoController.text) ?? 0;

          if (vItens < 0 || vFrete < 0 || vDesp < 0 || vDesc < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Valores monetários não podem ser negativos'),
              ),
            );
            return;
          }

          final total = (vItens + vFrete + vDesp) - vDesc;
          if (total < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Desconto não pode exceder o valor total'),
              ),
            );
            return;
          }

          valorItensCentavos = vItens;
          freteCentavos = vFrete;
          despesasCentavos = vDesp;
          descontoCentavos = vDesc;
          custoTotalCentavos = total;
          custoUnitarioCentavos = q > 0 ? (total / q).round() : 0;
        }
      } else {
        final hasUnit = _custoUnitarioSaidaController.text.trim().isNotEmpty;
        final hasTot = _custoTotalSaidaController.text.trim().isNotEmpty;
        if (hasUnit || hasTot) {
          if (hasUnit) {
            final unitCents = _parseCents(_custoUnitarioSaidaController.text);
            if (unitCents != null && unitCents >= 0) {
              custoUnitarioCentavos = unitCents;
              custoTotalCentavos = hasTot
                  ? _parseCents(_custoTotalSaidaController.text)
                  : (unitCents * q).round();
            }
          } else if (hasTot) {
            final totCents = _parseCents(_custoTotalSaidaController.text);
            if (totCents != null && totCents >= 0) {
              custoTotalCentavos = totCents;
              custoUnitarioCentavos = q > 0 ? (totCents / q).round() : 0;
            }
          }
        }
      }

      final mov = Movimentacao(
        id: const Uuid().v4(),
        materialId: widget.material.id,
        type: widget.type,
        quantity: q,
        quantityUnits: qUnits,
        quantityScale: 1000,
        deltaUnits: isSaida ? -qUnits : qUnits,
        commandType: isSaida ? 'saida' : 'entrada',
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
        valorItensCentavos: valorItensCentavos,
        freteCentavos: freteCentavos,
        despesasCentavos: despesasCentavos,
        descontoCentavos: descontoCentavos,
        custoTotalCentavos: custoTotalCentavos,
        custoUnitarioCentavos: custoUnitarioCentavos,
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
    return SigoLayout(
      title: isSaida ? 'Saída de Material' : 'Entrada de Material',
      activeRoute: '/construtoras/${widget.construtoraId}/almoxarifado',
      child: Padding(
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
                'Estoque Atual: ${formatQuantityWithScale(widget.material.displayQuantity)} ${widget.material.unit}',
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
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Informe a quantidade';
                  }
                  final int units;
                  try {
                    units = parseQuantityUnits(
                      val,
                      scale: 1000,
                      allowNegative: false,
                    );
                  } on FormatException catch (e) {
                    if (e.message == 'Use até 3 casas decimais') {
                      return 'Use até 3 casas decimais';
                    }
                    return 'Valor inválido';
                  } catch (_) {
                    return 'Valor inválido';
                  }
                  if (units <= 0) {
                    return 'Valor inválido';
                  }
                  final v = units / 1000.0;
                  if (isSaida && v > widget.material.displayQuantity) {
                    return 'Estoque insuficiente';
                  }
                  return null;
                },
              ),
              if (isSaida) ...[
                const SizedBox(height: 10),
                ref
                    .watch(construtoraObrasProvider(widget.construtoraId))
                    .when(
                      data: (obras) {
                        if (obras.isNotEmpty) {
                          return DropdownButtonFormField<String>(
                            key: const Key('obra-dropdown'),
                            initialValue: _selectedObraId,
                            decoration: const InputDecoration(
                              labelText: 'Loteamento de Destino',
                            ),
                            items: obras
                                .map(
                                  (o) => DropdownMenuItem(
                                    value: o.id,
                                    child: Text(o.name),
                                  ),
                                )
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
                                ? 'Informe o loteamento de destino'
                                : null,
                          );
                        }
                        return TextFormField(
                          controller: _obraController,
                          decoration: const InputDecoration(
                            labelText: 'ID do Loteamento de Destino',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Informe o loteamento de destino'
                              : null,
                        );
                      },
                      loading: () => TextFormField(
                        controller: _obraController,
                        decoration: const InputDecoration(
                          labelText: 'ID do Loteamento de Destino',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o loteamento de destino'
                            : null,
                      ),
                      error: (_, _) => TextFormField(
                        controller: _obraController,
                        decoration: const InputDecoration(
                          labelText: 'ID do Loteamento de Destino',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o loteamento de destino'
                            : null,
                      ),
                    ),
                const SizedBox(height: 16),
                LoteHierarchySelector(
                  construtoraId: widget.construtoraId,
                  loteamentoId: _loteamentoId,
                  quadraId: _quadraId,
                  loteId: _selectedLoteId,
                  enabled: !_isLoading,
                  loteValidator: (val) {
                    if (_apropriacaoLote && (val == null || val.isEmpty)) {
                      return 'Selecione o lote para apropriação';
                    }
                    return null;
                  },
                  onLoteamentoChanged: (val) {
                    setState(() {
                      _loteamentoId = val;
                      _quadraId = null;
                      _selectedLoteId = null;
                      _loteController.clear();
                    });
                  },
                  onQuadraChanged: (val) {
                    setState(() {
                      _quadraId = val;
                      _selectedLoteId = null;
                      _loteController.clear();
                    });
                  },
                  onLoteChanged: (val) {
                    setState(() {
                      _selectedLoteId = val;
                      _loteController.text = val ?? '';
                    });
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
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  children: const [
                    Icon(
                      Icons.monetization_on_outlined,
                      size: 20,
                      color: Colors.blueGrey,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Custo de Apropriação ao Lote (Opcional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('custo-unitario-field'),
                  controller: _custoUnitarioSaidaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Custo Unitário (R\$)',
                    hintText: 'Ex: 35,00',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: _validateMoneyField,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('custo-total-field'),
                  controller: _custoTotalSaidaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Custo Total Apropriado (R\$)',
                    hintText: 'Ex: 350,00',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: _validateMoneyField,
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
                FornecedorAutocompleteField(
                  construtoraId: widget.construtoraId,
                  labelText: 'Fornecedor',
                  initialValue: _fornecedorController.text,
                  onSelected: (f) {
                    setState(() {
                      _fornecedorController.text = f.nomeExibicao;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _evidenceController,
                  decoration: const InputDecoration(
                    labelText: 'Evidência / Comprovante (URL ou Referência)',
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  children: const [
                    Icon(
                      Icons.calculate_outlined,
                      size: 20,
                      color: Colors.blueGrey,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rateio e Custos de Aquisição (Opcional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('valor-itens-field'),
                  controller: _valorItensController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor dos Itens (R\$)',
                    hintText: 'Ex: 1500,00',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: _validateMoneyField,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('frete-field'),
                  controller: _freteController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor do Frete (R\$)',
                    hintText: 'Ex: 100,00',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: _validateMoneyField,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('despesas-field'),
                  controller: _despesasController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Outras Despesas Acessórias (R\$)',
                    hintText: 'Ex: 50,00',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: _validateMoneyField,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('desconto-field'),
                  controller: _descontoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Desconto Concedido (R\$)',
                    hintText: 'Ex: 20,00',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (val) {
                    final err = _validateMoneyField(val);
                    if (err != null) return err;
                    final dCents = _parseCents(val ?? '') ?? 0;
                    final bCents =
                        (_parseCents(_valorItensController.text) ?? 0) +
                        (_parseCents(_freteController.text) ?? 0) +
                        (_parseCents(_despesasController.text) ?? 0);
                    if (dCents > bCents) {
                      return 'Desconto não pode exceder o valor total';
                    }
                    return null;
                  },
                ),
                Builder(
                  builder: (context) {
                    final hasFin =
                        _valorItensController.text.trim().isNotEmpty ||
                        _freteController.text.trim().isNotEmpty ||
                        _despesasController.text.trim().isNotEmpty ||
                        _descontoController.text.trim().isNotEmpty;
                    if (!hasFin) return const SizedBox.shrink();

                    final vi = _parseCents(_valorItensController.text) ?? 0;
                    final vf = _parseCents(_freteController.text) ?? 0;
                    final vd = _parseCents(_despesasController.text) ?? 0;
                    final vdesc = _parseCents(_descontoController.text) ?? 0;
                    final total = (vi + vf + vd) - vdesc;
                    final isNegative = total < 0;
                    double qVal = 0.0;
                    try {
                      qVal =
                          parseQuantityUnits(
                            _quantityController.text,
                            scale: 1000,
                          ) /
                          1000.0;
                    } catch (_) {}
                    final unitCents = (qVal > 0 && !isNegative)
                        ? (total / qVal).round()
                        : null;

                    return Container(
                      key: const Key('rateio-preview-card'),
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isNegative
                            ? Colors.red.shade50
                            : Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isNegative
                              ? Colors.red.shade300
                              : Colors.blueGrey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isNegative) ...[
                            Text(
                              'Desconto não pode exceder o valor total',
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Custo Total da Entrada:',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _formatCents(total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            if (unitCents != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Custo Unitário Efetivo:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_formatCents(unitCents)} / ${widget.material.unit}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'Composição: Itens ${_formatCents(vi)} | Frete ${_formatCents(vf)} | Desp ${_formatCents(vd)} | Desc ${_formatCents(vdesc)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Divider(),
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

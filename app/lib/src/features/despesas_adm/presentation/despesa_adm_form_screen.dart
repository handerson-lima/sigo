import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../common_widgets/sigo_top_bar.dart';
import '../../authentication/data/auth_repository.dart';
import '../../lotes/presentation/obra_lotes_provider.dart';
import '../data/despesas_adm_repository.dart';
import '../domain/despesa_adm.dart';
import '../domain/parcelamento_math.dart';
import '../../fornecedores/presentation/widgets/fornecedor_autocomplete_field.dart';

class DespesaAdmFormScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;
  final String? despesaId;

  const DespesaAdmFormScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
    this.despesaId,
  });

  @override
  ConsumerState<DespesaAdmFormScreen> createState() =>
      _DespesaAdmFormScreenState();
}

class _DespesaAdmFormScreenState extends ConsumerState<DespesaAdmFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _fornecedorController = TextEditingController();
  String? _fornecedorId;

  CategoriaDespesa _categoria = CategoriaDespesa.locacao;
  String? _selectedLoteId;

  DateTime _dataEmissao = DateTime.now();
  DateTime _dataVencimento = DateTime.now().add(const Duration(days: 30));

  bool _isParcelado = false;
  int _numeroParcelas = 2;
  List<ParcelaDespesa> _parcelas = [];

  bool _isLoading = false;
  String? _errorMessage;

  Uint8List? _comprovanteBytes;
  String? _comprovanteFileName;

  @override
  void initState() {
    super.initState();
    if (widget.despesaId != null) {
      _loadExistingDespesa();
    }
  }

  Future<void> _loadExistingDespesa() async {
    setState(() => _isLoading = true);
    try {
      final despesa = await ref.read(despesasAdmRepositoryProvider).getDespesa(
            widget.construtoraId,
            widget.obraId,
            widget.despesaId!,
          );
      if (despesa != null && mounted) {
        _descricaoController.text = despesa.descricao;
        _valorController.text =
            (despesa.valorTotalCents / 100.0).toStringAsFixed(2);
        _fornecedorController.text = despesa.fornecedorNome ?? '';
        _fornecedorId = despesa.fornecedorId;
        _categoria = despesa.categoria;
        _selectedLoteId = despesa.loteId;
        _dataEmissao = despesa.dataEmissao;
        _dataVencimento = despesa.dataVencimento;
        _isParcelado = despesa.isParcelado;
        _parcelas = List.from(despesa.parcelas);
        _numeroParcelas =
            despesa.parcelas.isNotEmpty ? despesa.parcelas.length : 2;
      }
    } catch (e) {
      _errorMessage = 'Erro ao carregar despesa: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _fornecedorController.dispose();
    super.dispose();
  }

  int _parseValorTotalCents() {
    final clean = _valorController.text
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    final parsed = double.tryParse(clean) ?? 0.0;
    return (parsed * 100).round();
  }

  void _gerarParcelasAutomaticas() {
    final totalCents = _parseValorTotalCents();
    if (totalCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor total válido antes de gerar as parcelas.'),
        ),
      );
      return;
    }

    setState(() {
      _parcelas = ParcelamentoMath.gerarParcelas(
        totalCents: totalCents,
        numeroParcelas: _numeroParcelas,
        primeiroVencimento: _dataVencimento,
      );
    });
  }

  Future<void> _pickComprovante() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _comprovanteBytes = bytes;
          _comprovanteFileName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao anexar arquivo: $e')),
        );
      }
    }
  }

  Future<void> _salvarDespesa() async {
    if (!_formKey.currentState!.validate()) return;

    final totalCents = _parseValorTotalCents();
    if (totalCents <= 0) {
      setState(() => _errorMessage = 'O valor da despesa deve ser maior que zero.');
      return;
    }

    if (_isParcelado) {
      if (_parcelas.isEmpty) {
        setState(() => _errorMessage =
            'Gere ou defina as parcelas antes de salvar a despesa.');
        return;
      }

      final invarianteValida = ParcelamentoMath.validarInvarianteParcelas(
        totalCents: totalCents,
        parcelas: _parcelas,
      );

      if (!invarianteValida) {
        final soma = ParcelamentoMath.calcularSomaParcelas(_parcelas);
        final diff = (totalCents - soma).abs();
        setState(() => _errorMessage =
            'A soma das parcelas (R\$ ${(soma / 100).toStringAsFixed(2)}) difere do total (R\$ ${(totalCents / 100).toStringAsFixed(2)}) por R\$ ${(diff / 100).toStringAsFixed(2)}.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(despesasAdmRepositoryProvider);
      final user = ref.read(authRepositoryProvider).currentUser;
      final uid = user?.uid ?? 'anon';

      final despesaId = widget.despesaId ?? const Uuid().v4();

      String? compUrl;
      String? compPath;
      String? compNome;

      if (_comprovanteBytes != null && _comprovanteFileName != null) {
        final contentType = _comprovanteFileName!.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : 'image/jpeg';

        final uploadResult = await repo.uploadComprovante(
          construtoraId: widget.construtoraId,
          obraId: widget.obraId,
          despesaId: despesaId,
          nomeArquivo: _comprovanteFileName!,
          bytes: _comprovanteBytes!,
          contentType: contentType,
        );
        compUrl = uploadResult.url;
        compPath = uploadResult.path;
        compNome = uploadResult.nome;
      }

      final despesa = DespesaAdm(
        id: despesaId,
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        descricao: _descricaoController.text.trim(),
        categoria: _categoria,
        fornecedorNome: _fornecedorController.text.trim().isNotEmpty
            ? _fornecedorController.text.trim()
            : null,
        fornecedorId: _fornecedorId,
        loteId: _selectedLoteId,
        valorTotalCents: totalCents,
        status: StatusDespesaAdm.pendente,
        dataEmissao: _dataEmissao,
        dataVencimento: _dataVencimento,
        isParcelado: _isParcelado,
        parcelas: _isParcelado ? _parcelas : const [],
        comprovanteUrl: compUrl,
        comprovantePath: compPath,
        comprovanteNome: compNome,
        responsavelId: uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.despesaId != null) {
        await repo.updateDespesa(despesa);
      } else {
        await repo.createDespesa(despesa);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao salvar despesa: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final lotesAsync = ref.watch(obraLotesProvider(
        (construtoraId: widget.construtoraId, obraId: widget.obraId)));

    final totalCents = _parseValorTotalCents();
    final somaParcelas = ParcelamentoMath.calcularSomaParcelas(_parcelas);
    final parcelasBatem = totalCents > 0 && totalCents == somaParcelas;

    return Scaffold(
      appBar: SigoTopBar(
        title: widget.despesaId != null
            ? 'Editar Despesa'
            : 'Nova Despesa / Conta a Pagar',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Descrição
                    TextFormField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição da Despesa *',
                        hintText: 'Ex.: Locação de Andaimes, Conta de Energia',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a descrição da despesa'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Categoria
                    DropdownButtonFormField<CategoriaDespesa>(
                      initialValue: _categoria,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Categoria de Custo *',
                        border: OutlineInputBorder(),
                      ),
                      items: CategoriaDespesa.values.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c.label),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _categoria = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fornecedor
                    FornecedorAutocompleteField(
                      construtoraId: widget.construtoraId,
                      initialValue: _fornecedorController.text,
                      onSelected: (f) {
                        setState(() {
                          _fornecedorId = f.id;
                          _fornecedorController.text = f.nomeExibicao;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Lote associado (para Visão 360)
                    lotesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox(),
                      data: (lotes) {
                        return DropdownButtonFormField<String?>(
                          initialValue: _selectedLoteId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Apropriação por Lote (Opcional)',
                            helperText:
                                'Selecione se for custo direto do lote ou deixe vazio para rateio geral',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('(Nenhum - Despesa Geral da Obra)'),
                            ),
                            ...lotes.map((l) {
                              return DropdownMenuItem<String?>(
                                value: l.id,
                                child: Text('Lote: ${l.name} (${l.phase})'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedLoteId = val);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Valor total
                    TextFormField(
                      controller: _valorController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor Total (R\$) *',
                        hintText: 'Ex.: 1250,50',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe o valor total';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (_isParcelado) {
                          _gerarParcelasAutomaticas();
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Datas
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _dataEmissao,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _dataEmissao = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Data de Emissão',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(dateFormat.format(_dataEmissao)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _dataVencimento,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 1825)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _dataVencimento = picked;
                                  if (_isParcelado) _gerarParcelasAutomaticas();
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Primeiro Vencimento',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(dateFormat.format(_dataVencimento)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Seletor de Parcelamento
                    Card(
                      elevation: 0,
                      color: Colors.purple.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.purple.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Desdobrar em Parcelas?',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'Garante matematicamente a soma exata de centavos.',
                              ),
                              value: _isParcelado,
                              onChanged: (val) {
                                setState(() {
                                  _isParcelado = val;
                                  if (val && _parcelas.isEmpty) {
                                    _gerarParcelasAutomaticas();
                                  }
                                });
                              },
                            ),
                            if (_isParcelado) ...[
                              const Divider(),
                              Row(
                                children: [
                                  const Text('Quantidade:'),
                                  const SizedBox(width: 12),
                                  DropdownButton<int>(
                                    value: _numeroParcelas,
                                    items: List.generate(35, (i) => i + 2)
                                        .map((n) => DropdownMenuItem(
                                              value: n,
                                              child: Text('${n}x parcelas'),
                                            ))
                                        .toList(),
                                    onChanged: (n) {
                                      if (n != null) {
                                        setState(() {
                                          _numeroParcelas = n;
                                          _gerarParcelasAutomaticas();
                                        });
                                      }
                                    },
                                  ),
                                  const Spacer(),
                                  OutlinedButton.icon(
                                    onPressed: _gerarParcelasAutomaticas,
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Recalcular'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Tabela de Parcelas Geradas
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _parcelas.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final p = _parcelas[idx];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 12,
                                      child: Text(
                                        '${p.numero}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    title: Text(
                                      'Vencimento: ${dateFormat.format(p.dataVencimento)}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    trailing: SizedBox(
                                      width: 120,
                                      child: TextFormField(
                                        initialValue: (p.valorCents / 100.0)
                                            .toStringAsFixed(2),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          prefixText: 'R\$ ',
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 6,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          final clean = val
                                              .replaceAll('R\$', '')
                                              .replaceAll('.', '')
                                              .replaceAll(',', '.')
                                              .trim();
                                          final cents =
                                              ((double.tryParse(clean) ?? 0.0) *
                                                      100)
                                                  .round();
                                          setState(() {
                                            _parcelas[idx] =
                                                p.copyWith(valorCents: cents);
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 12),

                              // Status da Invariante
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: parcelasBatem
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      parcelasBatem
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: parcelasBatem
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        parcelasBatem
                                            ? 'Invariante OK: Soma das parcelas (${currency.format(somaParcelas / 100.0)}) confere perfeitamente.'
                                            : 'Discrepância: Soma (${currency.format(somaParcelas / 100.0)}) != Total (${currency.format(totalCents / 100.0)})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: parcelasBatem
                                              ? Colors.green.shade900
                                              : Colors.red.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Anexo de Comprovante / PDF
                    const Text(
                      'Documento Comprobatório / Boleto (PDF ou Imagem):',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _pickComprovante,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _comprovanteFileName != null
                            ? 'Arquivo: $_comprovanteFileName'
                            : 'Anexar Nota Fiscal / Boleto / PDF',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botão Salvar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _salvarDespesa,
                        icon: const Icon(Icons.save),
                        label: Text(
                          widget.despesaId != null
                              ? 'Atualizar Despesa'
                              : 'Cadastrar Despesa',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade800,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

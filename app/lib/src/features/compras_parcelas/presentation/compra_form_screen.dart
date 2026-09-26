import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../almoxarifado/data/almoxarifado_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../fornecedores/domain/fornecedor.dart';
import '../../fornecedores/presentation/widgets/fornecedor_autocomplete_field.dart';
import '../data/compras_repository.dart';
import '../domain/compra_nf.dart';
import '../domain/item_compra.dart';
import '../domain/parcela_compra.dart';
import '../domain/parcelamento_compras_math.dart';

class CompraFormScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;
  final String? compraId;

  const CompraFormScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
    this.compraId,
  });

  @override
  ConsumerState<CompraFormScreen> createState() => _CompraFormScreenState();
}

class _CompraFormScreenState extends ConsumerState<CompraFormScreen> {
  final _formKey = GlobalKey<FormState>();

  Fornecedor? _fornecedorSelecionado;
  final _fornecedorNomeController = TextEditingController();

  final _numeroNfController = TextEditingController();
  final _serieNfController = TextEditingController();
  final _chaveAcessoController = TextEditingController();
  final _descricaoController = TextEditingController();

  DateTime _dataEmissao = DateTime.now();
  DateTime? _dataRecebimento;

  // Itens da compra
  final List<ItemCompraNf> _itens = [];

  // Encargos
  final _freteController = TextEditingController(text: '0,00');
  final _despesasController = TextEditingController(text: '0,00');
  final _descontoController = TextEditingController(text: '0,00');

  // Parcelamento
  int _numeroParcelas = 1;
  final DateTime _primeiroVencimento = DateTime.now();
  List<ParcelaCompra> _parcelas = [];

  bool _isLoading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _fornecedorNomeController.dispose();
    _numeroNfController.dispose();
    _serieNfController.dispose();
    _chaveAcessoController.dispose();
    _descricaoController.dispose();
    _freteController.dispose();
    _despesasController.dispose();
    _descontoController.dispose();
    super.dispose();
  }

  int _parseCents(String text) {
    if (text.trim().isEmpty) return 0;
    final sanitized = text.replaceAll('.', '').replaceAll(',', '.').trim();
    final val = double.tryParse(sanitized) ?? 0.0;
    return (val * 100).round();
  }

  int get _valorItensCents =>
      _itens.fold<int>(0, (acc, item) => acc + item.valorTotalCents);
  int get _freteCents => _parseCents(_freteController.text);
  int get _despesasAcessoriasCents => _parseCents(_despesasController.text);
  int get _descontoCents => _parseCents(_descontoController.text);

  int get _totalCompraCents {
    final total =
        _valorItensCents +
        _freteCents +
        _despesasAcessoriasCents -
        _descontoCents;
    return total < 0 ? 0 : total;
  }

  int get _discrepanciaCents =>
      ParcelamentoComprasMath.calcularDiscrepanciaCents(
        totalCompraCents: _totalCompraCents,
        parcelas: _parcelas,
      );

  bool get _isInvarianteValida =>
      ParcelamentoComprasMath.validarInvarianteParcelas(
        totalCompraCents: _totalCompraCents,
        parcelas: _parcelas,
      );

  void _gerarParcelas() {
    if (_totalCompraCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adicione itens ou informe valores para gerar parcelas.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _parcelas = ParcelamentoComprasMath.gerarParcelas(
        totalCompraCents: _totalCompraCents,
        numeroParcelas: _numeroParcelas,
        primeiroVencimento: _primeiroVencimento,
      );
    });
  }

  void _rebalancearPrimeiraParcela() {
    if (_parcelas.isEmpty || _totalCompraCents <= 0) return;
    final somaDemais = _parcelas
        .skip(1)
        .fold<int>(0, (acc, p) => acc + p.valorCents);
    final novoValorP1 = _totalCompraCents - somaDemais;
    if (novoValorP1 <= 0) return;

    setState(() {
      _parcelas[0] = _parcelas[0].copyWith(valorCents: novoValorP1);
    });
  }

  Future<void> _adicionarItemModal() async {
    final materiaisAsync = ref.read(
      almoxarifadoRepositoryProvider.select(
        (repo) => repo.watchMateriais(widget.construtoraId),
      ),
    );

    final materiais = await materiaisAsync.first;

    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    String? selectedMaterialId;
    final nomeCtrl = TextEditingController();
    final unidCtrl = TextEditingController(text: 'un');
    final qtdCtrl = TextEditingController(text: '1');
    final precoCtrl = TextEditingController(text: '0,00');

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Adicionar Item Faturado'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (materiais.isNotEmpty)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Selecionar do Almoxarifado',
                        border: OutlineInputBorder(),
                      ),
                      items: materiais.map((m) {
                        return DropdownMenuItem(
                          value: m.id,
                          child: Text('${m.name} (${m.unit})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedMaterialId = val;
                          final matObj = materiais.firstWhere(
                            (m) => m.id == val,
                          );
                          nomeCtrl.text = matObj.name;
                          unidCtrl.text = matObj.unit;
                        });
                      },
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descrição do Material *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe a descrição'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: unidCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Unidade *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Informe a unidade'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: qtdCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Quantidade *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Informe a qtd';
                            }
                            final n = double.tryParse(v.replaceAll(',', '.'));
                            if (n == null || n <= 0) return 'Valor > 0';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: precoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preço Unitário (R\$) *',
                      border: OutlineInputBorder(),
                      prefixText: 'R\$ ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Informe o valor';
                      }
                      final c = _parseCents(v);
                      if (c <= 0) return 'Valor > 0';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );

    if (added == true) {
      final qtd = double.parse(qtdCtrl.text.replaceAll(',', '.'));
      final unitCents = _parseCents(precoCtrl.text);
      final totalCents = (qtd * unitCents).round();

      setState(() {
        _itens.add(
          ItemCompraNf(
            id: 'item_${DateTime.now().millisecondsSinceEpoch}',
            materialId: selectedMaterialId ?? 'mat_${_itens.length + 1}',
            materialNome: nomeCtrl.text.trim(),
            unidadeMedida: unidCtrl.text.trim(),
            quantidade: qtd,
            valorUnitarioCents: unitCents,
            valorTotalCents: totalCents,
          ),
        );
      });
      _gerarParcelas();
    }
  }

  Future<void> _salvarCompra() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fornecedorSelecionado == null &&
        _fornecedorNomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ou informe o fornecedor.')),
      );
      return;
    }

    if (_itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um item faturado.')),
      );
      return;
    }

    if (!_isInvarianteValida) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A soma das parcelas deve ser estritamente igual ao total da compra.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      final uid = user?.uid ?? 'anon_user';
      final now = DateTime.now();

      final idCompra =
          widget.compraId ??
          'compra_${widget.obraId}_${DateTime.now().millisecondsSinceEpoch}';

      final compra = CompraNf(
        id: idCompra,
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        fornecedorId: _fornecedorSelecionado?.id ?? 'forn_manual',
        fornecedorNome:
            _fornecedorSelecionado?.nomeExibicao ??
            _fornecedorNomeController.text.trim(),
        fornecedorDocumento: _fornecedorSelecionado?.documento,
        numeroNf: _numeroNfController.text.trim(),
        serieNf: _serieNfController.text.trim().isEmpty
            ? null
            : _serieNfController.text.trim(),
        chaveAcessoNf: _chaveAcessoController.text.trim().isEmpty
            ? null
            : _chaveAcessoController.text.trim(),
        dataEmissao: _dataEmissao,
        dataRecebimento: _dataRecebimento,
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        valorItensCents: _valorItensCents,
        freteCents: _freteCents,
        despesasAcessoriasCents: _despesasAcessoriasCents,
        descontoCents: _descontoCents,
        totalCompraCents: _totalCompraCents,
        itens: _itens,
        parcelas: _parcelas,
        criadoPorUid: uid,
        createdAt: now,
        updatedAt: now,
      );

      final repo = ref.read(comprasRepositoryProvider);
      if (widget.compraId == null) {
        await repo.createCompra(compra);
      } else {
        await repo.updateCompra(compra);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compra / NF salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar compra: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compraId != null && !_initialized) {
      final compraAsync = ref.watch(
        compraDetailsFutureProvider((
          construtoraId: widget.construtoraId,
          obraId: widget.obraId,
          compraId: widget.compraId!,
        )),
      );

      compraAsync.whenData((compra) {
        if (compra != null && !_initialized) {
          _initialized = true;
          _numeroNfController.text = compra.numeroNf;
          _serieNfController.text = compra.serieNf ?? '';
          _chaveAcessoController.text = compra.chaveAcessoNf ?? '';
          _descricaoController.text = compra.descricao ?? '';
          _fornecedorNomeController.text = compra.fornecedorNome;
          _dataEmissao = compra.dataEmissao;
          _dataRecebimento = compra.dataRecebimento;
          _freteController.text = (compra.freteCents / 100.0)
              .toStringAsFixed(2)
              .replaceAll('.', ',');
          _despesasController.text = (compra.despesasAcessoriasCents / 100.0)
              .toStringAsFixed(2)
              .replaceAll('.', ',');
          _descontoController.text = (compra.descontoCents / 100.0)
              .toStringAsFixed(2)
              .replaceAll('.', ',');
          _itens.clear();
          _itens.addAll(compra.itens);
          _parcelas.clear();
          _parcelas.addAll(compra.parcelas);
          _numeroParcelas = compra.parcelas.isEmpty
              ? 1
              : compra.parcelas.length;
          setState(() {});
        }
      });
    }

    return SigoLayout(
      title: widget.compraId == null
          ? 'Nova Compra / Nota Fiscal'
          : 'Editar Compra / NF',
      activeRoute:
          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/compras',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seção 1: Dados do Fornecedor e NF
                    _buildDadosNfCard(),
                    const SizedBox(height: 16),

                    // Seção 2: Itens Faturados
                    _buildItensCard(),
                    const SizedBox(height: 16),

                    // Seção 3: Encargos e Total
                    _buildEncargosCard(),
                    const SizedBox(height: 16),

                    // Seção 4: Desdobramento em Parcelas
                    _buildParcelasCard(),
                    const SizedBox(height: 24),

                    // Botão Salvar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: (_isInvarianteValida && _itens.isNotEmpty)
                            ? _salvarCompra
                            : null,
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Salvar Compra / NF',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(padding: const EdgeInsets.all(16.0), child: child),
    );
  }

  Widget _buildDadosNfCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Dados Fiscais e Fornecedor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FornecedorAutocompleteField(
            construtoraId: widget.construtoraId,
            initialValue: _fornecedorNomeController.text,
            onSelected: (fornecedor) {
              setState(() {
                _fornecedorSelecionado = fornecedor;
                _fornecedorNomeController.text = fornecedor.nomeExibicao;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _numeroNfController,
                  decoration: const InputDecoration(
                    labelText: 'Número da NF *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe o número da NF'
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _serieNfController,
                  decoration: const InputDecoration(
                    labelText: 'Série',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _chaveAcessoController,
            maxLength: 44,
            decoration: const InputDecoration(
              labelText: 'Chave de Acesso da NF-e (44 dígitos)',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dataEmissao,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _dataEmissao = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de Emissão *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${_dataEmissao.day.toString().padLeft(2, '0')}/${_dataEmissao.month.toString().padLeft(2, '0')}/${_dataEmissao.year}',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dataRecebimento ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _dataRecebimento = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Previsão / Recebimento',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.event_available),
                    ),
                    child: Text(
                      _dataRecebimento == null
                          ? 'Não informada'
                          : '${_dataRecebimento!.day.toString().padLeft(2, '0')}/${_dataRecebimento!.month.toString().padLeft(2, '0')}/${_dataRecebimento!.year}',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descricaoController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observação / Descrição da Compra',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItensCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '2. Itens Faturados (${_itens.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _adicionarItemModal,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Item'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_itens.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Nenhum item adicionado. Adicione os materiais desta nota fiscal.',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itens.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (ctx, idx) {
                final item = _itens[idx];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${idx + 1}')),
                  title: Text(
                    item.materialNome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item.quantidade} ${item.unidadeMedida} × R\$ ${item.valorUnitario.toStringAsFixed(2)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'R\$ ${item.valorTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() => _itens.removeAt(idx));
                          _gerarParcelas();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEncargosCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3. Encargos, Descontos e Total',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _freteController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Frete (R\$)',
                    border: OutlineInputBorder(),
                    prefixText: 'R\$ ',
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _gerarParcelas();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _despesasController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Outras Despesas',
                    border: OutlineInputBorder(),
                    prefixText: 'R\$ ',
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _gerarParcelas();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _descontoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Desconto (R\$)',
                    border: OutlineInputBorder(),
                    prefixText: 'R\$ ',
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _gerarParcelas();
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'VALOR TOTAL DA COMPRA:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'R\$ ${(_totalCompraCents / 100.0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelasCard() {
    final discrepancia = _discrepanciaCents;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '4. Desdobramento em Parcelas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  DropdownButton<int>(
                    value: _numeroParcelas,
                    items: List.generate(24, (i) => i + 1).map((n) {
                      return DropdownMenuItem(
                        value: n,
                        child: Text('$n parcela${n > 1 ? "s" : ""}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _numeroParcelas = val);
                        _gerarParcelas();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _gerarParcelas,
                    child: const Text('Recalcular'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Banner de Validação da Invariante
          if (_parcelas.isNotEmpty && discrepancia != 0)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Discrepância detectada: ${discrepancia > 0 ? "Faltam" : "Excesso de"} R\$ ${(discrepancia.abs() / 100.0).toStringAsFixed(2)}. A soma deve ser exata.',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _rebalancearPrimeiraParcela,
                    child: const Text('Ajustar 1ª Parcela'),
                  ),
                ],
              ),
            )
          else if (_parcelas.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Invariante algébrica validada: soma das parcelas = total.',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          if (_parcelas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Nenhuma parcela gerada ainda.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _parcelas.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (ctx, idx) {
                final p = _parcelas[idx];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      child: Text(
                        '${p.numero}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Vencimento: ${p.dataVencimento.day.toString().padLeft(2, '0')}/${p.dataVencimento.month.toString().padLeft(2, '0')}/${p.dataVencimento.year}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: (p.valorCents / 100.0)
                            .toStringAsFixed(2)
                            .replaceAll('.', ','),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final cents = _parseCents(val);
                          setState(() {
                            _parcelas[idx] = p.copyWith(valorCents: cents);
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../data/fornecedores_repository.dart';
import '../domain/fornecedor.dart';
import '../domain/fornecedor_validator.dart';
import 'fornecedores_controller.dart';

class FornecedorFormScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String? fornecedorId;

  const FornecedorFormScreen({
    super.key,
    required this.construtoraId,
    this.fornecedorId,
  });

  @override
  ConsumerState<FornecedorFormScreen> createState() =>
      _FornecedorFormScreenState();
}

class _FornecedorFormScreenState extends ConsumerState<FornecedorFormScreen> {
  final _formKey = GlobalKey<FormState>();

  TipoPessoa _tipoPessoa = TipoPessoa.juridica;
  final _documentoController = TextEditingController();
  final _razaoSocialController = TextEditingController();
  final _nomeFantasiaController = TextEditingController();
  final _inscricaoEstadualController = TextEditingController();
  final _inscricaoMunicipalController = TextEditingController();
  final _nomeContatoController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _observacoesController = TextEditingController();

  // Endereço
  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();

  // Dados Bancários / Pix
  final _chavePixController = TextEditingController();
  String _tipoChavePix = 'cnpj';
  final _bancoController = TextEditingController();
  final _agenciaController = TextEditingController();
  final _contaController = TextEditingController();
  final _favorecidoController = TextEditingController();

  final Set<String> _categoriasSelecionadas = {};
  bool _dadosCarregados = false;
  bool _salvando = false;

  final List<({String key, String label})> _todasCategorias = [
    (key: 'materiais_basicos', label: 'Materiais Básicos'),
    (key: 'eletrica_hidraulica', label: 'Elétrica & Hidráulica'),
    (key: 'acabamento', label: 'Acabamento'),
    (key: 'locacao_equipamentos', label: 'Locação de Equipamentos'),
    (key: 'servicos_empreiteiro', label: 'Empreiteiro / Mão de Obra'),
    (key: 'transporte_cacamba', label: 'Transporte & Caçambas'),
    (key: 'epi', label: 'EPI & Segurança'),
    (key: 'alimentacao', label: 'Alimentação'),
    (key: 'servicos_adm', label: 'Serviços ADM'),
  ];

  @override
  void dispose() {
    _documentoController.dispose();
    _razaoSocialController.dispose();
    _nomeFantasiaController.dispose();
    _inscricaoEstadualController.dispose();
    _inscricaoMunicipalController.dispose();
    _nomeContatoController.dispose();
    _telefoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _observacoesController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    _chavePixController.dispose();
    _bancoController.dispose();
    _agenciaController.dispose();
    _contaController.dispose();
    _favorecidoController.dispose();
    super.dispose();
  }

  void _preencherFormulario(Fornecedor f) {
    if (_dadosCarregados) return;
    _dadosCarregados = true;

    _tipoPessoa = f.tipoPessoa;
    _documentoController.text = f.documentoFormatado;
    _razaoSocialController.text = f.razaoSocial;
    _nomeFantasiaController.text = f.nomeFantasia ?? '';
    _inscricaoEstadualController.text = f.inscricaoEstadual ?? '';
    _inscricaoMunicipalController.text = f.inscricaoMunicipal ?? '';
    _nomeContatoController.text = f.nomeContato ?? '';
    _telefoneController.text = FornecedorValidator.formatarTelefone(f.telefone);
    _whatsappController.text = FornecedorValidator.formatarTelefone(f.whatsapp);
    _emailController.text = f.email ?? '';
    _observacoesController.text = f.observacoes ?? '';

    if (f.endereco != null) {
      _cepController.text = FornecedorValidator.formatarCep(f.endereco!.cep);
      _logradouroController.text = f.endereco!.logradouro ?? '';
      _numeroController.text = f.endereco!.numero ?? '';
      _complementoController.text = f.endereco!.complemento ?? '';
      _bairroController.text = f.endereco!.bairro ?? '';
      _cidadeController.text = f.endereco!.cidade ?? '';
      _ufController.text = f.endereco!.uf ?? '';
    }

    if (f.dadosBancarios != null) {
      _chavePixController.text = f.dadosBancarios!.chavePix ?? '';
      _tipoChavePix = f.dadosBancarios!.tipoChavePix ?? 'cnpj';
      _bancoController.text = f.dadosBancarios!.banco ?? '';
      _agenciaController.text = f.dadosBancarios!.agencia ?? '';
      _contaController.text = f.dadosBancarios!.contaCorrente ?? '';
      _favorecidoController.text = f.dadosBancarios!.favorecido ?? '';
    }

    _categoriasSelecionadas.addAll(f.categorias);
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            'Por favor, corrija os erros no formulário antes de salvar.',
          ),
        ),
      );
      return;
    }

    final docSanitizado = FornecedorValidator.apenasDigitos(
      _documentoController.text,
    );
    final isValido = FornecedorValidator.validarDocumento(
      docSanitizado,
      isPessoaJuridica: _tipoPessoa == TipoPessoa.juridica,
    );

    if (!isValido) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            '${_tipoPessoa == TipoPessoa.juridica ? "CNPJ" : "CPF"} inválido de acordo com a Receita Federal.',
          ),
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final fornecedorId = widget.fornecedorId ?? const Uuid().v4();

      final endereco = EnderecoFornecedor(
        cep: FornecedorValidator.apenasDigitos(_cepController.text),
        logradouro: _logradouroController.text.trim(),
        numero: _numeroController.text.trim(),
        complemento: _complementoController.text.trim(),
        bairro: _bairroController.text.trim(),
        cidade: _cidadeController.text.trim(),
        uf: _ufController.text.trim().toUpperCase(),
      );

      final dadosBancarios = DadosBancariosFornecedor(
        chavePix: _chavePixController.text.trim(),
        tipoChavePix: _tipoChavePix,
        banco: _bancoController.text.trim(),
        agencia: _agenciaController.text.trim(),
        contaCorrente: _contaController.text.trim(),
        favorecido: _favorecidoController.text.trim().isNotEmpty
            ? _favorecidoController.text.trim()
            : _razaoSocialController.text.trim(),
      );

      final fornecedor = Fornecedor(
        id: fornecedorId,
        construtoraId: widget.construtoraId,
        tipoPessoa: _tipoPessoa,
        documento: docSanitizado,
        razaoSocial: _razaoSocialController.text.trim(),
        nomeFantasia: _nomeFantasiaController.text.trim().isNotEmpty
            ? _nomeFantasiaController.text.trim()
            : null,
        inscricaoEstadual: _inscricaoEstadualController.text.trim().isNotEmpty
            ? _inscricaoEstadualController.text.trim()
            : null,
        inscricaoMunicipal: _inscricaoMunicipalController.text.trim().isNotEmpty
            ? _inscricaoMunicipalController.text.trim()
            : null,
        nomeContato: _nomeContatoController.text.trim().isNotEmpty
            ? _nomeContatoController.text.trim()
            : null,
        telefone: FornecedorValidator.apenasDigitos(_telefoneController.text),
        whatsapp: FornecedorValidator.apenasDigitos(_whatsappController.text),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim().toLowerCase()
            : null,
        endereco: endereco,
        categorias: _categoriasSelecionadas.toList(),
        dadosBancarios: dadosBancarios,
        observacoes: _observacoesController.text.trim().isNotEmpty
            ? _observacoesController.text.trim()
            : null,
        status: StatusFornecedor.ativo,
      );

      final sucesso = await ref
          .read(fornecedoresControllerProvider.notifier)
          .salvarFornecedor(fornecedor);

      if (sucesso && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              widget.fornecedorId != null
                  ? 'Fornecedor atualizado com sucesso!'
                  : 'Fornecedor cadastrado com sucesso!',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erro ao salvar fornecedor: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.fornecedorId != null;

    if (isEdicao && !_dadosCarregados) {
      final fornecedorAsync = ref.watch(
        fornecedorDetailsFutureProvider((
          construtoraId: widget.construtoraId,
          fornecedorId: widget.fornecedorId!,
        )),
      );

      return fornecedorAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) =>
            Scaffold(body: Center(child: Text('Erro ao carregar dados: $err'))),
        data: (f) {
          if (f != null) _preencherFormulario(f);
          return _buildScaffold(context, isEdicao);
        },
      );
    }

    return _buildScaffold(context, isEdicao);
  }

  Widget _buildScaffold(BuildContext context, bool isEdicao) {
    final isPJ = _tipoPessoa == TipoPessoa.juridica;

    return SigoLayout(
      title: isEdicao ? 'Editar Fornecedor' : 'Novo Fornecedor',
      activeRoute: '/construtoras/${widget.construtoraId}/fornecedores',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho e Tipo de Pessoa
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Identificação Fiscal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<TipoPessoa>(
                        segments: const [
                          ButtonSegment(
                            value: TipoPessoa.juridica,
                            label: Text('Pessoa Jurídica (CNPJ)'),
                            icon: Icon(Icons.business),
                          ),
                          ButtonSegment(
                            value: TipoPessoa.fisica,
                            label: Text('Pessoa Física (CPF)'),
                            icon: Icon(Icons.person_outline),
                          ),
                        ],
                        selected: {_tipoPessoa},
                        onSelectionChanged: isEdicao
                            ? null
                            : (set) {
                                setState(() {
                                  _tipoPessoa = set.first;
                                  _tipoChavePix =
                                      _tipoPessoa == TipoPessoa.juridica
                                      ? 'cnpj'
                                      : 'cpf';
                                  _documentoController.clear();
                                });
                              },
                      ),
                      const SizedBox(height: 16),

                      // Campo de Documento (CNPJ / CPF)
                      TextFormField(
                        controller: _documentoController,
                        decoration: InputDecoration(
                          labelText: isPJ ? 'CNPJ *' : 'CPF *',
                          hintText: isPJ
                              ? '00.000.000/0000-00'
                              : '000.000.000-00',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.badge_outlined),
                          suffixIcon: _buildDocValidationIcon(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          // Aplica formatação automática em tempo real
                          final sanitizado = FornecedorValidator.apenasDigitos(
                            val,
                          );
                          final formatado =
                              FornecedorValidator.formatarDocumento(sanitizado);
                          if (formatado != val) {
                            _documentoController.value = TextEditingValue(
                              text: formatado,
                              selection: TextSelection.collapsed(
                                offset: formatado.length,
                              ),
                            );
                          }
                          setState(() {});
                        },
                        validator: (val) {
                          final sanitizado = FornecedorValidator.apenasDigitos(
                            val,
                          );
                          if (sanitizado.isEmpty) {
                            return 'Informe o ${isPJ ? "CNPJ" : "CPF"}';
                          }
                          final valido = FornecedorValidator.validarDocumento(
                            sanitizado,
                            isPessoaJuridica: isPJ,
                          );
                          if (!valido) {
                            return '${isPJ ? "CNPJ" : "CPF"} inválido pelo cálculo oficial.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Dados Cadastrais Principais
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dados da Empresa / Fornecedor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Razão Social
                      TextFormField(
                        controller: _razaoSocialController,
                        decoration: InputDecoration(
                          labelText: isPJ
                              ? 'Razão Social *'
                              : 'Nome Completo *',
                          hintText: isPJ
                              ? 'Ex: Votorantim Cimentos S/A'
                              : 'Ex: José da Silva Pintor',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 3) {
                            return 'Informe pelo menos 3 caracteres.';
                          }
                          return null;
                        },
                      ),

                      if (isPJ) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nomeFantasiaController,
                          decoration: const InputDecoration(
                            labelText: 'Nome Fantasia',
                            hintText: 'Ex: Votorantim',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _inscricaoEstadualController,
                                decoration: const InputDecoration(
                                  labelText: 'Inscrição Estadual (IE)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _inscricaoMunicipalController,
                                decoration: const InputDecoration(
                                  labelText: 'Inscrição Municipal (IM)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Contatos
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contatos e Atendimento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nomeContatoController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Contato / Vendedor',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _telefoneController,
                              decoration: const InputDecoration(
                                labelText: 'Telefone Fixo',
                                hintText: '(00) 0000-0000',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                              onChanged: (v) {
                                final f = FornecedorValidator.formatarTelefone(
                                  v,
                                );
                                if (f != v) {
                                  _telefoneController.value = TextEditingValue(
                                    text: f,
                                    selection: TextSelection.collapsed(
                                      offset: f.length,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _whatsappController,
                              decoration: const InputDecoration(
                                labelText: 'WhatsApp / Celular',
                                hintText: '(00) 00000-0000',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.chat_bubble_outline),
                              ),
                              keyboardType: TextInputType.phone,
                              onChanged: (v) {
                                final f = FornecedorValidator.formatarTelefone(
                                  v,
                                );
                                if (f != v) {
                                  _whatsappController.value = TextEditingValue(
                                    text: f,
                                    selection: TextSelection.collapsed(
                                      offset: f.length,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail Comercial',
                          hintText: 'contato@empresa.com.br',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Categorias de Fornecimento
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Categorias de Fornecimento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Selecione as categorias de produtos e serviços atendidas por este fornecedor:',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _todasCategorias.map((c) {
                          final selecionada = _categoriasSelecionadas.contains(
                            c.key,
                          );
                          return FilterChip(
                            label: Text(c.label),
                            selected: selecionada,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _categoriasSelecionadas.add(c.key);
                                } else {
                                  _categoriasSelecionadas.remove(c.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Endereço (Expansível)
              ExpansionTile(
                title: const Text(
                  'Endereço da Empresa (Opcional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                leading: const Icon(Icons.location_on_outlined),
                initiallyExpanded: false,
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _cepController,
                          decoration: const InputDecoration(
                            labelText: 'CEP',
                            hintText: '00000-000',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final f = FornecedorValidator.formatarCep(v);
                            if (f != v) {
                              _cepController.value = TextEditingValue(
                                text: f,
                                selection: TextSelection.collapsed(
                                  offset: f.length,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _logradouroController,
                          decoration: const InputDecoration(
                            labelText: 'Logradouro / Rua',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _numeroController,
                          decoration: const InputDecoration(
                            labelText: 'Número',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: _complementoController,
                          decoration: const InputDecoration(
                            labelText: 'Complemento / Galpão',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _bairroController,
                          decoration: const InputDecoration(
                            labelText: 'Bairro',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _cidadeController,
                          decoration: const InputDecoration(
                            labelText: 'Cidade',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _ufController,
                          decoration: const InputDecoration(
                            labelText: 'UF',
                            hintText: 'SP',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Dados Bancários / Pix (Expansível)
              ExpansionTile(
                title: const Text(
                  'Dados para Pagamento / Pix (Opcional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                leading: const Icon(Icons.account_balance_outlined),
                initiallyExpanded: true,
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _chavePixController,
                          decoration: const InputDecoration(
                            labelText: 'Chave Pix',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pix),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _tipoChavePix,
                          decoration: const InputDecoration(
                            labelText: 'Tipo Chave',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'cnpj',
                              child: Text('CNPJ'),
                            ),
                            DropdownMenuItem(value: 'cpf', child: Text('CPF')),
                            DropdownMenuItem(
                              value: 'email',
                              child: Text('E-mail'),
                            ),
                            DropdownMenuItem(
                              value: 'telefone',
                              child: Text('Telefone'),
                            ),
                            DropdownMenuItem(
                              value: 'aleatoria',
                              child: Text('Aleatória'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              setState(() => _tipoChavePix = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _bancoController,
                          decoration: const InputDecoration(
                            labelText: 'Banco',
                            hintText: 'Ex: Itaú, Bradesco, BB',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _agenciaController,
                          decoration: const InputDecoration(
                            labelText: 'Agência',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _contaController,
                          decoration: const InputDecoration(
                            labelText: 'Conta Corrente',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _favorecidoController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Favorecido',
                      hintText: 'Nome do titular da conta bancária',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Observações
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Observações e Condições Comerciais',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _observacoesController,
                        decoration: const InputDecoration(
                          hintText: 'Condições de frete, prazos médios de entrega, políticas de desconto...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botões de Ação
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando ? null : () => context.pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    onPressed: _salvando ? null : _submeter,
                    icon: _salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _salvando
                          ? 'Salvando...'
                          : (isEdicao
                                ? 'Atualizar Fornecedor'
                                : 'Cadastrar Fornecedor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildDocValidationIcon() {
    final digitos = FornecedorValidator.apenasDigitos(
      _documentoController.text,
    );
    final esperado = _tipoPessoa == TipoPessoa.juridica ? 14 : 11;

    if (digitos.length < esperado) return null;

    final valido = FornecedorValidator.validarDocumento(
      digitos,
      isPessoaJuridica: _tipoPessoa == TipoPessoa.juridica,
    );

    if (valido) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else {
      return const Icon(Icons.error, color: Colors.red);
    }
  }
}

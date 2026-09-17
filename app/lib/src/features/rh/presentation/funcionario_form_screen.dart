import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../common_widgets/sigo_top_bar.dart';
import '../../../core/contracts.dart';
import '../data/rh_repository.dart';
import '../domain/funcionario.dart';

class FuncionarioFormScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final Funcionario? initialFuncionario;

  const FuncionarioFormScreen({
    super.key,
    required this.construtoraId,
    this.initialFuncionario,
  });

  @override
  ConsumerState<FuncionarioFormScreen> createState() =>
      _FuncionarioFormScreenState();
}

class _FuncionarioFormScreenState extends ConsumerState<FuncionarioFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _cpfController;
  late final TextEditingController _roleController;
  late final TextEditingController _baseSalaryController;
  late final TextEditingController _additionalCostsController;

  late String _employmentType;
  late String _salaryBasis;
  String? _teamId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFuncionario;
    _nameController = TextEditingController(text: f?.name ?? '');
    _cpfController = TextEditingController(text: f?.formattedCpf ?? '');
    _roleController = TextEditingController(text: f?.role ?? '');

    _baseSalaryController = TextEditingController(
      text: f != null ? (f.baseSalaryCents / 100.0).toStringAsFixed(2) : '',
    );
    _additionalCostsController = TextEditingController(
      text: f != null && f.additionalCostsCents > 0
          ? (f.additionalCostsCents / 100.0).toStringAsFixed(2)
          : '0.00',
    );

    _employmentType = f?.employmentType ?? 'clt';
    _salaryBasis = f?.salaryBasis ?? 'mensal';
    _teamId = f?.teamId;

    _baseSalaryController.addListener(() => setState(() {}));
    _additionalCostsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _roleController.dispose();
    _baseSalaryController.dispose();
    _additionalCostsController.dispose();
    super.dispose();
  }

  int _parseCents(String text) {
    if (text.trim().isEmpty) return 0;
    try {
      return parseCurrencyToCents(text);
    } catch (_) {
      return 0;
    }
  }

  int get _currentDailyRateCents {
    final base = _parseCents(_baseSalaryController.text);
    final add = _parseCents(_additionalCostsController.text);
    return Funcionario.calculateDailyRate(
      salaryBasis: _salaryBasis,
      baseSalaryCents: base,
      additionalCostsCents: add,
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final cpfText = _cpfController.text.trim();
    if (!Funcionario.isValidCpf(cpfText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CPF inválido. Verifique os números digitados.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final baseCents = _parseCents(_baseSalaryController.text);
    if (baseCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O salário base ou diária deve ser maior que zero.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final addCents = _parseCents(_additionalCostsController.text);

    setState(() => _isSaving = true);
    try {
      final isEditing = widget.initialFuncionario != null;
      final id = widget.initialFuncionario?.id ?? const Uuid().v4();

      final funcionario = Funcionario(
        id: id,
        construtoraId: widget.construtoraId,
        name: _nameController.text.trim(),
        cpf: cpfText.replaceAll(RegExp(r'\D'), ''),
        role: _roleController.text.trim(),
        teamId: _teamId,
        employmentType: _employmentType,
        salaryBasis: _salaryBasis,
        baseSalaryCents: baseCents,
        additionalCostsCents: addCents,
        isActive: widget.initialFuncionario?.isActive ?? true,
        schemaVersion: 1,
        createdAt: widget.initialFuncionario?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEditing) {
        await ref.read(rhRepositoryProvider).updateFuncionario(funcionario);
      } else {
        await ref.read(rhRepositoryProvider).createFuncionario(funcionario);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Colaborador atualizado com sucesso!'
                  : 'Colaborador cadastrado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar colaborador: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialFuncionario != null;
    final equipesAsync = ref.watch(equipesStreamProvider(widget.construtoraId));
    final dailyRateCents = _currentDailyRateCents;

    return Scaffold(
      appBar: SigoTopBar(
        title: isEditing ? 'Editar Colaborador' : 'Novo Colaborador',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Identificação do Profissional',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('funcionario_name_input'),
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nome Completo *',
                              hintText: 'Ex: João da Silva',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Nome é obrigatório';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  key: const Key('funcionario_cpf_input'),
                                  controller: _cpfController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'CPF *',
                                    hintText: '000.000.000-00',
                                    prefixIcon: Icon(Icons.badge),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'CPF é obrigatório';
                                    }
                                    if (!Funcionario.isValidCpf(val)) {
                                      return 'CPF inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  key: const Key('funcionario_role_input'),
                                  controller: _roleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Cargo / Função *',
                                    hintText: 'Ex: Pedreiro, Eletricista',
                                    prefixIcon: Icon(Icons.work),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Cargo é obrigatório';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          equipesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const SizedBox.shrink(),
                            data: (equipes) {
                              final activeEquipes =
                                  equipes.where((e) => e.isActive).toList();
                              return DropdownButtonFormField<String?>(
                                key: const Key('funcionario_team_select'),
                                isExpanded: true,
                                initialValue: _teamId,
                                decoration: const InputDecoration(
                                  labelText: 'Equipe de Trabalho (Opcional)',
                                  prefixIcon: Icon(Icons.groups),
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Sem equipe vinculada'),
                                  ),
                                  ...activeEquipes.map(
                                    (e) => DropdownMenuItem<String?>(
                                      value: e.id,
                                      child: Text(e.name),
                                    ),
                                  ),
                                ],
                                onChanged: (val) => setState(() => _teamId = val),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Regime Contratual & Remuneração',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: const Key('funcionario_employment_select'),
                                  isExpanded: true,
                                  initialValue: _employmentType,
                                  decoration: const InputDecoration(
                                    labelText: 'Regime de Contratação',
                                    prefixIcon: Icon(Icons.description),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'clt',
                                      child: Text('CLT (Carteira Assinada)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pj',
                                      child: Text('PJ (Pessoa Jurídica)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'avulso',
                                      child: Text('Diarista / Avulso'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _employmentType = val;
                                        if (val == 'avulso') {
                                          _salaryBasis = 'diaria';
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: const Key('funcionario_basis_select'),
                                  isExpanded: true,
                                  initialValue: _salaryBasis,
                                  decoration: const InputDecoration(
                                    labelText: 'Base Salarial',
                                    prefixIcon: Icon(Icons.schedule),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'mensal',
                                      child: Text('Salário Mensal'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'diaria',
                                      child: Text('Diária'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _salaryBasis = val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: const Key('funcionario_salary_input'),
                                  controller: _baseSalaryController,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: _salaryBasis == 'diaria'
                                        ? 'Valor da Diária (R\$) *'
                                        : 'Salário Base Mensal (R\$) *',
                                    hintText: '0.00',
                                    prefixText: 'R\$ ',
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Informe o valor';
                                    }
                                    if (_parseCents(val) <= 0) {
                                      return 'Valor deve ser positivo';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  key: const Key('funcionario_additional_input'),
                                  controller: _additionalCostsController,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Encargos / Benefícios (R\$)',
                                    hintText: '0.00',
                                    prefixText: 'R\$ ',
                                    border: OutlineInputBorder(),
                                    helperText: 'Mensal ou por diária',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.indigo.shade100,
                                  child: const Icon(
                                    Icons.calculate,
                                    color: Colors.indigo,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Taxa Diária para Apropriação em Lotes:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${formatCents(dailyRateCents)} / dia',
                                        key: const Key('daily_rate_preview_text'),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      Text(
                                        _salaryBasis == 'mensal'
                                            ? '(Cálculo: [Salário + Encargos] ÷ 30 dias corridos)'
                                            : '(Cálculo: [Diária + Encargos Adicionais])',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.indigo.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSaving ? null : () => context.pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        key: const Key('btn_save_funcionario'),
                        onPressed: _isSaving ? null : _handleSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isSaving
                              ? 'Salvando...'
                              : (isEditing ? 'Salvar Alterações' : 'Cadastrar'),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/epi_repository.dart';
import '../domain/epi_item.dart';

class EpiFormDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  final EpiItem? initialItem;

  const EpiFormDialog({
    super.key,
    required this.construtoraId,
    this.initialItem,
  });

  @override
  ConsumerState<EpiFormDialog> createState() => _EpiFormDialogState();
}

class _EpiFormDialogState extends ConsumerState<EpiFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _fabricanteController;
  late final TextEditingController _caNumeroController;
  late final TextEditingController _vidaUtilController;
  late final TextEditingController _descricaoController;

  late String _categoria;
  late String _unidade;
  late DateTime _caValidade;
  bool _isLoading = false;

  final List<Map<String, String>> _categorias = [
    {'value': 'cabeca', 'label': 'Proteção da Cabeça (Capacetes, Carneiras)'},
    {'value': 'ocular', 'label': 'Proteção dos Olhos/Face (Óculos, Viseiras)'},
    {
      'value': 'auditiva',
      'label': 'Proteção Auditiva (Protetores, Abafadores)',
    },
    {
      'value': 'respiratoria',
      'label': 'Proteção Respiratória (Máscaras, Respiradores)',
    },
    {'value': 'maos_bracos', 'label': 'Membros Superiores (Luvas, Mangotes)'},
    {'value': 'pes_pernas', 'label': 'Membros Inferiores (Botinas, Perneiras)'},
    {'value': 'altura', 'label': 'Proteção contra Quedas (Cintos, Talabartes)'},
    {'value': 'outros', 'label': 'Outros Equipamentos'},
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nomeController = TextEditingController(text: item?.nome ?? '');
    _fabricanteController = TextEditingController(text: item?.fabricante ?? '');
    _caNumeroController = TextEditingController(text: item?.caNumero ?? '');
    _vidaUtilController = TextEditingController(
      text: item != null ? item.vidaUtilDias.toString() : '180',
    );
    _descricaoController = TextEditingController(text: item?.descricao ?? '');

    _categoria = item?.categoria ?? 'cabeca';
    _unidade = item?.unidade ?? 'un';
    _caValidade =
        item?.caValidade ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _fabricanteController.dispose();
    _caNumeroController.dispose();
    _vidaUtilController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  bool get _isCaVencido {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _caValidade.isBefore(today);
  }

  Future<void> _selecionarDataValidade() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _caValidade,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      helpText: 'Data de Validade do C.A.',
    );
    if (picked != null) {
      setState(() => _caValidade = picked);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(epiRepositoryProvider);
      final id = widget.initialItem?.id ?? const Uuid().v4();
      final item = EpiItem(
        id: id,
        construtoraId: widget.construtoraId,
        nome: _nomeController.text.trim(),
        fabricante: _fabricanteController.text.trim(),
        categoria: _categoria,
        caNumero: _caNumeroController.text.trim(),
        caValidade: _caValidade,
        vidaUtilDias: int.tryParse(_vidaUtilController.text.trim()) ?? 180,
        unidade: _unidade,
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        isActive: widget.initialItem?.isActive ?? true,
      );

      await repo.saveEpiItem(item);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar EPI: $e'),
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
    final isEditing = widget.initialItem != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar EPI' : 'Novo EPI no Catálogo'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do EPI *',
                    hintText: 'Ex: Capacete de Segurança Aba Frontal',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nome é obrigatório'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _fabricanteController,
                        decoration: const InputDecoration(
                          labelText: 'Fabricante *',
                          hintText: 'Ex: MSA, 3M, Danny',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Fabricante é obrigatório'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _unidade,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                        items: const [
                          DropdownMenuItem(
                            value: 'un',
                            child: Text('Unidade (un)'),
                          ),
                          DropdownMenuItem(
                            value: 'par',
                            child: Text('Par (par)'),
                          ),
                          DropdownMenuItem(
                            value: 'kit',
                            child: Text('Kit (kit)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _unidade = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(
                    labelText: 'Categoria de Proteção *',
                  ),
                  items: _categorias
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat['value'],
                          child: Text(cat['label']!),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _categoria = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _caNumeroController,
                        decoration: const InputDecoration(
                          labelText: 'Número do C.A. *',
                          hintText: 'Ex: 12345',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Número de C.A. obrigatório'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _selecionarDataValidade,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Validade C.A. *',
                            suffixIcon: Icon(Icons.calendar_today, size: 20),
                          ),
                          child: Text(
                            '${_caValidade.day.toString().padLeft(2, '0')}/${_caValidade.month.toString().padLeft(2, '0')}/${_caValidade.year}',
                            style: TextStyle(
                              color: _isCaVencido ? Colors.red : null,
                              fontWeight: _isCaVencido ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isCaVencido)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.amber.shade900,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Atenção: Este C.A. está expirado! Itens com C.A. vencido exigirão autorização especial na entrega.',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vidaUtilController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Vida Útil Estimada (dias)',
                    hintText: 'Ex: 180',
                    helperText:
                        'Periodicidade sugerida para substituição preventiva',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Informe dias válidos';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descricaoController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição / Observações',
                    hintText:
                        'Instruções de conservação, detalhes técnicos, etc.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _salvar,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Salvar Alterações' : 'Cadastrar EPI'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../data/financeiro_repository.dart';
import '../domain/despesa.dart';
import '../../obras/presentation/construtora_obras_provider.dart'; 

class AddDespesaScreen extends ConsumerStatefulWidget {
  final String construtoraId;

  const AddDespesaScreen({super.key, required this.construtoraId});

  @override
  ConsumerState<AddDespesaScreen> createState() => _AddDespesaScreenState();
}

class _AddDespesaScreenState extends ConsumerState<AddDespesaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _categoriaController = TextEditingController(text: 'Material');
  DateTime _vencimento = DateTime.now();
  String? _selectedObraId;
  bool _isLoading = false;

  final List<String> _categoriasPadrao = ['Material', 'Mão de Obra', 'Equipamento', 'Imposto', 'Administrativo', 'Outros'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final valorText = _valorController.text.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
      final valor = double.tryParse(valorText) ?? 0.0;

      final despesa = Despesa(
        id: const Uuid().v4(),
        construtoraId: widget.construtoraId,
        obraId: _selectedObraId,
        descricao: _descricaoController.text,
        valor: valor,
        dataVencimento: _vencimento,
        status: StatusDespesa.pendente,
        categoria: _categoriaController.text,
        responsavelId: uid,
        createdAt: DateTime.now(),
      );

      await ref.read(financeiroRepositoryProvider).createDespesa(despesa);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Busca a lista de obras da construtora para preencher o dropdown
    final obrasAsync = ref.watch(construtoraObrasProvider(widget.construtoraId));

    return SigoLayout(
      title: 'Nova Despesa',
      activeRoute: '/construtoras/${widget.construtoraId}/financeiro',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _descricaoController,
                    decoration: const InputDecoration(labelText: 'Descrição da Despesa (Ex: Compra de Cimento)'),
                    validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _valorController,
                    decoration: const InputDecoration(labelText: 'Valor (R\$)', prefixText: 'R\$ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('Vencimento: ${_vencimento.day.toString().padLeft(2, '0')}/${_vencimento.month.toString().padLeft(2, '0')}/${_vencimento.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _vencimento,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _vencimento = d);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _categoriaController.text,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: _categoriasPadrao.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _categoriaController.text = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  obrasAsync.when(
                    data: (obras) {
                      return DropdownButtonFormField<String?>(
                        initialValue: _selectedObraId,
                        decoration: const InputDecoration(labelText: 'Loteamento (Opcional - Custo Global se Vazio)'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Nenhuma (Custo Administrativo)')),
                          ...obras.map((o) => DropdownMenuItem(value: o.id, child: Text(o.name))),
                        ],
                        onChanged: (val) => setState(() => _selectedObraId = val),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Text('Erro ao carregar loteamentos: $e'),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Salvar Despesa', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
    );
  }
}

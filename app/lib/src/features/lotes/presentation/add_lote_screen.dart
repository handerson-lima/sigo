import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../data/lote_repository.dart';
import '../domain/lote.dart';

class AddLoteScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;

  const AddLoteScreen({super.key, required this.construtoraId, required this.loteamentoId, required this.quadraId});

  @override
  ConsumerState<AddLoteScreen> createState() => _AddLoteScreenState();
}

class _AddLoteScreenState extends ConsumerState<AddLoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedPhase = defaultLotePhases.first;
  LoteStatus _selectedStatus = LoteStatus.noPrazo;
  bool _isLoading = false;
  late final String _loteId;

  @override
  void initState() {
    super.initState();
    _loteId = const Uuid().v4();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final lote = Lote(
        id: _loteId,
        construtoraId: widget.construtoraId,
        loteamentoId: widget.loteamentoId,
        quadraId: widget.quadraId,
        name: _nameController.text.trim(),
        phase: _selectedPhase,
        status: _selectedStatus,
        createdAt: DateTime.now(),
      );

      await ref.read(loteRepositoryProvider).createLote(lote).timeout(const Duration(seconds: 15));
      if (mounted) {
        context.pop();
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('O envio está demorando muito. O estado é incerto, mas seus dados não foram perdidos.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SigoLayout(
      title: 'Novo Lote',
      activeRoute: '/construtora/${widget.construtoraId}/loteamentos/${widget.loteamentoId}/quadras/${widget.quadraId}/lotes',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nome/Identificação do Lote (Ex: Casa 1)'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPhase,
                  decoration: const InputDecoration(labelText: 'Fase Inicial'),
                  items: defaultLotePhases.map((phase) {
                    return DropdownMenuItem(value: phase, child: Text(phase));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPhase = val);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LoteStatus>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status Inicial'),
                  items: const [
                    DropdownMenuItem(value: LoteStatus.noPrazo, child: Text('No Prazo')),
                    DropdownMenuItem(value: LoteStatus.atrasado, child: Text('Atrasado')),
                    DropdownMenuItem(value: LoteStatus.paralisado, child: Text('Paralisado')),
                    DropdownMenuItem(value: LoteStatus.concluido, child: Text('Concluído')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading ? const CircularProgressIndicator() : const Text('Criar Lote'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

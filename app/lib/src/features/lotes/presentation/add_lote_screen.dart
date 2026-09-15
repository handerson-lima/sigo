import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../data/lote_repository.dart';
import '../domain/lote.dart';

class AddLoteScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;

  const AddLoteScreen({super.key, required this.construtoraId, required this.obraId});

  @override
  ConsumerState<AddLoteScreen> createState() => _AddLoteScreenState();
}

class _AddLoteScreenState extends ConsumerState<AddLoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedPhase = defaultLotePhases.first;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final lote = Lote(
        id: const Uuid().v4(),
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        name: _nameController.text.trim(),
        phase: _selectedPhase,
        createdAt: DateTime.now(),
      );

      await ref.read(loteRepositoryProvider).createLote(lote);
      if (mounted) {
        context.pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Lote')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome/Identificação do Lote (Ex: Casa 1)'),
                validator: (val) => val == null || val.isEmpty ? 'Campo obrigatório' : null,
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
    );
  }
}

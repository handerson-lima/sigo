import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../data/almoxarifado_repository.dart';
import '../domain/material.dart' as mat;

class AddMaterialScreen extends ConsumerStatefulWidget {
  final String construtoraId;

  const AddMaterialScreen({super.key, required this.construtoraId});

  @override
  ConsumerState<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends ConsumerState<AddMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final material = mat.Material(
        id: const Uuid().v4(),
        construtoraId: widget.construtoraId,
        name: _nameController.text.trim(),
        unit: _unitController.text.trim(),
        currentQuantity: 0.0,
        quantityUnits: 0,
        quantityScale: 1000,
        schemaVersion: 2,
      );

      await ref.read(almoxarifadoRepositoryProvider).createMaterial(material);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material cadastrado com sucesso!')),
        );
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
    return SigoLayout(
      title: 'Novo Material no Catálogo',
      activeRoute: '/construtora/${widget.construtoraId}/almoxarifado',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome do Material (Ex: Cimento CP II)'),
                validator: (val) => val == null || val.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Unidade (Ex: Saco 50kg, M3, Unidade)'),
                validator: (val) => val == null || val.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Cadastrar'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

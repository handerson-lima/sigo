import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../construtoras/domain/construtora.dart';

class DevConstrutorasListScreen extends StatelessWidget {
  const DevConstrutorasListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SigoLayout(
      activeRoute: '/dev',
      title: 'Gestão Global de Construtoras',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Construtoras Cadastradas',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const _AddConstrutoraDialog(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Construtora'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('construtoras').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma construtora encontrada no banco de dados.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                      data['id'] = (data['id'] as String?)?.isNotEmpty == true ? data['id'] : doc.id;
                      data['name'] = (data['name'] as String?)?.isNotEmpty == true ? data['name'] : doc.id;
                      
                      if (data['createdAt'] is Timestamp) {
                        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
                      }
                      if (data['updatedAt'] is Timestamp) {
                        data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
                      }
                      
                      final construtora = Construtora.fromJson(data);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: const Icon(Icons.business, color: Colors.orange),
                          ),
                          title: Text(
                            construtora.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('ID: ${construtora.id} | CNPJ: ${construtora.cnpj ?? 'N/A'}'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddConstrutoraDialog extends StatefulWidget {
  const _AddConstrutoraDialog();

  @override
  State<_AddConstrutoraDialog> createState() => _AddConstrutoraDialogState();
}

class _AddConstrutoraDialogState extends State<_AddConstrutoraDialog> {
  final _nameController = TextEditingController();
  final _cnpjController = TextEditingController();
  bool _isSaving = false;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('construtoras').doc();
      final data = {
        'id': docRef.id,
        'name': name,
        'cnpj': _cnpjController.text.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Construtora'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome da Construtora'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cnpjController,
              decoration: const InputDecoration(labelText: 'CNPJ (opcional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

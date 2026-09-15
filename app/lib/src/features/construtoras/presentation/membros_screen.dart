import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_membro_dialog.dart';
import '../data/membros_repository.dart';
import '../domain/membro.dart';

final membrosProvider = StreamProvider.autoDispose.family<List<Membro>, String>((ref, construtoraId) {
  final repo = ref.watch(membrosRepositoryProvider);
  return repo.watchMembros(construtoraId);
});

class MembrosScreen extends ConsumerWidget {
  final String construtoraId;

  const MembrosScreen({super.key, required this.construtoraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membrosAsync = ref.watch(membrosProvider(construtoraId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Membros'),
      ),
      body: membrosAsync.when(
        data: (membros) {
          if (membros.isEmpty) {
            return const Center(child: Text('Nenhum membro encontrado.'));
          }
          return ListView.builder(
            itemCount: membros.length,
            itemBuilder: (context, index) {
              final membro = membros[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(membro.isAdmin ? Icons.admin_panel_settings : Icons.person),
                ),
                title: Text(membro.email.isNotEmpty ? membro.email : 'UID: ${membro.uid}'),
                subtitle: Text(membro.isAdmin ? 'Administrador' : 'Operário'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddMembroDialog(construtoraId: construtoraId),
          );
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

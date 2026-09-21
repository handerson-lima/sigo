import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common_widgets/sigo_layout.dart';
import 'add_membro_dialog.dart';
import '../data/membros_repository.dart';
import '../domain/membro.dart';

final membrosProvider = StreamProvider.autoDispose.family<List<Membro>, String>((ref, construtoraId) {
  final repo = ref.watch(membrosRepositoryProvider);
  return repo.watchMembros(construtoraId);
});

final pendingRequestsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, construtoraId) {
  final repo = ref.watch(membrosRepositoryProvider);
  return repo.watchPendingRequests(construtoraId);
});

class MembrosScreen extends ConsumerWidget {
  final String construtoraId;

  const MembrosScreen({super.key, required this.construtoraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membrosAsync = ref.watch(membrosProvider(construtoraId));
    final pendingAsync = ref.watch(pendingRequestsProvider(construtoraId));

    return SigoLayout(
      title: 'Gestão de Membros',
      activeRoute: '/construtora/$construtoraId/membros',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add),
          tooltip: 'Convidar Membro',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AddMembroDialog(construtoraId: construtoraId),
            );
          },
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddMembroDialog(construtoraId: construtoraId),
          );
        },
        child: const Icon(Icons.person_add),
      ),
      child: membrosAsync.when(
        data: (membros) {
          final List<Map<String, dynamic>> pending = pendingAsync.value ?? [];

          // Combinamos: pending no topo + membros ativos abaixo
          final totalCount = pending.length + membros.length;

          if (totalCount == 0) {
            return const Center(child: Text('Nenhum membro encontrado.'));
          }

          return ListView.builder(
            itemCount: totalCount,
            itemBuilder: (context, index) {
              // Itens pendentes no topo
              if (index < pending.length) {
                final req = pending[index];
                final roleLabel = _roleLabel(req['role'] as String? ?? 'operario');
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade700),
                  ),
                  title: Text(req['displayName'] as String? ?? req['email'] as String? ?? ''),
                  subtitle: Text(req['email'] as String? ?? ''),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      '⏳ Pendente · $roleLabel',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }

              // Membros ativos
              final membro = membros[index - pending.length];
              final isOwner = membro.isOwner;
              final isAdmin = membro.isAdmin && !isOwner;
              final roleLabel = isOwner
                  ? 'Proprietário'
                  : (isAdmin ? 'Administrador' : 'Operário');

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOwner
                      ? Colors.amber.shade100
                      : (isAdmin ? Colors.blue.shade50 : null),
                  child: Icon(
                    isOwner
                        ? Icons.stars_rounded
                        : (isAdmin ? Icons.admin_panel_settings : Icons.person),
                    color: isOwner
                        ? Colors.amber.shade900
                        : (isAdmin ? Colors.blue.shade800 : null),
                  ),
                ),
                title: Text(membro.email.isNotEmpty ? membro.email : 'UID: ${membro.uid}'),
                subtitle: Text(roleLabel),
                trailing: isOwner
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Text(
                          'Proprietário',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'owner':
        return 'Proprietário';
      default:
        return 'Operário';
    }
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../authentication/domain/app_user.dart';

class UserDetailsScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailsScreen({super.key, required this.userId});

  @override
  ConsumerState<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends ConsumerState<UserDetailsScreen> {
  bool _isLoading = false;

  Future<void> _updateGlobalRole(bool isDev) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('setDevRole').call({
        'userId': widget.userId,
        'isActive': isDev,
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Papel atualizado!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SigoLayout(
      activeRoute: '/dev/users',
      title: 'Detalhes do Usuário',
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Usuário não encontrado.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp)
                .toDate()
                .toIso8601String();
          }
          if (data['updatedAt'] is Timestamp) {
            data['updatedAt'] = (data['updatedAt'] as Timestamp)
                .toDate()
                .toIso8601String();
          }
          final user = AppUser.fromJson(data);
          final isDev = user.globalRole == 'dev';

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Usuário: ${user.displayName}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Permissão Global',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Acesso de Desenvolvedor'),
                          subtitle: const Text(
                            'Concede acesso ao painel de desenvolvedor. Cuidado.',
                          ),
                          value: isDev,
                          onChanged: _isLoading
                              ? null
                              : (val) => _updateGlobalRole(val),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2. Vínculos a Construtoras',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Lista de Vínculos
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collectionGroup('construtora_members')
                              .where('userId', isEqualTo: widget.userId)
                              .snapshots(),
                          builder: (context, memberSnapshot) {
                            if (memberSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (memberSnapshot.hasError) {
                              return Text('Erro: ${memberSnapshot.error}');
                            }

                            final memberDocs = memberSnapshot.data?.docs ?? [];

                            if (memberDocs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16.0),
                                child: Text(
                                  'Usuário não está vinculado a nenhuma construtora.',
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: memberDocs.length,
                              itemBuilder: (context, index) {
                                final doc = memberDocs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final role = data['role'] ?? 'member';
                                final modules =
                                    (data['modules'] as List<dynamic>?)
                                        ?.cast<String>() ??
                                    [];
                                final cId = doc.reference.parent.parent!.id;

                                // Buscando o nome da construtora
                                return FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('construtoras')
                                      .doc(cId)
                                      .get(),
                                  builder: (context, cSnapshot) {
                                    final cName = cSnapshot.data?.exists == true
                                        ? (cSnapshot.data!.data()
                                              as Map)['name']
                                        : 'Construtora Desconhecida';

                                    final isOwner = role == 'owner' || data['isOwner'] == true;
                                    final isAdmin = !isOwner && role == 'admin';

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isOwner
                                            ? Colors.amber.shade100
                                            : (isAdmin
                                                ? Colors.red.shade100
                                                : Colors.green.shade100),
                                        child: Icon(
                                          isOwner
                                              ? Icons.stars_rounded
                                              : (isAdmin
                                                  ? Icons.admin_panel_settings
                                                  : Icons.person),
                                          color: isOwner
                                              ? Colors.amber.shade900
                                              : (isAdmin
                                                  ? Colors.red
                                                  : Colors.green),
                                        ),
                                      ),
                                      title: Text(cName ?? '...'),
                                      subtitle: Text(
                                        'Papel: ${isOwner ? 'Proprietário' : (isAdmin ? 'Administrador' : 'Membro comum')}\nMódulos: ${modules.isEmpty ? 'Nenhum' : modules.join(', ')}',
                                      ),
                                      isThreeLine: true,
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                    'Remover vínculo?',
                                                  ),
                                                  content: const Text(
                                                    'O usuário perderá acesso a esta construtora.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Cancelar',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Remover',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                          if (confirm == true) {
                                            await FirebaseFunctions.instance
                                                .httpsCallable('setMembership')
                                                .call({
                                                  'userId': widget.userId,
                                                  'construtoraId': cId,
                                                  'isActive': false,
                                                  'role': role == 'admin'
                                                      ? 'admin'
                                                      : 'member',
                                                  'modules': modules
                                                      .where(
                                                        (m) => [
                                                          'estoque',
                                                          'almoxarifado',
                                                        ].contains(m),
                                                      )
                                                      .toList(),
                                                });
                                          }
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) =>
                                  _LinkConstrutoraDialog(user: user),
                            );
                          },
                          icon: const Icon(Icons.add_link),
                          label: const Text('Adicionar Vínculo'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LinkConstrutoraDialog extends StatefulWidget {
  final AppUser user;
  const _LinkConstrutoraDialog({required this.user});

  @override
  State<_LinkConstrutoraDialog> createState() => _LinkConstrutoraDialogState();
}

class _LinkConstrutoraDialogState extends State<_LinkConstrutoraDialog> {
  String? _selectedCId;
  String _role = 'member';
  final Map<String, bool> _modules = {'estoque': false};
  bool _isSaving = false;

  Future<void> _save() async {
    if (_selectedCId == null) return;
    setState(() => _isSaving = true);

    try {
      final selectedModules = _modules.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await FirebaseFunctions.instance.httpsCallable('setMembership').call({
        'construtoraId': _selectedCId,
        'userId': widget.user.id,
        'role': _role,
        'isOwner': _role == 'owner',
        'modules': selectedModules,
        'isActive': true,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vincular à Construtora'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('construtoras')
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final docs = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Construtora'),
                    initialValue: _selectedCId,
                    items: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(data['name'] ?? 'Sem Nome'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCId = val),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Papel na Construtora:'),
              DropdownButtonFormField<String>(
                initialValue: _role,
                items: const [
                  DropdownMenuItem(
                    value: 'member',
                    child: Text('Membro comum'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Administrador'),
                  ),
                  DropdownMenuItem(
                    value: 'owner',
                    child: Text('Proprietário'),
                  ),
                ],
                onChanged: (value) => setState(() => _role = value!),
              ),
              if (_role == 'member') ...[
                const SizedBox(height: 16),
                const Text('Módulos Permitidos:'),
                ..._modules.keys.map((mod) {
                  return CheckboxListTile(
                    title: Text(mod.toUpperCase()),
                    value: _modules[mod],
                    onChanged: (val) =>
                        setState(() => _modules[mod] = val ?? false),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving || _selectedCId == null ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

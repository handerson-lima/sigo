import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/app_user.dart';
import '../data/dev_users_repository.dart';
import 'user_admin_dialogs.dart';

class UserDetailsScreen extends ConsumerStatefulWidget {
  final String userId;
  final FirebaseFirestore? firestore;

  const UserDetailsScreen({
    super.key,
    required this.userId,
    this.firestore,
  });

  @override
  ConsumerState<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends ConsumerState<UserDetailsScreen> {
  bool _isLoading = false;

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(formatarErroDevUsers(error)),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _updateGlobalRole(bool isDev) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(devUsersRepositoryProvider).setDevRole(
            widget.userId,
            isDev,
          );
      _showSuccess('Papel atualizado!');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleUserActive(AppUser user, bool isSelf) async {
    if (isSelf && user.isActive) {
      _showError('Você não pode desativar sua própria conta.');
      return;
    }

    final confirm = await showConfirmToggleUserActiveDialog(
      context,
      user: user,
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final targetActive = !user.isActive;
      await ref
          .read(devUsersRepositoryProvider)
          .adminSetUserActive(widget.userId, targetActive);
      _showSuccess(
        targetActive
            ? 'Usuário ativado com sucesso.'
            : 'Usuário desativado com sucesso.',
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword(AppUser user) async {
    final password = await showResetPasswordDialog(
      context,
      userLabel: '${user.displayName} (${user.email})',
    );
    if (password == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(devUsersRepositoryProvider)
          .adminResetUserPassword(widget.userId, password);
      _showSuccess('Senha provisória redefinida com sucesso.');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(AppUser user, bool isSelf) async {
    if (isSelf) {
      _showError('Você não pode excluir sua própria conta.');
      return;
    }

    final confirm = await showConfirmDeleteUserDialog(context, user: user);
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(devUsersRepositoryProvider).adminDeleteUser(widget.userId);
      if (mounted) {
        _showSuccess('Usuário excluído com sucesso.');
        context.pop();
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMembership({
    required String construtoraId,
    required String role,
    required bool isOwner,
    required List<String> modules,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover vínculo?'),
        content: const Text('O usuário perderá acesso a esta construtora.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final preservedRole = isOwner
          ? 'owner'
          : (['admin', 'operario', 'member'].contains(role) ? role : 'member');
      final validModules = modules
          .where((m) => ['estoque', 'almoxarifado'].contains(m))
          .toList();

      await ref.read(devUsersRepositoryProvider).setMembership(
            construtoraId: construtoraId,
            userId: widget.userId,
            role: preservedRole,
            isOwner: isOwner,
            modules: validModules,
            isActive: false,
          );
      _showSuccess('Vínculo removido com sucesso.');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(authStateChangesProvider).value?.uid;
    final isSelf = currentUid != null && currentUid == widget.userId;

    return SigoLayout(
      activeRoute: '/dev/users',
      title: 'Detalhes do Usuário',
      child: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(widget.userId).snapshots(),
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

          final raw = snapshot.data!.data() as Map<String, dynamic>;
          final data = Map<String, dynamic>.from(raw);
          data['id'] ??= snapshot.data!.id;
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] =
                (data['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          if (data['updatedAt'] is Timestamp) {
            data['updatedAt'] =
                (data['updatedAt'] as Timestamp).toDate().toIso8601String();
          }
          final user = AppUser.fromJson(data);
          final isDev = user.globalRole == 'dev';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usuário: ${user.displayName}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user.email,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: user.isActive
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.isActive ? 'ATIVO' : 'INATIVO',
                        style: TextStyle(
                          color: user.isActive
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Permissão Global e Conta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Acesso de Desenvolvedor'),
                          subtitle: const Text(
                            'Concede acesso ao painel de desenvolvedor. Cuidado.',
                          ),
                          value: isDev,
                          onChanged:
                              _isLoading ? null : (val) => _updateGlobalRole(val),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('user-details-toggle-active-btn'),
                              onPressed: (_isLoading || (isSelf && user.isActive))
                                  ? null
                                  : () => _toggleUserActive(user, isSelf),
                              icon: Icon(
                                user.isActive
                                    ? Icons.person_off_outlined
                                    : Icons.person_outline,
                              ),
                              label: Text(
                                user.isActive
                                    ? 'Desativar Usuário'
                                    : 'Ativar Usuário',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: user.isActive
                                    ? Colors.orange.shade800
                                    : Colors.teal.shade700,
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const Key('user-details-reset-password-btn'),
                              onPressed:
                                  _isLoading ? null : () => _resetPassword(user),
                              icon: const Icon(Icons.lock_reset),
                              label: const Text('Redefinir Senha'),
                            ),
                            ElevatedButton.icon(
                              key: const Key('user-details-delete-btn'),
                              onPressed: (_isLoading || isSelf)
                                  ? null
                                  : () => _deleteUser(user, isSelf),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Excluir Usuário'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (isSelf) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Auto-desativação e auto-exclusão são bloqueadas para o desenvolvedor logado.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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

                        // Lista de Vínculos (apenas ativos)
                        StreamBuilder<QuerySnapshot>(
                          stream: _db
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

                            final allMemberDocs =
                                memberSnapshot.data?.docs ?? [];
                            final memberDocs = allMemberDocs.where((doc) {
                              final docData =
                                  doc.data() as Map<String, dynamic>;
                              return docData['isActive'] == true;
                            }).toList();

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
                                final memberData =
                                    doc.data() as Map<String, dynamic>;
                                final role =
                                    (memberData['role'] as String?) ?? 'member';
                                final modules =
                                    (memberData['modules'] as List<dynamic>?)
                                            ?.cast<String>() ??
                                        [];
                                final cId = doc.reference.parent.parent!.id;

                                return FutureBuilder<DocumentSnapshot>(
                                  future: _db
                                      .collection('construtoras')
                                      .doc(cId)
                                      .get(),
                                  builder: (context, cSnapshot) {
                                    final cName = cSnapshot.data?.exists == true
                                        ? (cSnapshot.data!.data() as Map)['name']
                                        : 'Construtora Desconhecida';

                                    final isOwner =
                                        role == 'owner' ||
                                        memberData['isOwner'] == true;
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
                                        key: Key('remove-membership-$cId'),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: _isLoading
                                            ? null
                                            : () => _removeMembership(
                                                  construtoraId: cId,
                                                  role: role,
                                                  isOwner: isOwner,
                                                  modules: modules,
                                                ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => _LinkConstrutoraDialog(
                                      user: user,
                                      firestore: _db,
                                    ),
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

class _LinkConstrutoraDialog extends ConsumerStatefulWidget {
  final AppUser user;
  final FirebaseFirestore firestore;

  const _LinkConstrutoraDialog({
    required this.user,
    required this.firestore,
  });

  @override
  ConsumerState<_LinkConstrutoraDialog> createState() =>
      _LinkConstrutoraDialogState();
}

class _LinkConstrutoraDialogState
    extends ConsumerState<_LinkConstrutoraDialog> {
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

      await ref.read(devUsersRepositoryProvider).setMembership(
            construtoraId: _selectedCId!,
            userId: widget.user.id,
            role: _role,
            isOwner: _role == 'owner',
            modules: selectedModules,
            isActive: true,
          );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatarErroDevUsers(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
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
                future: widget.firestore.collection('construtoras').get(),
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
                  DropdownMenuItem(value: 'owner', child: Text('Proprietário')),
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

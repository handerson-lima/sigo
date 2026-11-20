import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/app_user.dart';
import '../../construtoras/data/membros_repository.dart';
import '../data/dev_users_repository.dart';
import 'user_admin_dialogs.dart';

final allConstrutorasMapProvider =
    StreamProvider.autoDispose<Map<String, String>>((ref) {
      return FirebaseFirestore.instance
          .collection('construtoras')
          .snapshots()
          .map((snap) {
            final map = <String, String>{};
            for (final doc in snap.docs) {
              final data = doc.data();
              map[doc.id] = data['name'] as String? ?? 'Sem Nome';
            }
            return map;
          });
    });

final allUserMembershipsProvider =
    StreamProvider.autoDispose<Map<String, List<Map<String, dynamic>>>>((ref) {
      return FirebaseFirestore.instance
          .collectionGroup('construtora_members')
          .snapshots()
          .map((snap) {
            final map = <String, List<Map<String, dynamic>>>{};
            for (final doc in snap.docs) {
              final data = doc.data();
              if (data['isActive'] != true) continue;
              final uid = (data['userId'] as String?) ?? doc.id;
              final cId =
                  (data['construtoraId'] as String?) ??
                  doc.reference.parent.parent?.id ??
                  '';
              data['_cId'] = cId;
              map.putIfAbsent(uid, () => []).add(data);
            }
            return map;
          });
    });

final allUsersStreamProvider = StreamProvider.autoDispose<List<AppUser>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map((
    snapshot,
  ) {
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] ??= doc.id;
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
      return AppUser.fromJson(data);
    }).toList();
  });
});

final allPendingRequestsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(membrosRepositoryProvider).watchAllPendingRequests();
    });

class UsersListScreen extends ConsumerStatefulWidget {
  const UsersListScreen({super.key});

  @override
  ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedConstrutoraId;
  String? _selectedRole;
  String _statusFilter = 'Todos';

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

  List<Widget> _buildUserBadges(
    AppUser user,
    List<Map<String, dynamic>> memberships,
    Map<String, String> construtorasMap,
  ) {
    final list = <Widget>[];

    if (!user.isActive) {
      list.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'INATIVO',
            style: TextStyle(
              color: Colors.red.shade900,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (user.globalRole == 'dev') {
      list.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'DEV',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    for (final m in memberships) {
      final cId = m['_cId'] as String? ?? '';
      final cName =
          construtorasMap[cId] ?? (cId.isNotEmpty ? cId : 'Construtora');
      final isOwner = m['isOwner'] == true || m['role'] == 'owner';
      final isAdmin =
          !isOwner && (m['isAdmin'] == true || m['role'] == 'admin');

      // Tag com Nome da Construtora
      list.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.business, size: 12, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                cName,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

      // Tag com o Papel na Construtora
      if (isOwner) {
        list.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars_rounded,
                  size: 13,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(width: 4),
                Text(
                  'PROPRIETÁRIO',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (isAdmin) {
        list.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'ADMIN',
              style: TextStyle(
                color: Colors.indigo.shade900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else {
        list.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'MEMBRO',
              style: TextStyle(
                color: Colors.teal.shade900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }

    if (user.globalRole != 'dev' && memberships.isEmpty) {
      list.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Sem vínculo',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return list;
  }

  Future<void> _createUser() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _CreateUserDialog(),
    );

    if (result == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(devUsersRepositoryProvider).adminCreateUser(
            email: result['email']!,
            password: result['password']!,
            displayName: result['name']!,
            operationId: const Uuid().v4(),
            globalRole: 'user',
          );
      _showSuccess('Usuário criado com sucesso via Cloud Function!');
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
          .adminSetUserActive(user.id, targetActive);
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

  Future<void> _resetUserPassword(AppUser user) async {
    final password = await showResetPasswordDialog(
      context,
      userLabel: '${user.displayName} (${user.email})',
    );
    if (password == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(devUsersRepositoryProvider)
          .adminResetUserPassword(user.id, password);
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
      await ref.read(devUsersRepositoryProvider).adminDeleteUser(user.id);
      _showSuccess('Usuário excluído com sucesso.');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = ref.watch(allPendingRequestsProvider).value ?? [];
    final construtorasMap = ref.watch(allConstrutorasMapProvider).value ?? {};
    final currentUid = ref.watch(authStateChangesProvider).value?.uid;

    return SigoLayout(
      activeRoute: '/dev/users',
      title: 'Gestão de Usuários',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Card de Solicitações Pendentes ---
            if (pendingRequests.isNotEmpty)
              _PendingRequestsCard(
                requests: pendingRequests,
                construtorasMap: construtorasMap,
              ),
            if (pendingRequests.isNotEmpty) const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  'Usuários do Sistema',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createUser,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Usuário'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou e-mail...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (val) => setState(
                      () => _searchQuery = val.trim().toLowerCase(),
                    ),
                  ),
                ),
                SegmentedButton<String>(
                  key: const Key('users-status-filter'),
                  segments: const [
                    ButtonSegment(value: 'Todos', label: Text('Todos')),
                    ButtonSegment(value: 'Ativos', label: Text('Ativos')),
                    ButtonSegment(value: 'Inativos', label: Text('Inativos')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (newSelection) {
                    setState(() => _statusFilter = newSelection.first);
                  },
                ),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedConstrutoraId,
                      hint: const Text('Construtora'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas as construtoras'),
                        ),
                        ...construtorasMap.entries.map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedConstrutoraId = val),
                    ),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      hint: const Text('Tipo de Usuário'),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Todos os tipos'),
                        ),
                        DropdownMenuItem(
                          value: 'dev',
                          child: Text('Dev Global'),
                        ),
                        DropdownMenuItem(
                          value: 'owner',
                          child: Text('Proprietário'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                        DropdownMenuItem(
                          value: 'member',
                          child: Text('Membro comum'),
                        ),
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('Sem vínculo'),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedRole = val),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Builder(
                builder: (context) {
                  final construtorasMap2 =
                      ref.watch(allConstrutorasMapProvider).value ?? {};
                  final userMembershipsMap =
                      ref.watch(allUserMembershipsProvider).value ?? {};
                  final usersAsync = ref.watch(allUsersStreamProvider);

                  return usersAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Erro: $err')),
                    data: (users) {
                      if (users.isEmpty) {
                        return const Center(
                          child: Text('Nenhum usuário encontrado.'),
                        );
                      }

                      var filteredUsers = users.where((u) {
                        if (_statusFilter == 'Ativos' && !u.isActive) {
                          return false;
                        }
                        if (_statusFilter == 'Inativos' && u.isActive) {
                          return false;
                        }

                        if (_searchQuery.isNotEmpty) {
                          final matchName = u.displayName
                              .toLowerCase()
                              .contains(_searchQuery);
                          final matchEmail = u.email.toLowerCase().contains(
                            _searchQuery,
                          );
                          if (!matchName && !matchEmail) return false;
                        }

                        final memberships = userMembershipsMap[u.id] ?? [];

                        if (_selectedConstrutoraId != null) {
                          if (u.globalRole != 'dev' &&
                              !memberships.any(
                                (m) => m['_cId'] == _selectedConstrutoraId,
                              )) {
                            return false;
                          }
                        }

                        if (_selectedRole != null) {
                          if (_selectedRole == 'dev' && u.globalRole != 'dev') {
                            return false;
                          }
                          if (_selectedRole == 'none' &&
                              memberships.isNotEmpty) {
                            return false;
                          }
                          if (_selectedRole == 'owner' &&
                              !memberships.any(
                                (m) =>
                                    m['isOwner'] == true ||
                                    m['role'] == 'owner',
                              )) {
                            return false;
                          }
                          if (_selectedRole == 'admin' &&
                              !memberships.any(
                                (m) =>
                                    !(m['isOwner'] == true ||
                                        m['role'] == 'owner') &&
                                    (m['isAdmin'] == true ||
                                        m['role'] == 'admin'),
                              )) {
                            return false;
                          }
                          if (_selectedRole == 'member' &&
                              !memberships.any(
                                (m) =>
                                    !(m['isOwner'] == true ||
                                        m['role'] == 'owner') &&
                                    !(m['isAdmin'] == true ||
                                        m['role'] == 'admin'),
                              )) {
                            return false;
                          }
                        }

                        return true;
                      }).toList();

                      if (filteredUsers.isEmpty) {
                        return const Center(
                          child: Text(
                            'Nenhum usuário corresponde aos filtros.',
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final memberships = userMembershipsMap[user.id] ?? [];
                          final badges = _buildUserBadges(
                            user,
                            memberships,
                            construtorasMap2,
                          );
                          final isSelf =
                              currentUid != null && currentUid == user.id;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: user.isActive
                                    ? Colors.orange.shade100
                                    : Colors.grey.shade200,
                                child: Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: user.isActive
                                        ? Colors.orange
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(user.displayName),
                              subtitle: Text(user.email),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...badges,
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.grey,
                                    ),
                                    tooltip: 'Editar detalhes',
                                    onPressed: () {
                                      context.push('/dev/users/${user.id}');
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    key: Key('user-actions-menu-${user.id}'),
                                    tooltip: 'Ações do usuário',
                                    enabled: !_isLoading,
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'details':
                                          context.push('/dev/users/${user.id}');
                                          break;
                                        case 'toggle_active':
                                          _toggleUserActive(user, isSelf);
                                          break;
                                        case 'reset_password':
                                          _resetUserPassword(user);
                                          break;
                                        case 'delete':
                                          _deleteUser(user, isSelf);
                                          break;
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'details',
                                        child: Row(
                                          children: [
                                            Icon(Icons.manage_accounts, size: 18),
                                            SizedBox(width: 8),
                                            Flexible(
                                              child: Text('Detalhes e Vínculos'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle_active',
                                        enabled: !(isSelf && user.isActive),
                                        child: Row(
                                          children: [
                                            Icon(
                                              user.isActive
                                                  ? Icons.person_off_outlined
                                                  : Icons.person_outline,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                user.isActive
                                                    ? 'Desativar conta'
                                                    : 'Ativar conta',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'reset_password',
                                        child: Row(
                                          children: [
                                            Icon(Icons.lock_reset, size: 18),
                                            SizedBox(width: 8),
                                            Flexible(
                                              child: Text('Redefinir senha'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        enabled: !isSelf,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_forever,
                                              size: 18,
                                              color: isSelf
                                                  ? Colors.grey
                                                  : Colors.red.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                'Excluir usuário',
                                                style: TextStyle(
                                                  color: isSelf
                                                      ? Colors.grey
                                                      : Colors.red.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController(text: defaultProvisionalPassword);
  bool _copied = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyPassword() async {
    await Clipboard.setData(ClipboardData(text: _passCtrl.text));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Senha provisória copiada para a área de transferência.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo Usuário (Nuvem)'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('create-user-name'),
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Informe o nome do usuário.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('create-user-email'),
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Informe o e-mail.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('create-user-password'),
                  controller: _passCtrl,
                  decoration: InputDecoration(
                    labelText: 'Senha Provisória',
                    helperText: 'Mínimo de 8 caracteres.',
                    suffixIcon: IconButton(
                      icon: Icon(_copied ? Icons.check : Icons.copy),
                      tooltip: 'Copiar senha',
                      onPressed: _copyPassword,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 8) {
                      return 'A senha deve ter no mínimo 8 caracteres.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('create-user-submit'),
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              Navigator.pop(context, {
                'email': _emailCtrl.text.trim(),
                'password': _passCtrl.text,
                'name': _nameCtrl.text.trim(),
              });
            }
          },
          child: const Text('Criar'),
        ),
      ],
    );
  }
}

class _PendingRequestsCard extends ConsumerWidget {
  final List<Map<String, dynamic>> requests;
  final Map<String, String> construtorasMap;

  const _PendingRequestsCard({
    required this.requests,
    required this.construtorasMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notification_important_rounded,
                color: Colors.amber.shade900,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Solicitações de Acesso Pendentes (${requests.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Administradores de construtoras solicitaram a inclusão dos usuários abaixo, cujas contas ainda não existem no sistema:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (ctx, i) => const Divider(height: 12),
            itemBuilder: (context, index) {
              final req = requests[index];
              final email = req['email'] as String? ?? '';
              final displayName =
                  req['displayName'] as String? ?? 'Sem nome informado';
              final construtoraId = req['construtoraId'] as String? ?? '';
              final construtoraNome =
                  construtorasMap[construtoraId] ?? 'Construtora Desconhecida';
              final role = (req['role'] as String? ?? 'member').toUpperCase();
              final isOwner = req['isOwner'] == true;
              final reqId = req['id'] as String;

              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.amber.shade200,
                    child: Icon(
                      Icons.person,
                      color: Colors.amber.shade900,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOwner ? 'PROPRIETÁRIO' : role,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$email • $construtoraNome',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => _ApproveRequestDialog(
                          requestId: reqId,
                          email: email,
                          displayName: displayName,
                          construtoraNome: construtoraNome,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Aprovar e Criar Acesso'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApproveRequestDialog extends ConsumerStatefulWidget {
  final String requestId;
  final String email;
  final String displayName;
  final String construtoraNome;

  const _ApproveRequestDialog({
    required this.requestId,
    required this.email,
    required this.displayName,
    required this.construtoraNome,
  });

  @override
  ConsumerState<_ApproveRequestDialog> createState() =>
      _ApproveRequestDialogState();
}

class _ApproveRequestDialogState extends ConsumerState<_ApproveRequestDialog> {
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    // Sugere uma senha padrão temporária
    _passCtrl.text = defaultProvisionalPassword;
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyPassword() async {
    await Clipboard.setData(ClipboardData(text: _passCtrl.text));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Senha provisória copiada para a área de transferência.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _approve() async {
    final pass = _passCtrl.text.trim();
    if (pass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A senha deve ter pelo menos 8 caracteres'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(membrosRepositoryProvider)
          .approveAccessRequest(widget.requestId, pass);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Acesso criado com sucesso para ${widget.email}! O solicitante foi notificado.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aprovar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_person, color: Colors.teal),
          SizedBox(width: 8),
          Text('Definir Senha Inicial'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Criar credencial de acesso para:',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.displayName} (${widget.email})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              'Construtora: ${widget.construtoraNome}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: 'Senha Provisória',
                border: const OutlineInputBorder(),
                helperText:
                    'Mínimo de 8 caracteres. O administrador da construtora receberá esta senha na notificação.',
                prefixIcon: const Icon(Icons.password),
                suffixIcon: IconButton(
                  icon: Icon(_copied ? Icons.check : Icons.copy),
                  tooltip: 'Copiar senha',
                  onPressed: _copyPassword,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _approve,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmar e Criar'),
        ),
      ],
    );
  }
}

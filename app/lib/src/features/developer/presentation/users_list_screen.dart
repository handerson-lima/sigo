import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../authentication/domain/app_user.dart';

final allConstrutorasMapProvider = StreamProvider.autoDispose<Map<String, String>>((ref) {
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

final allUserMembershipsProvider = StreamProvider.autoDispose<Map<String, List<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collectionGroup('construtora_members')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) {
        final map = <String, List<Map<String, dynamic>>>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          final uid = (data['userId'] as String?) ?? doc.id;
          final cId = (data['construtoraId'] as String?) ?? doc.reference.parent.parent?.id ?? '';
          data['_cId'] = cId;
          map.putIfAbsent(uid, () => []).add(data);
        }
        return map;
      });
});

final allUsersStreamProvider = StreamProvider.autoDispose<List<AppUser>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
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

class UsersListScreen extends ConsumerStatefulWidget {
  const UsersListScreen({super.key});

  @override
  ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen> {
  bool _isLoading = false;

  List<Widget> _buildUserBadges(
    AppUser user,
    List<Map<String, dynamic>> memberships,
    Map<String, String> construtorasMap,
  ) {
    final list = <Widget>[];

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
      final cName = construtorasMap[cId] ?? (cId.isNotEmpty ? cId : 'Construtora');
      final isOwner = m['isOwner'] == true || m['role'] == 'owner';
      final isAdmin = !isOwner && (m['isAdmin'] == true || m['role'] == 'admin');

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
                Icon(Icons.stars_rounded, size: 13, color: Colors.amber.shade900),
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

    if (list.isEmpty) {
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
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Usuário (Nuvem)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'email': emailCtrl.text.trim(),
              'password': passCtrl.text,
              'name': nameCtrl.text.trim(),
            }),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (result == null ||
        result['email']!.isEmpty ||
        result['password']!.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'adminCreateUser',
      );
      await callable.call({
        'email': result['email'],
        'password': result['password'],
        'displayName': result['name'],
        'operationId': const Uuid().v4(),
        'globalRole': 'user', // Creates as common user by default
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário criado com sucesso via Cloud Function!'),
          ),
        );
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
      title: 'Gestão de Usuários',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 24),
            Expanded(
              child: Builder(
                builder: (context) {
                  final construtorasMap = ref.watch(allConstrutorasMapProvider).value ?? {};
                  final userMembershipsMap = ref.watch(allUserMembershipsProvider).value ?? {};
                  final usersAsync = ref.watch(allUsersStreamProvider);

                  return usersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Erro: $err')),
                    data: (users) {
                      if (users.isEmpty) {
                        return const Center(
                          child: Text('Nenhum usuário encontrado.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final memberships = userMembershipsMap[user.id] ?? [];
                          final badges = _buildUserBadges(user, memberships, construtorasMap);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.orange,
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
                                    onPressed: () {
                                      context.push('/dev/users/${user.id}');
                                    },
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

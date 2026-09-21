import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/notifications_repository.dart';

class NotificationsButton extends ConsumerWidget {
  const NotificationsButton({super.key});

  void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _NotificationsPanel(uid: user.uid),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return IconButton(
      tooltip: 'Notificações',
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(
          '$unreadCount',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        ),
        backgroundColor: Colors.redAccent,
        child: Icon(
          unreadCount > 0 ? Icons.notifications_active : Icons.notifications_none,
          color: unreadCount > 0 ? Colors.amber[900] : Colors.black54,
        ),
      ),
      onPressed: () => _showNotificationsSheet(context, ref),
    );
  }
}

class _NotificationsPanel extends ConsumerWidget {
  final String uid;

  const _NotificationsPanel({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(userNotificationsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arraste
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_rounded, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Notificações',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: notifsAsync.when(
                  data: (notifs) {
                    if (notifs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma notificação no momento.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: notifs.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notif = notifs[index];
                        final isUnread = !notif.read;

                        // Tenta extrair a senha provisória se houver
                        String? provisoryPass;
                        final match = RegExp(r'Senha provisória:\s*([^\s\.]+)').firstMatch(notif.body);
                        if (match != null) {
                          provisoryPass = match.group(1);
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: isUnread ? Colors.amber.shade50.withValues(alpha: 0.5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isUnread ? Colors.amber.shade200 : Colors.grey.shade200,
                                    child: Icon(
                                      Icons.person_add,
                                      size: 16,
                                      color: isUnread ? Colors.amber.shade900 : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notif.title,
                                          style: TextStyle(
                                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notif.body,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                    tooltip: 'Remover',
                                    onPressed: () {
                                      ref
                                          .read(notificationsRepositoryProvider)
                                          .deleteNotification(uid, notif.id);
                                    },
                                  ),
                                ],
                              ),
                              if (provisoryPass != null) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 38),
                                  child: Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: provisoryPass!));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Senha provisória copiada: $provisoryPass'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                          if (isUnread) {
                                            ref.read(notificationsRepositoryProvider).markAsRead(uid, notif.id);
                                          }
                                        },
                                        icon: const Icon(Icons.copy, size: 14),
                                        label: Text('Copiar Senha: $provisoryPass'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.teal.shade800,
                                          side: BorderSide(color: Colors.teal.shade400),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (isUnread)
                                        TextButton(
                                          onPressed: () {
                                            ref.read(notificationsRepositoryProvider).markAsRead(uid, notif.id);
                                          },
                                          child: const Text('Marcar como lida', style: TextStyle(fontSize: 12)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

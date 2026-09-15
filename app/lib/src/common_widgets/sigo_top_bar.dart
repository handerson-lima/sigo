import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/data/auth_repository.dart';

class SigoTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const SigoTopBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final user = authState.value;
    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(
        color: Colors.black87,
      ), // For the drawer icon on mobile
      leading: context.canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black54),
              onPressed: () => context.pop(),
            )
          : null,
      title: Row(
        children: [
          if (context.canPop())
            const Text(
              'Voltar • ',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
      actions: [
        ...?actions,
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black54),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: Colors.amber[100],
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.amber[900],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

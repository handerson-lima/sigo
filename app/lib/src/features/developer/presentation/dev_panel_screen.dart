import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../../common_widgets/sigo_module_card.dart';

class DevPanelScreen extends ConsumerWidget {
  const DevPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SigoLayout(
      activeRoute: '/dev',
      title: 'Painel do Desenvolvedor',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Área de Administração',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Acesso restrito a desenvolvedores e administradores do sistema.',
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                SigoModuleCard(
                  title: 'Gestão de Usuários',
                  icon: Icons.people_alt,
                  onTap: () => context.push('/dev/users'),
                ),
                SigoModuleCard(
                  title: 'Gestão de Construtoras',
                  icon: Icons.business,
                  onTap: () {
                    context.push('/dev/construtoras');
                  },
                ),
                SigoModuleCard(
                  title: 'Testes de Integração',
                  icon: Icons.science,
                  onTap: () {
                    // TODO: Implementar depois
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Em breve!')));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

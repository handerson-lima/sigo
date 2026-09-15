import '../../authentication/data/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'user_construtoras_provider.dart';
import '../../../common_widgets/sigo_layout.dart';

class ConstrutorasListScreen extends ConsumerWidget {
  const ConstrutorasListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDev = ref.watch(trustedDevProvider).value == true;
    final construtorasAsync = ref.watch(userConstrutorasProvider);

    return SigoLayout(
      title: 'Minhas Construtoras',
      activeRoute: '/',
      actions: [
        if (isDev)
          FilledButton.icon(
            icon: const Icon(Icons.build),
            label: const Text('Painel Dev'),
            onPressed: () => context.go('/dev'),
          ),
      ],
      child: construtorasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (construtoras) {
          if (construtoras.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDev
                        ? 'Nenhuma construtora encontrada no sistema.'
                        : 'Você não pertence a nenhuma construtora.\nFale com o administrador.',
                    textAlign: TextAlign.center,
                  ),
                  if (isDev) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_business),
                      label: const Text('Gerenciar Construtoras no Painel Dev'),
                      onPressed: () => context.go('/dev/construtoras'),
                    ),
                  ],
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 3 / 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: construtoras.length,
            itemBuilder: (context, index) {
              final construtora = construtoras[index];
              return Card(
                elevation: 4,
                child: InkWell(
                  onTap: () => context.go('/construtora/${construtora.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          construtora.name,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        if (construtora.cnpj != null)
                          Text('CNPJ: ${construtora.cnpj}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import '../../authentication/data/user_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'user_construtoras_provider.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../../obras/presentation/current_permissions_provider.dart';
import '../../../core/contracts.dart';

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
                    isDev ? 'Nenhuma construtora ativa encontrada.' : 'Você não pertence a nenhuma construtora.\nFale com o administrador.',
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
              return Consumer(
                builder: (context, ref, child) {
                  final cm = ref
                      .watch(construtoraPermissionProvider(construtora.id))
                      .value;
                  final canViewLoteamentos =
                      isDev ||
                      (cm?['isActive'] == true &&
                          normalizeRawModules(
                            cm?['modules'],
                            cm?['allowedModules'],
                          ).contains('lotes'));

                  return Card(
                    elevation: 4,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        if (canViewLoteamentos) {
                          context.go(
                            '/construtoras/${construtora.id}/loteamentos',
                          );
                        } else {
                          context.go('/construtoras/${construtora.id}');
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (construtora.logoUrl != null)
                            Image.network(
                              construtora.logoUrl!,
                              fit: BoxFit.cover,
                            )
                          else
                            Container(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              child: const Center(
                                child: Icon(
                                  Icons.business,
                                  size: 48,
                                  color: Colors.black12,
                                ),
                              ),
                            ),
                          // Overlay escuro para garantir leitura do texto
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                                stops: [0.6, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Text(
                              construtora.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
    );
  }
}

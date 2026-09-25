import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/etapa_repository.dart';

import 'package:intl/intl.dart';

import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../../obras/presentation/current_permissions_provider.dart';

class EtapasListScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;

  const EtapasListScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
  });

  @override
  ConsumerState<EtapasListScreen> createState() => _EtapasListScreenState();
}

class _EtapasListScreenState extends ConsumerState<EtapasListScreen> {
  bool _isInitializing = false;

  Future<void> _inicializarEtapas() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      await ref
          .read(etapaRepositoryProvider)
          .createDefaultEtapas(
            construtoraId: widget.construtoraId,
            loteamentoId: widget.loteamentoId,
            quadraId: widget.quadraId,
            loteId: widget.loteId,
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A inicialização está demorando muito. Os dados estão sendo processados.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao inicializar etapas. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = (
      construtoraId: widget.construtoraId,
      loteamentoId: widget.loteamentoId,
      quadraId: widget.quadraId,
      loteId: widget.loteId,
    );
    final etapasAsync = ref.watch(watchEtapasProvider(params));
    final baseRoute =
        '/construtoras/${widget.construtoraId}/loteamentos/${widget.loteamentoId}/quadras/${widget.quadraId}/lotes/${widget.loteId}/etapas';

    final adminAsync = ref.watch(
      currentPermissionsProvider((
        construtoraId: widget.construtoraId,
        obraId: widget.loteamentoId,
      )),
    );
    final isAdmin = adminAsync.value?.isAdmin == true;

    return SigoLayout(
      title: 'Etapas',
      activeRoute: baseRoute,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: etapasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar as etapas.',
                cause: err,
                onRetry: () => ref.invalidate(watchEtapasProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SigoEmptyState(
                    message: 'Nenhuma etapa cadastrada',
                    icon: Icons.view_module_outlined,
                    action: adminAsync.when(
                      error: (err, _) => Text(
                        'Erro de permissão',
                        style: TextStyle(color: Colors.red.shade300),
                      ),
                      loading: () => const SizedBox.shrink(),
                      data: (_) {
                        if (!isAdmin) return null;
                        if (_isInitializing) {
                          return const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Inicializando...'),
                            ],
                          );
                        }
                        return ElevatedButton(
                          onPressed: _inicializarEtapas,
                          child: const Text('Inicializar Etapas'),
                        );
                      },
                      // loading e error já definidos acima
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final dateStr = DateFormat('dd/MM/yyyy HH:mm')
                        .format(item.createdAt);
                    return ListTile(
                      title: Text(item.nome),
                      subtitle: Text('Criado em: $dateStr'),
                      onTap: () {
                        context.go('$baseRoute/${item.id}/equipes');
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

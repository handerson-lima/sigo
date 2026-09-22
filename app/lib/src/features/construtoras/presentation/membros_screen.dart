import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common_widgets/sigo_layout.dart';
import 'add_membro_dialog.dart';
import 'membros_providers.dart';
import 'widgets/member_row.dart';
import 'widgets/role_chip.dart';

export 'membros_providers.dart' show membrosProvider, pendingRequestsProvider;

class MembrosScreen extends ConsumerWidget {
  final String construtoraId;

  const MembrosScreen({super.key, required this.construtoraId});

  void _invalidateTudo(WidgetRef ref) {
    ref.invalidate(membrosProvider(construtoraId));
    ref.invalidate(pendingRequestsProvider(construtoraId));
    ref.invalidate(obrasDaConstrutoraProvider(construtoraId));
    ref.invalidate(obrasAtivasProvider(construtoraId));
    ref.invalidate(contagemObrasPorMembroProvider(construtoraId));
    ref.invalidate(contagemObrasMetaProvider(construtoraId));
    ref.invalidate(obraMembersProvider);
  }

  bool _isOfflineError(Object err) {
    if (err is FirebaseException) {
      return err.code == 'unavailable' ||
          err.code == 'deadline-exceeded' ||
          err.code == 'network-request-failed' ||
          err.code == 'cancelled' ||
          err.code == 'aborted';
    }
    final msg = err.toString().toLowerCase();
    return msg.contains('unavailable') ||
        msg.contains('sem conexão') ||
        msg.contains('sem conexao') ||
        msg.contains('network') ||
        msg.contains('socket');
  }

  bool _isAccessDenied(Object err) {
    if (err is FirebaseException) {
      return err.code == 'permission-denied';
    }
    final msg = err.toString().toLowerCase();
    return msg.contains('permission-denied') ||
        msg.contains('permission denied');
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
        ),
        title: Container(
          height: 14,
          margin: const EdgeInsets.only(right: 80),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Container(
          height: 12,
          margin: const EdgeInsets.only(top: 6, right: 140),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membrosAsync = ref.watch(membrosProvider(construtoraId));
    final pendingAsync = ref.watch(pendingRequestsProvider(construtoraId));
    final obrasAtivasAsync = ref.watch(obrasAtivasProvider(construtoraId));
    final contagem = ref.watch(contagemObrasPorMembroProvider(construtoraId));
    final contagemMeta = ref.watch(contagemObrasMetaProvider(construtoraId));
    final contagemCarregando =
        (obrasAtivasAsync.isLoading && !obrasAtivasAsync.hasValue) ||
            contagemMeta.carregando;
    final contagemErro = contagemMeta.erro;

    return SigoLayout(
      title: 'Gestão de Membros',
      activeRoute: '/construtora/$construtoraId/membros',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add),
          tooltip: 'Convidar Membro',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AddMembroDialog(construtoraId: construtoraId),
            );
          },
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddMembroDialog(construtoraId: construtoraId),
          );
        },
        child: const Icon(Icons.person_add),
      ),
      child: membrosAsync.when(
        data: (membros) {
          final List<Map<String, dynamic>> pending = pendingAsync.value ?? [];
          final pendingErro = pendingAsync.hasError;
          final totalCount = pending.length + membros.length;

          if (totalCount == 0 && !pendingErro) {
            if (pendingAsync.isLoading) {
              return _buildSkeleton();
            }
            return RefreshIndicator(
              onRefresh: () async => _invalidateTudo(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('Nenhum membro encontrado.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _invalidateTudo(ref),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: totalCount + (pendingErro ? 1 : 0),
              itemBuilder: (context, index) {
                if (pendingErro && index == 0) {
                  return ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade800,
                    ),
                    title: const Text(
                      'Não foi possível carregar as solicitações pendentes.',
                    ),
                    trailing: TextButton(
                      onPressed: () => ref.invalidate(
                        pendingRequestsProvider(construtoraId),
                      ),
                      child: const Text('Recarregar'),
                    ),
                  );
                }
                final ajustado = pendingErro ? index - 1 : index;
                if (ajustado < pending.length) {
                  final req = pending[ajustado];
                  final roleRaw = req['role'];
                  final role = roleRaw is String ? roleRaw : null;
                  final cargo = rotuloCargoPendente(role);
                  final displayRaw = req['displayName'];
                  final emailRaw = req['email'];
                  final displayName =
                      displayRaw is String ? displayRaw.trim() : '';
                  final email = emailRaw is String ? emailRaw.trim() : '';
                  final nome = displayName.isNotEmpty
                      ? displayName
                      : (email.isNotEmpty ? email : 'Solicitação pendente');
                  final basePendente = subtitlePendente(role);
                  final subtitle =
                      (email.isNotEmpty && email != nome)
                          ? '$basePendente\n$email'
                          : basePendente;
                  final semantics = email.isNotEmpty && email != nome
                      ? '$nome, $email, $subtitle, pendente'
                      : '$nome, $subtitle, pendente';
                  return MemberRow(
                    nome: nome,
                    subtitle: subtitle,
                    semanticsLabel: semantics,
                    papel: PapelChip.pendente,
                    chipLabel: 'Pendente · $cargo',
                    isPendente: true,
                  );
                }

                final membro = membros[ajustado - pending.length];
                final cargo = rotuloCargo(membro);
                final count = contagem[membro.uid] ?? 0;
                final mostrarPlaceholder =
                    contagemCarregando || (contagemErro && count == 0);
                final subtitle = mostrarPlaceholder
                    ? '$cargo · …'
                    : subtitleMembroAtivo(membro, count);
                final nome = membro.email.trim().isNotEmpty
                    ? membro.email.trim()
                    : 'UID: ${membro.uid}';
                final semantics = contagemCarregando
                    ? '$nome, $cargo, carregando obras, ativo'
                    : (contagemErro && count == 0)
                        ? '$nome, $cargo, erro ao carregar obras, ativo'
                        : '$nome, $cargo, ${textoContagemObras(count)}, ativo';
                return MemberRow(
                  nome: nome,
                  subtitle: subtitle,
                  semanticsLabel: semantics,
                  papel: RoleChip.papelDe(membro.isOwner, membro.isAdmin),
                  chipLabel: cargo,
                );
              },
            ),
          );
        },
        loading: () => _buildSkeleton(),
        error: (err, stack) {
          final negado = _isAccessDenied(err);
          final offline = !negado && _isOfflineError(err);
          final mensagem =
              negado
                  ? 'Acesso negado — fale com o administrador.'
                  : offline
                  ? 'Sem conexão — tente novamente'
                  : 'Não foi possível carregar os membros. Tente novamente.';
          return RefreshIndicator(
            onRefresh: () async => _invalidateTudo(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mensagem, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _invalidateTudo(ref),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
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

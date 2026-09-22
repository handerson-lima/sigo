import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../obras/domain/obra.dart';
import '../domain/membro.dart';
import 'add_membro_dialog.dart';
import 'membros_providers.dart';
import 'widgets/member_row.dart';
import 'widgets/role_chip.dart';

export 'membros_providers.dart' show membrosProvider, pendingRequestsProvider;

class MembrosScreen extends ConsumerStatefulWidget {
  final String construtoraId;

  const MembrosScreen({super.key, required this.construtoraId});

  @override
  ConsumerState<MembrosScreen> createState() => _MembrosScreenState();
}

class _MembrosScreenState extends ConsumerState<MembrosScreen> {
  late final TextEditingController _buscaController;

  @override
  void initState() {
    super.initState();
    _buscaController = TextEditingController();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _invalidateTudo(WidgetRef ref) {
    final construtoraId = widget.construtoraId;
    ref.invalidate(membrosProvider(construtoraId));
    ref.invalidate(pendingRequestsProvider(construtoraId));
    ref.invalidate(obrasDaConstrutoraProvider(construtoraId));
    ref.invalidate(obrasAtivasProvider(construtoraId));
    ref.invalidate(contagemObrasPorMembroProvider(construtoraId));
    ref.invalidate(contagemObrasMetaProvider(construtoraId));
    ref.invalidate(uidObrasPorMembroProvider(construtoraId));
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

  Widget _buildFiltroBar(
    String construtoraId,
    FiltroMembros filtro,
    String? obraSelecionada,
    String query,
    AsyncValue<List<Obra>> obrasAtivasAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<FiltroMembros>(
              segments: const [
                ButtonSegment<FiltroMembros>(
                  value: FiltroMembros.todos,
                  label: Text('Todos'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment<FiltroMembros>(
                  value: FiltroMembros.porObra,
                  label: Text('Por obra'),
                  icon: Icon(Icons.business),
                ),
                ButtonSegment<FiltroMembros>(
                  value: FiltroMembros.pendentes,
                  label: Text('Pendentes'),
                  icon: Icon(Icons.hourglass_top_rounded),
                ),
              ],
              selected: {filtro},
              onSelectionChanged: (selecao) {
                ref
                    .read(filtroMembrosProvider.notifier)
                    .setFiltro(selecao.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _buscaController,
            decoration: InputDecoration(
              labelText: 'Buscar por email ou nome',
              hintText: 'Ex.: ana@obra.com',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        _buscaController.clear();
                        ref.read(buscaMembrosProvider.notifier).limpar();
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (value) =>
                ref.read(buscaMembrosProvider.notifier).setQuery(value),
          ),
          if (filtro == FiltroMembros.porObra) ...[
            const SizedBox(height: 8),
            obrasAtivasAsync.when(
              data: (obras) {
                if (obras.isEmpty) {
                  return const Text('Nenhuma obra ativa');
                }
                final sel = obraSelecionada;
                final selecionadaValida =
                    sel != null && obras.any((o) => o.id == sel);
                return DropdownButtonFormField<String>(
                  // Key derivada da seleção: recria o FormField quando a
                  // seleção muda, para o initialValue refletir a obra
                  // selecionada mesmo após reload (value está depreciado
                  // no Flutter 3.47 em favor de initialValue).
                  key: ValueKey(
                    'filtro-obra-dropdown-${selecionadaValida ? sel : 'nenhuma'}',
                  ),
                  initialValue: selecionadaValida ? sel : null,
                  decoration: const InputDecoration(
                    labelText: 'Obra',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Selecionar obra'),
                  items: [
                    for (final obra in obras)
                      DropdownMenuItem<String>(
                        value: obra.id,
                        child: Text(
                          obra.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => ref
                      .read(obraSelecionadaProvider.notifier)
                      .selecionar(value),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, stack) =>
                  const Text('Não foi possível carregar as obras.'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvisoPendentes(WidgetRef ref, String construtoraId) {
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

  @override
  Widget build(BuildContext context) {
    final construtoraId = widget.construtoraId;
    final membrosAsync = ref.watch(membrosProvider(construtoraId));
    final pendingAsync = ref.watch(pendingRequestsProvider(construtoraId));
    final obrasAtivasAsync = ref.watch(obrasAtivasProvider(construtoraId));
    final contagem = ref.watch(contagemObrasPorMembroProvider(construtoraId));
    final contagemMeta = ref.watch(contagemObrasMetaProvider(construtoraId));
    final contagemCarregando =
        (obrasAtivasAsync.isLoading && !obrasAtivasAsync.hasValue) ||
            contagemMeta.carregando;
    final contagemErro = contagemMeta.erro;
    // Loading da junção uid→obras (mesma fonte da contagem 8.1).
    final juncaoCarregando = contagemCarregando;

    final filtro = ref.watch(filtroMembrosProvider);
    final obraSelecionada = ref.watch(obraSelecionadaProvider);
    final query = ref.watch(buscaMembrosProvider);
    final uidObras = ref.watch(uidObrasPorMembroProvider(construtoraId));

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
          final totalBase = pending.length + membros.length;

          if (totalBase == 0 && !pendingErro) {
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

          // Filtro/busca em memória sobre a agregação 8.1.
          // Por obra exclui pendentes; Pendentes exclui ativos.
          // Seleção fora das obras ativas (ex.: desativada depois de
          // selecionada) equivale a sem seleção e é limpa.
          String? obraEfetiva;
          var selecaoObraInvalida = false;
          if (filtro == FiltroMembros.porObra) {
            final sel = obraSelecionada;
            if (sel == null || sel.isEmpty) {
              obraEfetiva = null;
            } else if (!obrasAtivasAsync.hasValue) {
              obraEfetiva = sel; // obras ainda carregando: não julgar
            } else if ((obrasAtivasAsync.value ?? const <Obra>[])
                .any((o) => o.id == sel)) {
              obraEfetiva = sel;
            } else {
              selecaoObraInvalida = true;
            }
          }
          if (selecaoObraInvalida) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(obraSelecionadaProvider.notifier).limpar();
            });
          }
          final semSelecaoDeObra = filtro == FiltroMembros.porObra &&
              (obraEfetiva == null || obraEfetiva.isEmpty);
          final List<Map<String, dynamic>> pendentesFiltrados;
          final List<Membro> ativosFiltrados;
          switch (filtro) {
            case FiltroMembros.porObra:
              final porObra = obraEfetiva == null || obraEfetiva.isEmpty
                  ? const <Membro>[]
                  : filtrarMembros(membros, uidObras, obraEfetiva);
              ativosFiltrados = buscarMembros(porObra, query);
              pendentesFiltrados = const [];
              break;
            case FiltroMembros.pendentes:
              ativosFiltrados = const [];
              pendentesFiltrados = filtrarPendentes(pending, query);
              break;
            case FiltroMembros.todos:
              ativosFiltrados = buscarMembros(membros, query);
              pendentesFiltrados = filtrarPendentes(pending, query);
              break;
          }
          final mostrarBannerPendente =
              pendingErro && filtro != FiltroMembros.porObra;
          final totalFiltrado =
              pendentesFiltrados.length + ativosFiltrados.length;

          if (totalFiltrado == 0) {
            // Junção uid→obras ainda carregando: skeleton, sem vazio falso.
            if (filtro == FiltroMembros.porObra &&
                obraEfetiva != null &&
                juncaoCarregando) {
              return _buildSkeleton();
            }
            return RefreshIndicator(
              onRefresh: () async => _invalidateTudo(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildFiltroBar(
                    construtoraId,
                    filtro,
                    obraSelecionada,
                    query,
                    obrasAtivasAsync,
                  ),
                  if (mostrarBannerPendente)
                    _buildAvisoPendentes(ref, construtoraId),
                  if (semSelecaoDeObra)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Text('Selecione uma obra'),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 80),
                    const Center(child: Text('Nenhum membro encontrado.')),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _invalidateTudo(ref),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount:
                  totalFiltrado + (mostrarBannerPendente ? 1 : 0) + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildFiltroBar(
                    construtoraId,
                    filtro,
                    obraSelecionada,
                    query,
                    obrasAtivasAsync,
                  );
                }
                final ajustado = mostrarBannerPendente ? index - 2 : index - 1;
                if (mostrarBannerPendente && index == 1) {
                  return _buildAvisoPendentes(ref, construtoraId);
                }
                if (ajustado < pendentesFiltrados.length) {
                  final req = pendentesFiltrados[ajustado];
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

                final membro =
                    ativosFiltrados[ajustado - pendentesFiltrados.length];
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../obras/presentation/construtora_obras_provider.dart';
import '../../obras/domain/obra.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/epi_repository.dart';
import '../domain/epi_event.dart';
import 'entrega_epi_screen.dart';

class ColaboradorEpisTab extends ConsumerStatefulWidget {
  final String construtoraId;
  final String? obraId;
  final String funcionarioId;
  final String funcionarioNome;

  const ColaboradorEpisTab({
    super.key,
    required this.construtoraId,
    this.obraId,
    required this.funcionarioId,
    required this.funcionarioNome,
  });

  @override
  ConsumerState<ColaboradorEpisTab> createState() => _ColaboradorEpisTabState();
}

class _ColaboradorEpisTabState extends ConsumerState<ColaboradorEpisTab> {
  String? _selectedObraId;

  @override
  void initState() {
    super.initState();
    if (widget.obraId != null && widget.obraId!.isNotEmpty) {
      _selectedObraId = widget.obraId;
    }
  }

  void _abrirNovaEntrega(BuildContext context, String obraIdAtiva) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntregaEpiScreen(
          construtoraId: widget.construtoraId,
          obraId: obraIdAtiva,
          preselectedFuncionarioId: widget.funcionarioId,
        ),
      ),
    );
  }

  void _confirmarBaixaOuDevolucao(
    BuildContext context,
    String obraIdAtiva,
    EpiEvent evento,
    String tipo, // 'devolucao' ou 'baixa_descarte'
  ) {
    final motivoController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tipo == 'devolucao'
              ? 'Registrar Devolução'
              : 'Registrar Baixa / Descarte',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Confirmar ${tipo == 'devolucao' ? 'a devolução' : 'a baixa'} de: ${evento.epiNome} (C.A.: ${evento.caNumero})?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ex: Troca periódica, danificado, rescisão...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = ref.read(authRepositoryProvider).currentUser;
              await ref
                  .read(epiRepositoryProvider)
                  .registrarDevolucaoOuBaixa(
                    construtoraId: widget.construtoraId,
                    obraId: obraIdAtiva,
                    eventoOriginalId: evento.id,
                    tipoEvento: tipo,
                    responsavelUid: user?.uid ?? 'sistema',
                    responsavelNome: user?.displayName ?? 'Responsável',
                    motivo: motivoController.text.trim().isEmpty
                        ? null
                        : motivoController.text.trim(),
                  );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(
      construtoraObrasProvider(widget.construtoraId),
    );
    final obras = obrasAsync.asData?.value ?? <Obra>[];

    String effectiveObraId = _selectedObraId ?? '';
    if (effectiveObraId.isEmpty && obras.isNotEmpty) {
      effectiveObraId = obras.first.id;
    }

    if (effectiveObraId.isEmpty) {
      return obrasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Erro ao carregar loteamentos: $err')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Nenhum loteamento cadastrado para consultar entregas de EPI.',
                ),
              ),
            );
          }
          return const SizedBox();
        },
      );
    }

    final eventsAsync = ref.watch(
      epiEventsFuncionarioStreamProvider((
        construtoraId: widget.construtoraId,
        obraId: effectiveObraId,
        funcionarioId: widget.funcionarioId,
      )),
    );

    final termosAsync = ref.watch(
      termosFuncionarioStreamProvider((
        construtoraId: widget.construtoraId,
        obraId: effectiveObraId,
        funcionarioId: widget.funcionarioId,
      )),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (obras.length > 1 &&
              (widget.obraId == null || widget.obraId!.isEmpty)) ...[
            DropdownButtonFormField<String>(
              initialValue: effectiveObraId,
              decoration: const InputDecoration(
                labelText: 'Loteamento',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: obras
                  .map(
                    (o) => DropdownMenuItem(value: o.id, child: Text(o.name)),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedObraId = val);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EPIs de ${widget.funcionarioNome}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_moderator),
                label: const Text('Nova Entrega de EPI'),
                onPressed: () => _abrirNovaEntrega(context, effectiveObraId),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Equipamentos Atualmente em Uso',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          eventsAsync.when(
            data: (events) {
              final ativos = events.where((e) => e.status == 'ativo').toList();
              if (ativos.isEmpty) {
                return Card(
                  elevation: 0,
                  color: Colors.grey.shade100,
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'Nenhum EPI ativo registrado para este colaborador no momento.',
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ativos.length,
                itemBuilder: (ctx, i) {
                  final ev = ativos[i];
                  final dataEntregaStr =
                      '${ev.dataEvento.day.toString().padLeft(2, '0')}/${ev.dataEvento.month.toString().padLeft(2, '0')}/${ev.dataEvento.year}';
                  final dataTrocaStr = ev.dataTrocaPrevista != null
                      ? '${ev.dataTrocaPrevista!.day.toString().padLeft(2, '0')}/${ev.dataTrocaPrevista!.month.toString().padLeft(2, '0')}/${ev.dataTrocaPrevista!.year}'
                      : 'Não informada';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ev.isTrocaVencida
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        child: Icon(
                          Icons.security,
                          color: ev.isTrocaVencida
                              ? Colors.red.shade900
                              : Colors.green.shade900,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${ev.epiNome} (Qtd: ${ev.quantidade})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (ev.isTrocaVencida)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red),
                              ),
                              child: const Text(
                                'SUBSTITUIÇÃO VENCIDA',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        'C.A.: ${ev.caNumero} • Entregue em: $dataEntregaStr • Troca prevista: $dataTrocaStr\nMotivo: ${ev.motivo ?? 'Não informado'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'devolver') {
                            _confirmarBaixaOuDevolucao(
                              context,
                              effectiveObraId,
                              ev,
                              'devolucao',
                            );
                          } else if (val == 'baixa') {
                            _confirmarBaixaOuDevolucao(
                              context,
                              effectiveObraId,
                              ev,
                              'baixa_descarte',
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'devolver',
                            child: Text('Registrar Devolução'),
                          ),
                          const PopupMenuItem(
                            value: 'baixa',
                            child: Text('Registrar Descarte/Baixa'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Erro ao carregar EPIs: $err'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Termos de Responsabilidade Assinados',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          termosAsync.when(
            data: (termos) {
              if (termos.isEmpty) {
                return const Card(
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Nenhum termo digital assinado arquivado.'),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: termos.length,
                itemBuilder: (ctx, i) {
                  final termo = termos[i];
                  final dataStr =
                      '${termo.dataAssinatura.day.toString().padLeft(2, '0')}/${termo.dataAssinatura.month.toString().padLeft(2, '0')}/${termo.dataAssinatura.year}';

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: const Icon(
                        Icons.assignment_turned_in,
                        color: Colors.blue,
                      ),
                      title: Text('Termo assinado em $dataStr'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Itens: ${termo.itens.map((it) => "${it['epiNome']} (CA ${it['caNumero']})").join(", ")}',
                          ),
                          Text(
                            'Hash SHA-256: ${termo.hashSha256.substring(0, 16)}...',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline),
                        tooltip: 'Ver Termo Completo',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(
                                'Termo de Responsabilidade - $dataStr',
                              ),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Colaborador: ${termo.funcionarioNome} (CPF: ${termo.funcionarioCpf})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Itens Entregues:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ...termo.itens.map(
                                      (it) => Text(
                                        '• ${it['epiNome']} - C.A. ${it['caNumero']} (Qtd: ${it['quantidade']})',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Texto Legal (NR-6 / CLT):',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      termo.textoLegal,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Hash SHA-256 Completo:\n${termo.hashSha256}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Fechar'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Erro ao carregar termos: $err'),
          ),
        ],
      ),
    );
  }
}

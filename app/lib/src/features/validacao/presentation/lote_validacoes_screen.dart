import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../data/validacao_repository.dart';
import '../domain/validacao_vistoria.dart';

class LoteValidacoesScreen extends ConsumerWidget {
  final String construtoraId;
  final String obraId;
  final String loteId;

  const LoteValidacoesScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
    required this.loteId,
  });

  Widget _buildStatusBadge(ValidacaoStatus status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case ValidacaoStatus.aprovado:
        bg = Colors.green[50]!;
        fg = Colors.green[800]!;
        icon = Icons.check_circle;
        break;
      case ValidacaoStatus.reprovado:
        bg = Colors.red[50]!;
        fg = Colors.red[800]!;
        icon = Icons.cancel;
        break;
      case ValidacaoStatus.reaberto:
        bg = Colors.orange[50]!;
        fg = Colors.orange[800]!;
        icon = Icons.refresh;
        break;
      case ValidacaoStatus.pendente:
        bg = Colors.blue[50]!;
        fg = Colors.blue[800]!;
        icon = Icons.pending;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidatedHeader(List<ValidacaoVistoria> vistorias) {
    if (vistorias.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Este lote ainda não possui nenhuma vistoria de qualidade registrada.',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    final hasReprovada = vistorias.any((v) => v.isReprovado);
    final hasReaberta = vistorias.any((v) => v.isReaberto);
    final allAprovadas = vistorias.every((v) => v.isAprovado);

    Color cardBg;
    Color borderCol;
    IconData statusIcon;
    Color iconCol;
    String title;
    String desc;

    if (hasReprovada) {
      cardBg = Colors.red[50]!;
      borderCol = Colors.red[200]!;
      statusIcon = Icons.warning_amber_rounded;
      iconCol = Colors.red[700]!;
      title = 'Atenção: Não-Conformidade Ativa no Lote';
      desc = 'Existem vistorias reprovadas aguardando retrabalho e re-inspeção.';
    } else if (hasReaberta) {
      cardBg = Colors.orange[50]!;
      borderCol = Colors.orange[200]!;
      statusIcon = Icons.sync_problem;
      iconCol = Colors.orange[700]!;
      title = 'Re-inspeção em Andamento';
      desc = 'O lote passou por retrabalho e está em processo de reavaliação.';
    } else if (allAprovadas) {
      cardBg = Colors.green[50]!;
      borderCol = Colors.green[200]!;
      statusIcon = Icons.verified;
      iconCol = Colors.green[700]!;
      title = 'Qualidade Conforme (100% Aprovado)';
      desc = 'Todas as disciplinas avaliadas foram aprovadas sem pendências técnicas.';
    } else {
      cardBg = Colors.blue[50]!;
      borderCol = Colors.blue[200]!;
      statusIcon = Icons.assignment_turned_in;
      iconCol = Colors.blue[700]!;
      title = 'Vistorias em Preenchimento';
      desc = 'Existem checklists de qualidade pendentes de finalização.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: iconCol, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconCol,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vistoriasAsync = ref.watch(
      loteVistoriasStreamProvider((
        construtoraId: construtoraId,
        obraId: obraId,
        loteId: loteId,
      )),
    );

    final df = DateFormat('dd/MM/yyyy HH:mm');

    return SigoLayout(
      title: 'Validação & Qualidade do Lote',
      activeRoute: '/construtora/$construtoraId/obra/$obraId/lotes/$loteId/validacoes',
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            context.go(
              '/construtora/$construtoraId/obra/$obraId/lotes/$loteId/validacoes/nova',
            );
          },
          icon: const Icon(Icons.playlist_add),
          label: const Text('Nova Vistoria'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.go('/construtora/$construtoraId/obra/$obraId/lotes');
                },
                tooltip: 'Voltar aos Lotes',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lote: $loteId',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          vistoriasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Erro ao carregar vistorias: $err')),
            data: (vistorias) {
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConsolidatedHeader(vistorias),
                    const SizedBox(height: 24),
                    Text(
                      'Histórico de Inspeções (${vistorias.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (vistorias.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.checklist, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'Nenhuma vistoria realizada para este lote.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  context.go(
                                    '/construtora/$construtoraId/obra/$obraId/lotes/$loteId/validacoes/nova',
                                  );
                                },
                                icon: const Icon(Icons.add_task),
                                label: const Text('Iniciar Vistoria'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: vistorias.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final vistoria = vistorias[index];
                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  context.go(
                                    '/construtora/$construtoraId/obra/$obraId/lotes/$loteId/validacoes/${vistoria.id}',
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: vistoria.isAprovado
                                            ? Colors.green[50]
                                            : (vistoria.isReprovado
                                                ? Colors.red[50]
                                                : Colors.blue[50]),
                                        child: Icon(
                                          vistoria.isAprovado
                                              ? Icons.check
                                              : (vistoria.isReprovado
                                                  ? Icons.priority_high
                                                  : Icons.edit_document),
                                          color: vistoria.isAprovado
                                              ? Colors.green[800]
                                              : (vistoria.isReprovado
                                                  ? Colors.red[800]
                                                  : Colors.blue[800]),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    vistoria.templateTitulo,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'v${vistoria.templateVersion}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue[800],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Inspetor: ${vistoria.inspetorNome} • Data: ${df.format(vistoria.dataVistoria)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Itens: ${vistoria.totalConformes} conformes / ${vistoria.totalNaoConformes} reprovados / ${vistoria.totalNaoSeAplica} N/A',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: vistoria.hasNaoConforme
                                                    ? Colors.red[800]
                                                    : Colors.grey[600],
                                                fontWeight: vistoria.hasNaoConforme
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _buildStatusBadge(vistoria.status),
                                          const SizedBox(height: 8),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

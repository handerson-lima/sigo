import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common_widgets/sigo_top_bar.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/despesas_adm_repository.dart';
import '../domain/despesa_adm.dart';
import 'despesa_liquidar_dialog.dart';

class DespesaAdmDetailsScreen extends ConsumerWidget {
  final String construtoraId;
  final String obraId;
  final String despesaId;

  const DespesaAdmDetailsScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
    required this.despesaId,
  });

  Future<void> _liquidar(
    BuildContext context,
    WidgetRef ref,
    DespesaAdm despesa, {
    int? numeroParcela,
  }) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final uid = user?.uid ?? 'anon';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => DespesaLiquidarDialog(
        construtoraId: construtoraId,
        obraId: obraId,
        despesa: despesa,
        numeroParcela: numeroParcela,
        userUid: uid,
      ),
    );

    if (result == true && context.mounted) {
      ref.invalidate(despesaDetailsFutureProvider((
        construtoraId: construtoraId,
        obraId: obraId,
        despesaId: despesaId,
      )));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Liquidação concluída com sucesso!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormat = DateFormat('dd/MM/yyyy');

    final despesaAsync = ref.watch(despesaDetailsFutureProvider((
      construtoraId: construtoraId,
      obraId: obraId,
      despesaId: despesaId,
    )));

    return Scaffold(
      appBar: SigoTopBar(
        title: 'Detalhes da Despesa',
        actions: [
          despesaAsync.maybeWhen(
            data: (despesa) {
              if (despesa == null || despesa.status == StatusDespesaAdm.pago) {
                return const SizedBox();
              }
              return IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Editar Despesa',
                onPressed: () {
                  context.push(
                    '/construtora/$construtoraId/obra/$obraId/despesas/$despesaId/editar',
                  );
                },
              );
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: despesaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (despesa) {
          if (despesa == null) {
            return const Center(child: Text('Despesa não encontrada.'));
          }

          final isPaga = despesa.status == StatusDespesaAdm.pago;
          final isCancelada = despesa.status == StatusDespesaAdm.cancelado;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                despesa.categoria.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                despesa.status.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: isPaga
                                  ? Colors.green.shade100
                                  : isCancelada
                                      ? Colors.grey.shade200
                                      : Colors.orange.shade100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          despesa.descricao,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (despesa.fornecedorNome != null &&
                            despesa.fornecedorNome!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.business, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Fornecedor: ${despesa.fornecedorNome!}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ],
                        if (despesa.loteId != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.home_work, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Alocação Direta: Lote ${despesa.loteId!}',
                                style: TextStyle(
                                  color: Colors.indigo.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Data de Emissão:',
                                    style: TextStyle(fontSize: 12)),
                                Text(
                                  dateFormat.format(despesa.dataEmissao),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Vencimento:',
                                    style: TextStyle(fontSize: 12)),
                                Text(
                                  dateFormat.format(despesa.dataVencimento),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: despesa.isVencida
                                        ? Colors.red.shade800
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Card de Valores
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total do Título',
                                  style: TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(despesa.valorTotal),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Pago',
                                  style: TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(despesa.valorPagoCents / 100.0),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Saldo Devedor',
                                  style: TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(despesa.saldoDevedorCents / 100.0),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: despesa.saldoDevedorCents > 0
                                      ? Colors.red.shade800
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Se houver cancelamento
                if (despesa.status == StatusDespesaAdm.cancelado) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Título Cancelado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Motivo: ${despesa.motivoCancelamento ?? "Não informado"}',
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Se houver anexo
                if (despesa.comprovanteUrl != null &&
                    despesa.comprovanteUrl!.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    color: Colors.blue.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.blue.shade200),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: Text(
                        despesa.comprovanteNome ?? 'Documento Comprobatório',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Toque para visualizar no navegador'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () {
                        // Link direto
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Parcelas (se parcelado)
                if (despesa.isParcelado && despesa.parcelas.isNotEmpty) ...[
                  const Text(
                    'Desdobramento em Parcelas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: despesa.parcelas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = despesa.parcelas[index];
                      final isParcelaPaga = p.status == StatusDespesaAdm.pago;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isParcelaPaga
                                ? Colors.green.shade100
                                : Colors.purple.shade100,
                            child: Text(
                              '${p.numero}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isParcelaPaga
                                    ? Colors.green.shade900
                                    : Colors.purple.shade900,
                              ),
                            ),
                          ),
                          title: Text(
                            currency.format(p.valorCents / 100.0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Vencimento: ${dateFormat.format(p.dataVencimento)}',
                          ),
                          trailing: isParcelaPaga
                              ? const Chip(
                                  label: Text('Pago'),
                                  backgroundColor: Colors.greenAccent,
                                )
                              : ElevatedButton(
                                  onPressed: () => _liquidar(
                                    context,
                                    ref,
                                    despesa,
                                    numeroParcela: p.numero,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Liquidar'),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Botão de Quitação Total
                if (!isPaga && !isCancelada) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _liquidar(context, ref, despesa),
                      icon: const Icon(Icons.check_circle),
                      label: Text(
                        'Liquidar Valor Restante (${currency.format(despesa.saldoDevedorCents / 100.0)})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

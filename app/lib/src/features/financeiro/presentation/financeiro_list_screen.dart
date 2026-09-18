import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import 'financeiro_provider.dart';
import '../domain/despesa.dart';
import '../data/financeiro_repository.dart';

class FinanceiroListScreen extends ConsumerWidget {
  final String construtoraId;

  const FinanceiroListScreen({super.key, required this.construtoraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final despesasAsync = ref.watch(despesasConstrutoraProvider(construtoraId));

    return SigoLayout(
      title: 'Contas a Pagar / Financeiro',
      activeRoute: '/construtora/$construtoraId/financeiro',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.go('/construtora/$construtoraId/financeiro/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Despesa'),
      ),
      child: despesasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
        data: (despesas) {
          int totalPendente = 0;
          int totalPago = 0;
          for (var d in despesas) {
            if (d.status == StatusDespesa.pago) {
              totalPago += d.valorEmCentavos;
            } else {
              totalPendente += d.valorEmCentavos;
            }
          }

          return Column(
            children: [
              // Resumo
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.red.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text('A Pagar / Atrasado'),
                              Text(
                                'R\$ ${(totalPendente / 100).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: Colors.green.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text('Total Pago'),
                              Text(
                                'R\$ ${(totalPago / 100).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: despesas.length,
                  itemBuilder: (context, index) {
                    final d = despesas[index];
                    final isPago = d.status == StatusDespesa.pago;
                    final isAtrasado =
                        !isPago && d.dataVencimento.isBefore(DateTime.now());

                    Color statusColor = Colors.grey;
                    if (isPago) {
                      statusColor = Colors.green;
                    } else if (isAtrasado) {
                      statusColor = Colors.red;
                    } else {
                      statusColor = Colors.orange;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor,
                          child: Icon(
                            isPago ? Icons.check : Icons.money_off,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(d.descricao),
                        subtitle: Text(
                          'Valor: R\$ ${d.valor.toStringAsFixed(2)}\nVencimento: ${d.dataVencimento.day.toString().padLeft(2, '0')}/${d.dataVencimento.month.toString().padLeft(2, '0')}/${d.dataVencimento.year}\nCategoria: ${d.categoria}',
                        ),
                        isThreeLine: true,
                        trailing: isPago
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(financeiroRepositoryProvider)
                                        .marcarComoPago(construtoraId, d.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Pagamento salvo localmente; aguardando confirmação do servidor.',
                                              ),
                                            ),
                                          );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Não foi possível salvar: $e',
                                              ),
                                            ),
                                          );
                                    }
                                  }
                                },
                                tooltip: 'Dar Baixa',
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

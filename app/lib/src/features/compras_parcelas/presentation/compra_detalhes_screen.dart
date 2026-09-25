import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/compras_repository.dart';
import '../domain/compra_nf.dart';
import '../domain/parcela_compra.dart';
import 'widgets/liquidar_parcela_dialog.dart';
import 'widgets/receber_materiais_dialog.dart';

class CompraDetalhesScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;
  final String compraId;

  const CompraDetalhesScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
    required this.compraId,
  });

  @override
  ConsumerState<CompraDetalhesScreen> createState() =>
      _CompraDetalhesScreenState();
}

class _CompraDetalhesScreenState extends ConsumerState<CompraDetalhesScreen> {
  bool _isLoading = false;

  Future<void> _liquidarParcela(CompraNf compra, ParcelaCompra parcela) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => LiquidarParcelaDialog(
        parcela: parcela,
        fornecedorNome: compra.fornecedorNome,
      ),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final user = ref.read(authRepositoryProvider).currentUser;
        final uid = user?.uid ?? 'anon_user';

        await ref.read(comprasRepositoryProvider).liquidarParcela(
              construtoraId: widget.construtoraId,
              obraId: widget.obraId,
              compraId: widget.compraId,
              numeroParcela: parcela.numero,
              pagoPorUid: uid,
              metodoPagamento: result['metodoPagamento'] as MetodoPagamentoCompra,
              dataPagamento: result['dataPagamento'] as DateTime?,
              observacaoPagamento: result['observacao'] as String?,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Parcela ${parcela.numero} liquidada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao liquidar parcela: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _receberMateriais(CompraNf compra) async {
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (ctx) => ReceberMateriaisDialog(compra: compra),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _isLoading = true);
      try {
        final user = ref.read(authRepositoryProvider).currentUser;
        final uid = user?.uid ?? 'anon_user';

        await ref.read(comprasRepositoryProvider).receberItensNoEstoque(
              construtoraId: widget.construtoraId,
              obraId: widget.obraId,
              compraId: widget.compraId,
              quantidadesRecebidasPorItem: result,
              responsavelId: uid,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entrada de materiais realizada no Almoxarifado!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao receber materiais: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelarCompra(CompraNf compra) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Cancelar Compra'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta ação cancelará a compra e todas as suas parcelas em aberto. É obrigatório registrar uma justificativa formal.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo do Cancelamento *',
                hintText: 'Mínimo de 10 caracteres...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 10) {
                Navigator.of(ctx).pop(true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('O motivo deve conter ao menos 10 caracteres.'),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmar Cancelamento'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final user = ref.read(authRepositoryProvider).currentUser;
        final uid = user?.uid ?? 'anon_user';

        await ref.read(comprasRepositoryProvider).cancelarCompra(
              construtoraId: widget.construtoraId,
              obraId: widget.obraId,
              compraId: widget.compraId,
              canceladoPorUid: uid,
              motivoCancelamento: controller.text.trim(),
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compra cancelada com sucesso.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao cancelar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compraAsync = ref.watch(
      compraDetailsFutureProvider((
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        compraId: widget.compraId,
      )),
    );

    return SigoLayout(
      title: 'Detalhes da Compra / NF',
      activeRoute:
          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/compras',
      actions: [
        compraAsync.maybeWhen(
          data: (compra) {
            if (compra == null) return const SizedBox.shrink();
            final podeCancelar = compra.status != StatusCompra.cancelado &&
                !compra.parcelas
                    .any((p) => p.status == StatusParcelaCompra.pago);

            return PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'editar') {
                  context.push(
                    '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/compras/${widget.compraId}/editar',
                  );
                } else if (val == 'cancelar') {
                  _cancelarCompra(compra);
                }
              },
              itemBuilder: (ctx) => [
                if (compra.status != StatusCompra.pago &&
                    compra.status != StatusCompra.cancelado)
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Editar Compra'),
                      ],
                    ),
                  ),
                if (podeCancelar)
                  const PopupMenuItem(
                    value: 'cancelar',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Cancelar Compra',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : compraAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erro ao carregar detalhes: $err'),
              ),
              data: (compra) {
                if (compra == null) {
                  return const Center(child: Text('Compra não encontrada.'));
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho Principal
                      _buildHeaderCard(compra),
                      const SizedBox(height: 16),

                      // Resumo Financeiro
                      _buildFinanceCard(compra),
                      const SizedBox(height: 16),

                      // Seção de Itens da Compra
                      _buildItensSection(compra),
                      const SizedBox(height: 16),

                      // Seção de Parcelas
                      _buildParcelasSection(compra),

                      // Informações de Cancelamento
                      if (compra.status == StatusCompra.cancelado) ...[
                        const SizedBox(height: 16),
                        _buildCancelamentoCard(compra),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeaderCard(CompraNf compra) {
    final statusColor = switch (compra.status) {
      StatusCompra.pago => Colors.green,
      StatusCompra.parcial => Colors.blue,
      StatusCompra.aberto => Colors.orange,
      StatusCompra.cancelado => Colors.red,
    };

    final recColor = switch (compra.statusRecebimento) {
      StatusRecebimentoCompra.recebido => Colors.green,
      StatusRecebimentoCompra.parcial => Colors.amber,
      StatusRecebimentoCompra.pendente => Colors.grey,
    };

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nota Fiscal: ${compra.numeroNf} ${compra.serieNf != null ? "Série ${compra.serieNf}" : ""}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      compra.fornecedorNome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey,
                      ),
                    ),
                    if (compra.fornecedorDocumento != null &&
                        compra.fornecedorDocumento!.isNotEmpty)
                      Text(
                        'CNPJ/CPF: ${compra.fornecedorDocumento}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBadge(
                    label: compra.status.label,
                    color: statusColor,
                  ),
                  const SizedBox(height: 6),
                  _buildBadge(
                    label: compra.statusRecebimento.label,
                    color: recColor,
                  ),
                  if (compra.isAtrasada) ...[
                    const SizedBox(height: 6),
                    _buildBadge(
                      label: 'Parcela em Atraso',
                      color: Colors.red,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _buildInfoColumn(
                'Data de Emissão',
                '${compra.dataEmissao.day.toString().padLeft(2, '0')}/${compra.dataEmissao.month.toString().padLeft(2, '0')}/${compra.dataEmissao.year}',
              ),
              if (compra.dataRecebimento != null)
                _buildInfoColumn(
                  'Data de Recebimento',
                  '${compra.dataRecebimento!.day.toString().padLeft(2, '0')}/${compra.dataRecebimento!.month.toString().padLeft(2, '0')}/${compra.dataRecebimento!.year}',
                ),
              if (compra.chaveAcessoNf != null && compra.chaveAcessoNf!.isNotEmpty)
                _buildInfoColumn('Chave de Acesso', compra.chaveAcessoNf!),
            ],
          ),
          if (compra.descricao != null && compra.descricao!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Descrição: ${compra.descricao}',
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinanceCard(CompraNf compra) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Composição Financeira da Compra',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFinanceTile(
                  'Valor dos Itens',
                  'R\$ ${compra.valorItens.toStringAsFixed(2)}',
                  Colors.blueGrey,
                ),
              ),
              Expanded(
                child: _buildFinanceTile(
                  'Frete / Despesas',
                  'R\$ ${(compra.frete + compra.despesasAcessorias).toStringAsFixed(2)}',
                  Colors.blueGrey,
                ),
              ),
              Expanded(
                child: _buildFinanceTile(
                  'Desconto',
                  'R\$ ${compra.desconto.toStringAsFixed(2)}',
                  Colors.orange,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildFinanceTile(
                  'Total da Compra',
                  'R\$ ${compra.totalCompra.toStringAsFixed(2)}',
                  Colors.blue,
                  isBold: true,
                ),
              ),
              Expanded(
                child: _buildFinanceTile(
                  'Total Pago',
                  'R\$ ${compra.totalPago.toStringAsFixed(2)}',
                  Colors.green,
                  isBold: true,
                ),
              ),
              Expanded(
                child: _buildFinanceTile(
                  'Saldo Devedor',
                  'R\$ ${compra.saldoDevedor.toStringAsFixed(2)}',
                  compra.saldoDevedorCents > 0 ? Colors.red : Colors.green,
                  isBold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItensSection(CompraNf compra) {
    final temPendente = !compra.isTotalmenteRecebido &&
        compra.status != StatusCompra.cancelado;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Itens Faturados (${compra.itens.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (temPendente)
                FilledButton.icon(
                  onPressed: () => _receberMateriais(compra),
                  icon: const Icon(Icons.inventory_2, size: 18),
                  label: const Text('Receber no Estoque'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (compra.itens.isEmpty)
            const Text('Nenhum item discriminado nesta compra.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: compra.itens.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (ctx, idx) {
                final item = compra.itens[idx];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: item.isTotalmenteRecebido
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1),
                      child: Icon(
                        item.isTotalmenteRecebido
                            ? Icons.check
                            : Icons.category,
                        color: item.isTotalmenteRecebido
                            ? Colors.green
                            : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.materialNome,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Quantidade: ${item.quantidade} ${item.unidadeMedida} × R\$ ${item.valorUnitario.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                          Text(
                            'Recebido: ${item.quantidadeRecebida} ${item.unidadeMedida} ${item.quantidadePendente > 0 ? "(Pendente: ${item.quantidadePendente})" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.isTotalmenteRecebido
                                  ? Colors.green
                                  : Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'R\$ ${item.valorTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildParcelasSection(CompraNf compra) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Parcelas e Vencimentos (${compra.parcelas.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (compra.isQuitada)
                _buildBadge(label: 'Totalmente Quitado', color: Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: compra.parcelas.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (ctx, idx) {
              final parcela = compra.parcelas[idx];
              final isPaga = parcela.status == StatusParcelaCompra.pago;

              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isPaga
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${parcela.numero}ª',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPaga ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'R\$ ${parcela.valor.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Vencimento: ${parcela.dataVencimento.day.toString().padLeft(2, '0')}/${parcela.dataVencimento.month.toString().padLeft(2, '0')}/${parcela.dataVencimento.year}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (isPaga && parcela.dataPagamento != null)
                          Text(
                            'Pago em: ${parcela.dataPagamento!.day.toString().padLeft(2, '0')}/${parcela.dataPagamento!.month.toString().padLeft(2, '0')}/${parcela.dataPagamento!.year} via ${parcela.metodoPagamento?.label ?? "Outro"}',
                            style: const TextStyle(fontSize: 11, color: Colors.green),
                          ),
                      ],
                    ),
                  ),
                  if (!isPaga && compra.status != StatusCompra.cancelado)
                    FilledButton.tonal(
                      onPressed: () => _liquidarParcela(compra, parcela),
                      child: const Text('Liquidar'),
                    )
                  else
                    _buildBadge(
                      label: parcela.status.label,
                      color: isPaga ? Colors.green : Colors.grey,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCancelamentoCard(CompraNf compra) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Compra Cancelada',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Motivo: ${compra.motivoCancelamento ?? "Não informado"}'),
          if (compra.dataCancelamento != null)
            Text(
              'Data: ${compra.dataCancelamento!.day}/${compra.dataCancelamento!.month}/${compra.dataCancelamento!.year}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildFinanceTile(String label, String value, Color color,
      {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

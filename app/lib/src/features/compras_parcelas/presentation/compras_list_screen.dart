import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../data/compras_repository.dart';
import '../domain/compra_nf.dart';

enum FiltroCompra { todas, abertas, pagas, recebidas, atrasadas }

class ComprasListScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;

  const ComprasListScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
  });

  @override
  ConsumerState<ComprasListScreen> createState() => _ComprasListScreenState();
}

class _ComprasListScreenState extends ConsumerState<ComprasListScreen> {
  final _searchController = TextEditingController();
  FiltroCompra _filtroSelecionado = FiltroCompra.todas;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comprasAsync = ref.watch(
      comprasObraStreamProvider((
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
      )),
    );

    return SigoLayout(
      title: 'Compras e Notas Fiscais',
      activeRoute:
          '/construtora/${widget.construtoraId}/obra/${widget.obraId}/compras',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push(
            '/construtora/${widget.construtoraId}/obra/${widget.obraId}/compras/nova',
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Compra / NF'),
      ),
      child: comprasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Erro ao carregar compras: $err'),
        ),
        data: (compras) {
          // Métricas Consolidadas
          final totalCompradoCents = compras
              .where((c) => c.status != StatusCompra.cancelado)
              .fold<int>(0, (acc, c) => acc + c.totalCompraCents);

          final totalPagoCents = compras
              .where((c) => c.status != StatusCompra.cancelado)
              .fold<int>(0, (acc, c) => acc + c.totalPagoCents);

          final saldoDevedorCents = compras
              .where((c) => c.status != StatusCompra.cancelado)
              .fold<int>(0, (acc, c) => acc + c.saldoDevedorCents);

          // Filtragem
          final busca = _searchController.text.trim().toLowerCase();
          final comprasFiltradas = compras.where((c) {
            if (busca.isNotEmpty) {
              final matchNf = c.numeroNf.toLowerCase().contains(busca);
              final matchForn = c.fornecedorNome.toLowerCase().contains(busca);
              if (!matchNf && !matchForn) return false;
            }

            return switch (_filtroSelecionado) {
              FiltroCompra.todas => true,
              FiltroCompra.abertas =>
                c.status == StatusCompra.aberto || c.status == StatusCompra.parcial,
              FiltroCompra.pagas => c.status == StatusCompra.pago,
              FiltroCompra.recebidas =>
                c.statusRecebimento == StatusRecebimentoCompra.recebido,
              FiltroCompra.atrasadas => c.isAtrasada,
            };
          }).toList();

          return Column(
            children: [
              // Top Cards de Métricas
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Total Comprado',
                        'R\$ ${(totalCompradoCents / 100.0).toStringAsFixed(2)}',
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        'Total Pago',
                        'R\$ ${(totalPagoCents / 100.0).toStringAsFixed(2)}',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        'A Pagar',
                        'R\$ ${(saldoDevedorCents / 100.0).toStringAsFixed(2)}',
                        saldoDevedorCents > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              // Barra de Busca e Filtros
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por número de NF ou fornecedor...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 8),

              // Chips de Filtro
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _buildFilterChip('Todas', FiltroCompra.todas),
                    const SizedBox(width: 8),
                    _buildFilterChip('Em Aberto', FiltroCompra.abertas),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pagas', FiltroCompra.pagas),
                    const SizedBox(width: 8),
                    _buildFilterChip('Recebidas', FiltroCompra.recebidas),
                    const SizedBox(width: 8),
                    _buildFilterChip('Atrasadas', FiltroCompra.atrasadas),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Lista de Compras
              Expanded(
                child: comprasFiltradas.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma compra ou nota fiscal encontrada.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: comprasFiltradas.length,
                        itemBuilder: (ctx, idx) {
                          final compra = comprasFiltradas[idx];
                          return _buildCompraCard(compra);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, FiltroCompra filtro) {
    final isSelected = _filtroSelecionado == filtro;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filtroSelecionado = filtro),
    );
  }

  Widget _buildCompraCard(CompraNf compra) {
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            context.push(
              '/construtora/${widget.construtoraId}/obra/${widget.obraId}/compras/${compra.id}',
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'NF ${compra.numeroNf} ${compra.serieNf != null ? "(Série ${compra.serieNf})" : ""}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildBadge(compra.status.label, statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  compra.fornecedorNome,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${compra.itens.length} ite${compra.itens.length > 1 ? "ns" : "m"} | ${compra.parcelas.length} parcela${compra.parcelas.length > 1 ? "s" : ""}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    _buildBadge(
                      compra.statusRecebimento.label,
                      recColor,
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emissão: ${compra.dataEmissao.day.toString().padLeft(2, '0')}/${compra.dataEmissao.month.toString().padLeft(2, '0')}/${compra.dataEmissao.year}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (compra.dataRecebimento != null)
                          Text(
                            'Recebido: ${compra.dataRecebimento!.day.toString().padLeft(2, '0')}/${compra.dataRecebimento!.month.toString().padLeft(2, '0')}/${compra.dataRecebimento!.year}',
                            style: TextStyle(fontSize: 12, color: Colors.green[700]),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R\$ ${compra.totalCompra.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        if (compra.saldoDevedorCents > 0 &&
                            compra.status != StatusCompra.cancelado)
                          Text(
                            'Saldo: R\$ ${compra.saldoDevedor.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
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

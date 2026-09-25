import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common_widgets/sigo_layout.dart';
import 'controllers/custos_360_controller.dart';
import '../domain/custo_lote_consolidado.dart';
import 'widgets/cubo_custo_card.dart';

class LoteCustoDetalheScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;
  final String loteId;

  const LoteCustoDetalheScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
    required this.loteId,
  });

  @override
  ConsumerState<LoteCustoDetalheScreen> createState() =>
      _LoteCustoDetalheScreenState();
}

class _LoteCustoDetalheScreenState extends ConsumerState<LoteCustoDetalheScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatarMoeda(int cents) {
    final valor = cents / 100.0;
    final valorStr = valor.toStringAsFixed(2).replaceAll('.', ',');
    final partes = valorStr.split(',');
    final inteira = partes[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'R\$ $inteira,${partes[1]}';
  }

  void _abrirDialogoEditarOrcamento(
    BuildContext context,
    CustoLoteConsolidado? loteCusto,
  ) {
    final controller = TextEditingController(
      text: loteCusto != null && loteCusto.orcamentoPrevistoCents > 0
          ? (loteCusto.orcamentoPrevistoCents / 100.0).toStringAsFixed(2)
          : '',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Definir Meta Orçamentária'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informe o teto orçamentário previsto para ${loteCusto?.loteNome ?? "o lote"}:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: 'R\$ ',
                labelText: 'Orçamento Previsto (R\$)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.replaceAll(',', '.').trim();
              final valorDouble = double.tryParse(text) ?? 0.0;
              final cents = (valorDouble * 100).round();

              Navigator.of(dialogCtx).pop();

              final sucesso = await ref
                  .read(custos360ControllerProvider)
                  .atualizarOrcamentoLote(
                    construtoraId: widget.construtoraId,
                    obraId: widget.obraId,
                    loteId: widget.loteId,
                    orcamentoPrevistoCents: cents,
                  );

              if (context.mounted) {
                if (sucesso) {
                  ref.invalidate(
                    resumoCustosObraStreamProvider((
                      construtoraId: widget.construtoraId,
                      obraId: widget.obraId,
                    )),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Orçamento previsto atualizado com sucesso!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Falha ao atualizar orçamento.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Salvar Meta'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loteCusto = ref.watch(
      loteCustoConsolidadoProvider((
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        loteId: widget.loteId,
      )),
    );

    final extratoAsync = ref.watch(
      extratoLoteFutureProvider((
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        loteId: widget.loteId,
      )),
    );

    final titulo = loteCusto?.loteNome ?? 'Detalhe de Custos do Lote';

    return SigoLayout(
      title: titulo,
      activeRoute:
          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/custos-360',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_calendar_outlined),
          tooltip: 'Definir Orçamento',
          onPressed: () => _abrirDialogoEditarOrcamento(context, loteCusto),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Atualizar Extrato',
          onPressed: () {
            ref.invalidate(
              extratoLoteFutureProvider((
                construtoraId: widget.construtoraId,
                obraId: widget.obraId,
                loteId: widget.loteId,
              )),
            );
          },
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loteCusto != null) ...[
              _buildHeaderLote(context, loteCusto),
              const SizedBox(height: 20),

              // 4 Cubos do Lote
              const Text(
                'Composição dos 4 Cubos do Lote',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isWide ? 1.5 : 1.1,
                    children: [
                      CuboCustoCard(
                        cubo: CuboCusto.material,
                        valorCents: loteCusto.materiaisCents,
                        totalReferenciaCents: loteCusto.totalCustoLoteCents,
                        onTap: () => _tabController.animateTo(1),
                      ),
                      CuboCustoCard(
                        cubo: CuboCusto.maoDeObra,
                        valorCents: loteCusto.maoDeObraCents,
                        totalReferenciaCents: loteCusto.totalCustoLoteCents,
                        onTap: () => _tabController.animateTo(2),
                      ),
                      CuboCustoCard(
                        cubo: CuboCusto.despesaDireta,
                        valorCents: loteCusto.despesasDiretasCents,
                        totalReferenciaCents: loteCusto.totalCustoLoteCents,
                        onTap: () => _tabController.animateTo(3),
                      ),
                      CuboCustoCard(
                        cubo: CuboCusto.rateioIndireto,
                        valorCents: loteCusto.rateioIndiretoCents,
                        totalReferenciaCents: loteCusto.totalCustoLoteCents,
                        onTap: () => _tabController.animateTo(4),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // Seção de Extrato com Abas
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Extrato Analítico de Lançamentos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _abrirDialogoEditarOrcamento(context, loteCusto),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Ajustar Meta'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Todos'),
                Tab(text: 'Materiais'),
                Tab(text: 'Mão de Obra'),
                Tab(text: 'Despesas Diretas'),
                Tab(text: 'Rateio Indireto'),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 480,
              child: extratoAsync.when(
                data: (extrato) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaExtrato(extrato, null),
                      _buildListaExtrato(extrato, CuboCusto.material),
                      _buildListaExtrato(extrato, CuboCusto.maoDeObra),
                      _buildListaExtrato(extrato, CuboCusto.despesaDireta),
                      _buildListaExtrato(extrato, CuboCusto.rateioIndireto),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Erro ao carregar extrato do lote: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderLote(BuildContext context, CustoLoteConsolidado lote) {
    Color corBadge;
    String textoBadge;
    if (lote.estourado) {
      corBadge = Colors.red.shade700;
      textoBadge = 'Orçamento Estourado';
    } else if (lote.emAlerta) {
      corBadge = Colors.orange.shade800;
      textoBadge = 'Alerta Orçamentário (>=85%)';
    } else if (lote.orcamentoPrevistoCents > 0) {
      corBadge = Colors.green.shade700;
      textoBadge = 'Dentro do Orçamento';
    } else {
      corBadge = Colors.grey.shade600;
      textoBadge = 'Sem Meta Definida';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Custo Acumulado do Lote',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: corBadge.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: corBadge, width: 0.8),
                  ),
                  child: Text(
                    textoBadge,
                    style: TextStyle(
                      color: corBadge,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatarMoeda(lote.totalCustoLoteCents),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta Orçamentária',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatarMoeda(lote.orcamentoPrevistoCents),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lote.temDesvioPositivo
                          ? 'Desvio Acima'
                          : 'Saldo Restante',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatarMoeda(lote.varianciaCents.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: lote.temDesvioPositivo
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (lote.orcamentoPrevistoCents > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: lote.percentualConsumido.clamp(0.0, 1.0),
                color: corBadge,
                backgroundColor: Colors.grey.shade200,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(lote.percentualConsumido * 100).toStringAsFixed(1)}% consumido',
                  style: TextStyle(
                    fontSize: 11,
                    color: corBadge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListaExtrato(List<ExtratoItemCusto> todos, CuboCusto? filtro) {
    final filtrados = filtro != null
        ? todos.where((item) => item.cubo == filtro).toList()
        : todos;

    if (filtrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              filtro != null
                  ? 'Nenhum lançamento no cubo ${filtro.label}.'
                  : 'Nenhum lançamento de custo encontrado para este lote.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: filtrados.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = filtrados[index];
        final (cor, icone) = switch (item.cubo) {
          CuboCusto.material => (
            Colors.orange.shade700,
            Icons.inventory_2_outlined,
          ),
          CuboCusto.maoDeObra => (Colors.blue.shade700, Icons.groups_outlined),
          CuboCusto.despesaDireta => (
            Colors.purple.shade700,
            Icons.receipt_long_outlined,
          ),
          CuboCusto.rateioIndireto => (
            Colors.teal.shade700,
            Icons.pie_chart_outline_rounded,
          ),
        };

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cor.withValues(alpha: 0.12),
            child: Icon(icone, color: cor, size: 20),
          ),
          title: Text(
            item.descricao,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${_formatarData(item.data)}${item.documentoReferencia != null ? " • Doc: ${item.documentoReferencia}" : ""}${item.responsavelNome != null ? " • ${item.responsavelNome}" : ""}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          trailing: Text(
            _formatarMoeda(item.valorCents),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: item.valorCents < 0
                  ? Colors.green.shade700
                  : Colors.black87,
            ),
          ),
        );
      },
    );
  }

  String _formatarData(DateTime data) {
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    final y = data.year;
    return '$d/$m/$y';
  }
}

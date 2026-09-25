import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import 'controllers/custos_360_controller.dart';
import '../domain/custo_lote_consolidado.dart';
import 'widgets/cubo_custo_card.dart';

class Visao360CustosScreen extends ConsumerWidget {
  final String construtoraId;
  final String obraId;

  const Visao360CustosScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
  });

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumoAsync = ref.watch(
      resumoCustosObraStreamProvider(
        (construtoraId: construtoraId, obraId: obraId),
      ),
    );

    return SigoLayout(
      title: 'Visão 360º de Custos',
      activeRoute: '/construtoras/$construtoraId/obra/$obraId/custos-360',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Recalcular Projeções',
          onPressed: () => ref.refresh(
            resumoCustosObraStreamProvider(
              (construtoraId: construtoraId, obraId: obraId),
            ),
          ),
        ),
      ],
      child: resumoAsync.when(
        data: (resumo) {
          final totalGeralCents = resumo.totalGeralCents;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                resumoCustosObraStreamProvider(
                  (construtoraId: construtoraId, obraId: obraId),
                ),
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card de Resumo Geral Executivo
                  _buildCardTotalObra(context, resumo),
                  const SizedBox(height: 20),

                  // Seção dos 4 Cubos de Custo
                  const Text(
                    'Composição pelos 4 Cubos de Custo',
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
                            valorCents: resumo.totalMateriaisCents,
                            totalReferenciaCents: totalGeralCents,
                          ),
                          CuboCustoCard(
                            cubo: CuboCusto.maoDeObra,
                            valorCents: resumo.totalMaoDeObraCents,
                            totalReferenciaCents: totalGeralCents,
                          ),
                          CuboCustoCard(
                            cubo: CuboCusto.despesaDireta,
                            valorCents: resumo.totalDespesasDiretasCents,
                            totalReferenciaCents: totalGeralCents,
                          ),
                          CuboCustoCard(
                            cubo: CuboCusto.rateioIndireto,
                            valorCents: resumo.totalDespesasIndiretasCents,
                            totalReferenciaCents: totalGeralCents,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Barra de Distribuição Percentual
                  if (totalGeralCents > 0) ...[
                    _buildBarraDistribuicao(context, resumo),
                    const SizedBox(height: 24),
                  ],

                  // Matriz de Lotes da Obra
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Matriz de Custos por Lote (${resumo.lotesCustos.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (resumo.lotesCustos.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.layers_clear_outlined,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text(
                                'Nenhum lote cadastrado nesta obra.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cadastre lotes no módulo de Obras/Lotes para apurar os 4 cubos.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: resumo.lotesCustos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final loteCusto = resumo.lotesCustos[index];
                        return _buildCardLote(context, loteCusto, totalGeralCents);
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Consolidando 4 cubos de custos...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('Erro ao carregar Visão 360: $err',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(
                    resumoCustosObraStreamProvider(
                      (construtoraId: construtoraId, obraId: obraId),
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardTotalObra(BuildContext context, ResumoCustosObra resumo) {
    final orcamentoTotal = resumo.orcamentoTotalPrevistoCents;
    final totalGeral = resumo.totalGeralCents;
    final variancia = totalGeral - orcamentoTotal;
    final desvioPositivo = orcamentoTotal > 0 && totalGeral > orcamentoTotal;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Custo Total Realizado da Obra',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Atualizado em ${_formatarData(resumo.apuradoEm)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatarMoeda(totalGeral),
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
                    Text('Orçamento Previsto',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text(_formatarMoeda(orcamentoTotal),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Variação Orçamentária',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text(
                      _formatarMoeda(variancia.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: desvioPositivo ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraDistribuicao(BuildContext context, ResumoCustosObra resumo) {
    final total = resumo.totalGeralCents.toDouble();
    final pMat = resumo.totalMateriaisCents / total;
    final pMo = resumo.totalMaoDeObraCents / total;
    final pDd = resumo.totalDespesasDiretasCents / total;
    final pRi = resumo.totalDespesasIndiretasCents / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribuição Relativa dos Gastos',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                if (pMat > 0)
                  Expanded(
                    flex: (pMat * 1000).toInt(),
                    child: Container(color: Colors.orange.shade700),
                  ),
                if (pMo > 0)
                  Expanded(
                    flex: (pMo * 1000).toInt(),
                    child: Container(color: Colors.blue.shade700),
                  ),
                if (pDd > 0)
                  Expanded(
                    flex: (pDd * 1000).toInt(),
                    child: Container(color: Colors.purple.shade700),
                  ),
                if (pRi > 0)
                  Expanded(
                    flex: (pRi * 1000).toInt(),
                    child: Container(color: Colors.teal.shade700),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardLote(
    BuildContext context,
    CustoLoteConsolidado lote,
    int totalObraCents,
  ) {
    final percObra = totalObraCents > 0
        ? (lote.totalCustoLoteCents / totalObraCents.toDouble()) * 100.0
        : 0.0;

    Color corBadge;
    String textoBadge;
    if (lote.estourado) {
      corBadge = Colors.red.shade700;
      textoBadge = 'Estourado';
    } else if (lote.emAlerta) {
      corBadge = Colors.orange.shade800;
      textoBadge = 'Alerta';
    } else if (lote.orcamentoPrevistoCents > 0) {
      corBadge = Colors.green.shade700;
      textoBadge = 'No Orçamento';
    } else {
      corBadge = Colors.grey.shade600;
      textoBadge = 'Sem Meta';
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.go(
            '/construtoras/$construtoraId/obra/$obraId/custos-360/lotes/${lote.loteId}',
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
                    child: Text(
                      lote.loteNome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: corBadge.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: corBadge, width: 0.5),
                    ),
                    child: Text(
                      textoBadge,
                      style: TextStyle(
                        color: corBadge,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Realizado',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Text(
                        _formatarMoeda(lote.totalCustoLoteCents),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Participação na Obra',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Text(
                        '${percObra.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Barra de progresso do orçamento
              if (lote.orcamentoPrevistoCents > 0) ...[
                LinearProgressIndicator(
                  value: lote.percentualConsumido.clamp(0.0, 1.0),
                  color: corBadge,
                  backgroundColor: Colors.grey.shade200,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Meta: ${_formatarMoeda(lote.orcamentoPrevistoCents)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Text(
                      '${(lote.percentualConsumido * 100).toStringAsFixed(1)}% consumido',
                      style: TextStyle(
                        fontSize: 11,
                        color: corBadge,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 18),
              // Mini indicadores dos 4 cubos
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _miniCuboIndicator('Mat', lote.materiaisCents, Colors.orange.shade700),
                    const SizedBox(width: 8),
                    _miniCuboIndicator('M.O.', lote.maoDeObraCents, Colors.blue.shade700),
                    const SizedBox(width: 8),
                    _miniCuboIndicator('Dir', lote.despesasDiretasCents, Colors.purple.shade700),
                    const SizedBox(width: 8),
                    _miniCuboIndicator('Ind', lote.rateioIndiretoCents, Colors.teal.shade700),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniCuboIndicator(String label, int cents, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ${_formatarMoeda(cents)}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _formatarData(DateTime data) {
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    final y = data.year;
    final h = data.hour.toString().padLeft(2, '0');
    final min = data.minute.toString().padLeft(2, '0');
    return '$d/$m/$y às $h:$min';
  }
}

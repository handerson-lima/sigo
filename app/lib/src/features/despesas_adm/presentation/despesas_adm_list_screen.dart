import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/despesas_adm_repository.dart';
import '../domain/despesa_adm.dart';
import 'despesa_liquidar_dialog.dart';
import 'widgets/despesa_card.dart';

class DespesasAdmListScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;

  const DespesasAdmListScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
  });

  @override
  ConsumerState<DespesasAdmListScreen> createState() =>
      _DespesasAdmListScreenState();
}

class _DespesasAdmListScreenState extends ConsumerState<DespesasAdmListScreen> {
  String _filtroStatus = 'todos'; // todos, pendentes, pagos, atrasados
  String _termoBusca = '';

  Future<void> _abrirModalLiquidacao(DespesaAdm despesa) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final uid = user?.uid ?? 'anon';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => DespesaLiquidarDialog(
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        despesa: despesa,
        userUid: uid,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Despesa liquidada com sucesso!'),
        ),
      );
    }
  }

  Future<void> _cancelarDespesa(DespesaAdm despesa) async {
    final controller = TextEditingController();
    final user = ref.read(authRepositoryProvider).currentUser;
    final uid = user?.uid ?? 'anon';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Despesa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Atenção: O cancelamento é irreversível e exige justificativa com pelo menos 10 caracteres.',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Motivo do Cancelamento *',
                hintText: 'Ex: Boleto emitido com valor incorreto pelo fornecedor',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.trim().length >= 10) {
                Navigator.of(ctx).pop(true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Justificativa deve ter no mínimo 10 caracteres.'),
                  ),
                );
              }
            },
            child: const Text('Confirmar Cancelamento'),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      try {
        await ref.read(despesasAdmRepositoryProvider).cancelarDespesa(
              construtoraId: widget.construtoraId,
              obraId: widget.obraId,
              despesaId: despesa.id,
              motivo: controller.text.trim(),
              canceladoPorUid: uid,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Despesa cancelada com sucesso.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text('Erro ao cancelar despesa: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final despesasAsync = ref.watch(despesasObraStreamProvider(
        (construtoraId: widget.construtoraId, obraId: widget.obraId)));

    return SigoLayout(
      title: 'Módulo ADM — Contas a Pagar',
      activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/despesas',
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            context.push(
              '/construtora/${widget.construtoraId}/obra/${widget.obraId}/despesas/nova',
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Nova Despesa'),
        ),
      ],
      child: despesasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar despesas: $err')),
        data: (despesas) {
          // Totais consolidados
          int totalPendenteCents = 0;
          int totalPagoCents = 0;
          int totalAtrasadoCents = 0;

          for (final d in despesas) {
            if (d.status == StatusDespesaAdm.pago) {
              totalPagoCents += d.valorTotalCents;
            } else if (d.status == StatusDespesaAdm.pendente) {
              if (d.isVencida) {
                totalAtrasadoCents += d.saldoDevedorCents;
              } else {
                totalPendenteCents += d.saldoDevedorCents;
              }
            }
          }

          // Filtragem
          final filtradas = despesas.where((d) {
            if (_termoBusca.isNotEmpty) {
              final query = _termoBusca.toLowerCase();
              final descMatch = d.descricao.toLowerCase().contains(query);
              final fornMatch =
                  (d.fornecedorNome ?? '').toLowerCase().contains(query);
              if (!descMatch && !fornMatch) return false;
            }

            return switch (_filtroStatus) {
              'pendentes' => d.status == StatusDespesaAdm.pendente && !d.isVencida,
              'pagos' => d.status == StatusDespesaAdm.pago,
              'atrasados' => d.isVencida,
              _ => true,
            };
          }).toList();

          return Column(
            children: [
              // Cards de Resumo Financeiro
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.orange.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.orange.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'A Pagar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(totalPendenteCents / 100.0),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        color: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Atrasadas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(totalAtrasadoCents / 100.0),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        color: Colors.green.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.green.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Pago',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(totalPagoCents / 100.0),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
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

              // Barra de Busca e Filtros
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por descrição ou fornecedor...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _termoBusca = val),
                ),
              ),
              const SizedBox(height: 8),

              // Chips de Filtro
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Todas'),
                      selected: _filtroStatus == 'todos',
                      onSelected: (_) => setState(() => _filtroStatus = 'todos'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Pendentes'),
                      selected: _filtroStatus == 'pendentes',
                      onSelected: (_) =>
                          setState(() => _filtroStatus = 'pendentes'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Atrasadas'),
                      selected: _filtroStatus == 'atrasados',
                      onSelected: (_) =>
                          setState(() => _filtroStatus = 'atrasados'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Pagas'),
                      selected: _filtroStatus == 'pagos',
                      onSelected: (_) => setState(() => _filtroStatus = 'pagos'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Lista de Despesas
              Expanded(
                child: filtradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma conta a pagar encontrada.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filtradas.length,
                        itemBuilder: (context, index) {
                          final d = filtradas[index];
                          return DespesaCard(
                            despesa: d,
                            onTap: () {
                              context.push(
                                '/construtora/${widget.construtoraId}/obra/${widget.obraId}/despesas/${d.id}',
                              );
                            },
                            onLiquidar: () => _abrirModalLiquidacao(d),
                            onCancelar: () => _cancelarDespesa(d),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common_widgets/sigo_sidebar.dart';
import '../data/chamada_repository.dart';
import '../domain/chamada_diaria.dart';

class ChamadasListScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;

  const ChamadasListScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
  });

  @override
  ConsumerState<ChamadasListScreen> createState() => _ChamadasListScreenState();
}

class _ChamadasListScreenState extends ConsumerState<ChamadasListScreen> {
  String _statusFilter = 'todas'; // 'todas' | 'confirmada' | 'retificada'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final chamadasAsync = ref.watch(
      chamadasStreamProvider((
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
      )),
    );

    return Scaffold(
      drawer: SigoSidebar(
        activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas',
      ),
      appBar: AppBar(
        title: const Text('Chamada Diária (RH)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova Chamada',
            onPressed: () => context.push(
              '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/nova',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'todas', label: Text('Todas')),
                      ButtonSegment(value: 'confirmada', label: Text('Confirmadas')),
                      ButtonSegment(value: 'retificada', label: Text('Retificadas')),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (set) {
                      setState(() {
                        _statusFilter = set.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: chamadasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text('Erro ao carregar chamadas: $e'),
              ),
              data: (chamadas) {
                final filtered = chamadas.where((c) {
                  if (_statusFilter == 'todas') return c.status != 'cancelada';
                  return c.status == _statusFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fact_check_outlined,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma chamada diária registrada.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Inicie o registro de presença da equipe para apropriar a mão de obra nos lotes.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Lançar Chamada de Hoje'),
                            onPressed: () => context.push(
                              '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/nova',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final chamada = filtered[index];
                    return _ChamadaCard(
                      chamada: chamada,
                      onTap: () => context.push(
                        '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/${chamada.id}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.playlist_add_check),
        label: const Text('Nova Chamada'),
        onPressed: () => context.push(
          '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/nova',
        ),
      ),
    );
  }
}

class _ChamadaCard extends StatelessWidget {
  final ChamadaDiaria chamada;
  final VoidCallback onTap;

  const _ChamadaCard({
    required this.chamada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    DateTime? parsedDate = DateTime.tryParse(chamada.date);
    final dateDisplay = parsedDate != null
        ? DateFormat('dd/MM/yyyy (EEE)', 'pt_BR').format(parsedDate)
        : chamada.date;

    final isRetificada = chamada.status == 'retificada';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        dateDisplay,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (isRetificada)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Retificada',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                chamada.teamName != null
                    ? 'Equipe: ${chamada.teamName}'
                    : 'Equipe: Geral da Obra',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              // Badges de Presença
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Badge(
                    label: '${chamada.presentCount} presentes',
                    color: Colors.green,
                    icon: Icons.check,
                  ),
                  if (chamada.meioPeriodoCount > 0)
                    _Badge(
                      label: '${chamada.meioPeriodoCount} meio-período',
                      color: Colors.orange,
                      icon: Icons.schedule,
                    ),
                  if (chamada.faltaCount > 0)
                    _Badge(
                      label: '${chamada.faltaCount} faltas',
                      color: Colors.red,
                      icon: Icons.close,
                    ),
                  _Badge(
                    label: '${chamada.totalWorkers} total',
                    color: Colors.blueGrey,
                    icon: Icons.groups,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

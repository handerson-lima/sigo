import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../data/epi_repository.dart';
import '../domain/epi_item.dart';
import 'epi_form_dialog.dart';

class CatalogoEpisScreen extends ConsumerStatefulWidget {
  final String construtoraId;

  const CatalogoEpisScreen({super.key, required this.construtoraId});

  @override
  ConsumerState<CatalogoEpisScreen> createState() => _CatalogoEpisScreenState();
}

class _CatalogoEpisScreenState extends ConsumerState<CatalogoEpisScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'todas';
  String _statusFilter = 'todos'; // todos, ativos, ca_vencido, ca_vencendo

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirFormulario([EpiItem? item]) {
    showDialog(
      context: context,
      builder: (ctx) =>
          EpiFormDialog(construtoraId: widget.construtoraId, initialItem: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final episAsync = ref.watch(
      catalogoEpisStreamProvider(widget.construtoraId),
    );

    return SigoLayout(
      title: 'Catálogo de EPIs',
      activeRoute: '/construtoras/${widget.construtoraId}/epis',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _abrirFormulario(),
          icon: const Icon(Icons.add),
          label: const Text('Novo EPI'),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome, fabricante ou C.A...',
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
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedCategory,
                  items: const [
                    DropdownMenuItem(
                      value: 'todas',
                      child: Text('Todas as Categorias'),
                    ),
                    DropdownMenuItem(value: 'cabeca', child: Text('Cabeça')),
                    DropdownMenuItem(
                      value: 'ocular',
                      child: Text('Olhos/Face'),
                    ),
                    DropdownMenuItem(
                      value: 'auditiva',
                      child: Text('Auditiva'),
                    ),
                    DropdownMenuItem(
                      value: 'respiratoria',
                      child: Text('Respiratória'),
                    ),
                    DropdownMenuItem(
                      value: 'maos_bracos',
                      child: Text('Membros Sup.'),
                    ),
                    DropdownMenuItem(
                      value: 'pes_pernas',
                      child: Text('Membros Inf.'),
                    ),
                    DropdownMenuItem(
                      value: 'altura',
                      child: Text('Quedas/Altura'),
                    ),
                    DropdownMenuItem(value: 'outros', child: Text('Outros')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(
                      value: 'todos',
                      child: Text('Todos os Status'),
                    ),
                    DropdownMenuItem(
                      value: 'ativos',
                      child: Text('Apenas Ativos'),
                    ),
                    DropdownMenuItem(
                      value: 'ca_vencido',
                      child: Text('C.A. Vencido'),
                    ),
                    DropdownMenuItem(
                      value: 'ca_vencendo',
                      child: Text('C.A. a Vencer (<30d)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _statusFilter = val);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: episAsync.when(
              data: (epis) {
                final query = _searchController.text.trim().toLowerCase();
                final filtered = epis.where((epi) {
                  if (_selectedCategory != 'todas' &&
                      epi.categoria != _selectedCategory) {
                    return false;
                  }
                  if (_statusFilter == 'ativos' && !epi.isActive) return false;
                  if (_statusFilter == 'ca_vencido' && !epi.isCaVencido)
                    return false;
                  if (_statusFilter == 'ca_vencendo' &&
                      !epi.isCaProximoVencimento(30))
                    return false;

                  if (query.isNotEmpty) {
                    final nMatch = epi.nome.toLowerCase().contains(query);
                    final fMatch = epi.fabricante.toLowerCase().contains(query);
                    final caMatch = epi.caNumero.toLowerCase().contains(query);
                    return nMatch || fMatch || caMatch;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nenhum EPI encontrado com os filtros aplicados.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Cadastrar Primeiro EPI'),
                          onPressed: () => _abrirFormulario(),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final epi = filtered[index];
                    return _buildEpiCard(epi);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Erro ao carregar catálogo: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpiCard(EpiItem epi) {
    Widget caBadge;
    if (epi.isCaVencido) {
      caBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, size: 14, color: Colors.red.shade800),
            const SizedBox(width: 4),
            Text(
              'C.A. Vencido',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (epi.isCaProximoVencimento(30)) {
      caBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 14, color: Colors.amber.shade900),
            const SizedBox(width: 4),
            Text(
              'Vence em ${epi.diasParaVencer}d',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      caBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade800),
            const SizedBox(width: 4),
            Text(
              'C.A. Válido',
              style: TextStyle(
                color: Colors.green.shade900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final dataValStr =
        '${epi.caValidade.day.toString().padLeft(2, '0')}/${epi.caValidade.month.toString().padLeft(2, '0')}/${epi.caValidade.year}';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: epi.isActive
              ? Colors.blue.shade100
              : Colors.grey.shade300,
          child: Icon(
            _getCategoryIcon(epi.categoria),
            color: epi.isActive ? Colors.blue.shade900 : Colors.grey.shade600,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                epi.nome,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: epi.isActive ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            const SizedBox(width: 8),
            caBadge,
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${epi.categoriaFormatada} • Fabricante: ${epi.fabricante}'),
              const SizedBox(height: 2),
              Text(
                'C.A.: ${epi.caNumero} (Validade: $dataValStr) • Vida Útil: ${epi.vidaUtilDias} dias • Unidade: ${epi.unidade}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) async {
            if (val == 'editar') {
              _abrirFormulario(epi);
            } else if (val == 'toggle_status') {
              await ref
                  .read(epiRepositoryProvider)
                  .toggleEpiStatus(widget.construtoraId, epi.id, !epi.isActive);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'editar', child: Text('Editar')),
            PopupMenuItem(
              value: 'toggle_status',
              child: Text(epi.isActive ? 'Inativar EPI' : 'Ativar EPI'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'cabeca':
        return Icons.hardware;
      case 'ocular':
        return Icons.visibility;
      case 'auditiva':
        return Icons.hearing;
      case 'respiratoria':
        return Icons.masks;
      case 'maos_bracos':
        return Icons.front_hand;
      case 'pes_pernas':
        return Icons.do_not_step;
      case 'altura':
        return Icons.airline_seat_recline_extra;
      default:
        return Icons.security;
    }
  }
}

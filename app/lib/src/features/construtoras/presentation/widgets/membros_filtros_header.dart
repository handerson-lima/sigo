import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../obras/domain/obra.dart';
import '../membros_providers.dart';

/// Barra superior da lista de membros: segmented Todos/Por obra/Pendentes,
/// busca por email/nome e dropdown de obra (estado vazio explícito).
///
/// Extraída de `MembrosScreen` (retro epic-8 item 1 — god-class growth).
/// Estado permanece no parent (Riverpod + `TextEditingController`); aqui
/// só apresentação e repasse de callbacks — StatelessWidget pura de
/// apresentação, convenção já usada pelos widgets desta feature.
class MembrosFiltrosHeader extends StatelessWidget {
  final FiltroMembros filtro;
  final String? obraSelecionada;
  final String query;
  final TextEditingController buscaController;
  final AsyncValue<List<Obra>> obrasAtivasAsync;
  final ValueChanged<FiltroMembros> onFiltroChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onLimparBusca;
  final ValueChanged<String?> onObraChanged;

  const MembrosFiltrosHeader({
    super.key,
    required this.filtro,
    required this.obraSelecionada,
    required this.query,
    required this.buscaController,
    required this.obrasAtivasAsync,
    required this.onFiltroChanged,
    required this.onQueryChanged,
    required this.onLimparBusca,
    required this.onObraChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<FiltroMembros>(
              segments: const [
                ButtonSegment<FiltroMembros>(
                  value: FiltroMembros.todos,
                  label: Text('Todos'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment<FiltroMembros>(
                  value: FiltroMembros.porObra,
                  label: Text('Por loteamento'),
                  icon: Icon(Icons.business),
                ),
                ButtonSegment<FiltroMembros>(
                  value: FiltroMembros.pendentes,
                  label: Text('Pendentes'),
                  icon: Icon(Icons.hourglass_top_rounded),
                ),
              ],
              selected: {filtro},
              onSelectionChanged: (selecao) => onFiltroChanged(selecao.first),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: buscaController,
            decoration: InputDecoration(
              labelText: 'Buscar por email ou nome',
              hintText: 'Ex.: ana@obra.com',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Limpar busca',
                      onPressed: onLimparBusca,
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onChanged: onQueryChanged,
          ),
          if (filtro == FiltroMembros.porObra) ...[
            const SizedBox(height: 8),
            obrasAtivasAsync.when(
              data: (obras) {
                if (obras.isEmpty) {
                  return const Text('Nenhum loteamento ativo');
                }
                final sel = obraSelecionada;
                final selecionadaValida =
                    sel != null && obras.any((o) => o.id == sel);
                return DropdownButtonFormField<String>(
                  // Key derivada da seleção: recria o FormField quando a
                  // seleção muda, para o initialValue refletir a obra
                  // selecionada mesmo após reload (value está depreciado
                  // no Flutter 3.47 em favor de initialValue).
                  key: ValueKey(
                    'filtro-obra-dropdown-${selecionadaValida ? sel : 'nenhuma'}',
                  ),
                  initialValue: selecionadaValida ? sel : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Loteamento',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Selecionar loteamento'),
                  items: [
                    for (final obra in obras)
                      DropdownMenuItem<String>(
                        value: obra.id,
                        child: Text(obra.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: onObraChanged,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, stack) =>
                  const Text('Não foi possível carregar os loteamentos.'),
            ),
          ],
        ],
      ),
    );
  }
}

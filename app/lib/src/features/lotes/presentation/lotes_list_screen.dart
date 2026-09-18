import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/lote_repository.dart';
import '../domain/lote.dart';
import 'obra_lotes_provider.dart';

class LotesListScreen extends ConsumerWidget {
  final String construtoraId;
  final String obraId;

  const LotesListScreen({super.key, required this.construtoraId, required this.obraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotesAsync = ref.watch(obraLotesProvider((construtoraId: construtoraId, obraId: obraId)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Lotes'),
      ),
      body: lotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
        data: (lotes) {
          if (lotes.isEmpty) {
            return const Center(child: Text('Nenhum lote cadastrado nesta obra.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final lote = lotes[index];
              return _LoteCard(lote: lote);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/construtora/$construtoraId/obra/$obraId/lotes/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Lote'),
      ),
    );
  }
}

class _LoteCard extends ConsumerWidget {
  final Lote lote;
  const _LoteCard({required this.lote});

  Color _getStatusColor() {
    switch (lote.status) {
      case LoteStatus.noPrazo:
        return Colors.green[100]!;
      case LoteStatus.atrasado:
        return Colors.red[100]!;
      case LoteStatus.paralisado:
        return Colors.orange[100]!;
      case LoteStatus.concluido:
        return Colors.blue[100]!;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: _getStatusColor(),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) => _EditLoteSheet(lote: lote),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lote.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Fase: ${lote.phase}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.fact_check, size: 20, color: Colors.black54),
                    tooltip: 'Vistorias de Qualidade',
                    onPressed: () {
                      context.go(
                        '/construtora/${lote.construtoraId}/obra/${lote.obraId}/lotes/${lote.id}/validacoes',
                      );
                    },
                  ),
                ],
              ),
              Text('Status: ${lote.status.name}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditLoteSheet extends ConsumerStatefulWidget {
  final Lote lote;

  const _EditLoteSheet({required this.lote});

  @override
  ConsumerState<_EditLoteSheet> createState() => _EditLoteSheetState();
}

class _EditLoteSheetState extends ConsumerState<_EditLoteSheet> {
  late String _selectedPhase;
  late LoteStatus _selectedStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedPhase = widget.lote.phase;
    _selectedStatus = widget.lote.status;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(loteRepositoryProvider);
      if (_selectedPhase != widget.lote.phase) {
        await repo.updatePhase(
          widget.lote.construtoraId,
          widget.lote.obraId,
          widget.lote.id,
          _selectedPhase,
        );
      }
      if (_selectedStatus != widget.lote.status) {
        await repo.updateStatus(
          widget.lote.construtoraId,
          widget.lote.obraId,
          widget.lote.id,
          _selectedStatus,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lote atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar lote: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lote: ${widget.lote.name}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedPhase,
            decoration: const InputDecoration(labelText: 'Fase de Construção'),
            items: defaultLotePhases.map((phase) {
              return DropdownMenuItem(value: phase, child: Text(phase));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedPhase = val);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<LoteStatus>(
            initialValue: _selectedStatus,
            decoration: const InputDecoration(labelText: 'Status Operacional'),
            items: const [
              DropdownMenuItem(value: LoteStatus.noPrazo, child: Text('No Prazo')),
              DropdownMenuItem(value: LoteStatus.atrasado, child: Text('Atrasado')),
              DropdownMenuItem(value: LoteStatus.paralisado, child: Text('Paralisado')),
              DropdownMenuItem(value: LoteStatus.concluido, child: Text('Concluído')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedStatus = val);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar Alterações'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go(
                  '/construtora/${widget.lote.construtoraId}/obra/${widget.lote.obraId}/lotes/${widget.lote.id}/validacoes',
                );
              },
              icon: const Icon(Icons.fact_check),
              label: const Text('Vistorias de Qualidade do Lote'),
            ),
          ),
        ],
      ),
    );
  }
}

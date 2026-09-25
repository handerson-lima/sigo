import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../lotes/domain/lote.dart';
import '../../domain/equipe.dart';

class ChamadaFiltrosHeader extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPickDate;
  final String? defaultLotId;
  final List<Lote> lotes;
  final ValueChanged<String?> onDefaultLotChanged;
  final String? selectedTeamId;
  final List<Equipe> equipes;
  final ValueChanged<String?> onTeamChanged;
  final bool isSaving;

  const ChamadaFiltrosHeader({
    super.key,
    required this.selectedDate,
    required this.onPickDate,
    required this.defaultLotId,
    required this.lotes,
    required this.onDefaultLotChanged,
    required this.selectedTeamId,
    required this.equipes,
    required this.onTeamChanged,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Garante que o valor defaultLotId existe nos lotes para evitar erro no Dropdown
    final safeDefaultLotId =
        (defaultLotId != null && lotes.any((l) => l.id == defaultLotId))
        ? defaultLotId
        : null;

    final safeSelectedTeamId =
        (selectedTeamId != null && equipes.any((e) => e.id == selectedTeamId))
        ? selectedTeamId
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Column(
        children: [
          Row(
            children: [
              // Data da chamada
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: isSaving ? null : onPickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data do Expediente',
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Lote Padrão
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  key: const Key('lote-padrao-dropdown'),
                  initialValue: safeDefaultLotId,
                  decoration: InputDecoration(
                    labelText: 'Lote Padrão',
                    prefixIcon: const Icon(Icons.home_work, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  hint: const Text('Selecionar lote...'),
                  items: [
                    ...lotes.map(
                      (l) => DropdownMenuItem(
                        value: l.id,
                        child: Text(l.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: isSaving ? null : onDefaultLotChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Seleção de Equipe
          DropdownButtonFormField<String?>(
            initialValue: safeSelectedTeamId,
            decoration: InputDecoration(
              labelText: 'Equipe de Trabalho',
              prefixIcon: const Icon(Icons.groups, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos os Colaboradores do Loteamento'),
              ),
              ...equipes.map(
                (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
              ),
            ],
            onChanged: isSaving ? null : onTeamChanged,
          ),
        ],
      ),
    );
  }
}

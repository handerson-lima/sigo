import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../obras/domain/obra.dart';
import '../../obras/domain/obra_member.dart';
import '../domain/construtora_member.dart';
import '../domain/membro.dart';
import 'membros_providers.dart';
import 'widgets/obra_vinculo_row.dart';
import 'widgets/role_chip.dart';

/// Detalhe do membro (8.3): somente leitura.
///
/// Responsivo: `BottomSheet` arrastável ~70% no mobile (`<800px`) ou
/// `Dialog` 480px no desktop (`>=800px`, breakpoint da Intent: 800 = desktop).
/// Sem escrita; ações dos epics 9/10 ficam desabilitadas.
class MemberDetalheSheet extends ConsumerWidget {
  final String construtoraId;
  final Membro membro;

  const MemberDetalheSheet({
    super.key,
    required this.construtoraId,
    required this.membro,
  });

  static Future<void> show({
    required BuildContext context,
    required String construtoraId,
    required Membro membro,
  }) {
    final sheet = MemberDetalheSheet(
      construtoraId: construtoraId,
      membro: membro,
    );
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;
    if (isDesktop) {
      return showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 480,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: SingleChildScrollView(child: sheet),
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: SingleChildScrollView(child: sheet),
        ),
      ),
    );
  }

  String get _titulo {
    final email = membro.email.trim();
    return email.isNotEmpty ? email : 'UID: ${membro.uid}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final key = (construtoraId: construtoraId, uid: membro.uid);
    final vinculoAsync = ref.watch(memberDetalheProvider(key));
    final meta = ref.watch(contagemObrasMetaProvider(construtoraId));
    final contagem =
        ref.watch(contagemObrasPorMembroProvider(construtoraId));
    final obrasVinculadas = ref.watch(obrasVinculadasProvider(key));

    final cargoLista = rotuloCargo(membro);
    final count = contagem[membro.uid] ?? 0;
    final vinculo = vinculoAsync.value;
    final cargoA11y = vinculo == null
        ? cargoLista
        : rotuloCargoFlags(isOwner: vinculo.isOwner, isAdmin: vinculo.isAdmin);
    final statusLabel =
        vinculo == null ? '' : ', ${rotuloStatusVinculo(vinculo.isActive)}';
    final obrasA11y = meta.carregando
        ? 'carregando obras'
        : (meta.erro && count == 0)
            ? 'erro ao carregar obras'
            : textoContagemObras(count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Semantics(
        label: '$_titulo, $cargoA11y, $obrasA11y$statusLabel',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detalhe de $_titulo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  autofocus: true,
                  icon: const Icon(Icons.close),
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Vínculo construtora',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _blocoVinculo(context, ref, key, vinculoAsync),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Obras vinculadas',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            _blocoObras(context, ref, meta, obrasVinculadas),
            const SizedBox(height: 16),
            Text(
              'Ações',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              label: 'Disponível em breve',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Disponível em breve',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: null,
                        child: const Text('Atribuir à obra'),
                      ),
                      OutlinedButton(
                        onPressed: null,
                        child: const Text('Trocar cargo'),
                      ),
                      OutlinedButton(
                        onPressed: null,
                        child: const Text('Desativar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blocoVinculo(
    BuildContext context,
    WidgetRef ref,
    MemberDetalheKey key,
    AsyncValue<ConstrutoraMember?> vinculoAsync,
  ) {
    return vinculoAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (err, stack) => _vinculoErro(context, ref, key),
      data: (member) {
        if (member == null) {
          return Text(
            'Membro não encontrado.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        final theme = Theme.of(context);
        final cargo = rotuloCargoFlags(
          isOwner: member.isOwner,
          isAdmin: member.isAdmin,
        );
        final status = rotuloStatusVinculo(member.isActive);
        final desde = 'Desde ${formatarJoinedAt(member.joinedAt)}';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ExcludeSemantics(
                  child: RoleChip(
                    papel: RoleChip.papelDe(member.isOwner, member.isAdmin),
                    label: cargo,
                  ),
                ),
                _statusChip(status, member.isActive),
              ],
            ),
            const SizedBox(height: 8),
            Text(desde, style: theme.textTheme.bodySmall),
            if (!member.isActive) ...[
              const SizedBox(height: 8),
              Semantics(
                label: 'Ative na construtora primeiro',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ative na construtora primeiro',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _vinculoErro(
    BuildContext context,
    WidgetRef ref,
    MemberDetalheKey key,
  ) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Não foi possível carregar o vínculo.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => ref.invalidate(memberDetalheProvider(key)),
            child: const Text('Tentar novamente'),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status, bool ativo) {
    final bg = ativo ? const Color(0xFFECFDF5) : Colors.grey.shade100;
    final border = ativo ? const Color(0xFF10B981) : Colors.grey.shade400;
    final ink = ativo ? const Color(0xFF065F46) : Colors.grey.shade700;
    final icon =
        ativo ? Icons.check_circle_outline : Icons.remove_circle_outline;
    return Semantics(
      label: status,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blocoObras(
    BuildContext context,
    WidgetRef ref,
    ({bool carregando, bool erro}) meta,
    List<({Obra obra, ObraMember vinculo})> obrasVinculadas,
  ) {
    final theme = Theme.of(context);

    if (meta.erro) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Não foi possível carregar as obras.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _retryObras(ref),
              child: const Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }
    if (meta.carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (obrasVinculadas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: ObraVinculoVazio(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in obrasVinculadas)
          ObraVinculoRow(obra: entry.obra, vinculo: entry.vinculo),
      ],
    );
  }

  void _retryObras(WidgetRef ref) {
    final conhecidas = <String>{};
    for (final origem in [
      ref.read(obrasAtivasProvider(construtoraId)).value,
      ref.read(obrasDaConstrutoraProvider(construtoraId)).value,
    ]) {
      for (final obra in origem ?? const <Obra>[]) {
        conhecidas.add(obra.id);
      }
    }
    ref.invalidate(obrasDaConstrutoraProvider(construtoraId));
    ref.invalidate(obrasAtivasProvider(construtoraId));
    for (final obraId in conhecidas) {
      ref.invalidate(
        obraMembersProvider((construtoraId: construtoraId, obraId: obraId)),
      );
    }
  }
}

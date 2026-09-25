import 'legacy_recovery.dart';

import 'package:flutter/material.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../../sync/operation_queue.dart';

class SyncQueueScreen extends StatelessWidget {
  final String construtoraId, obraId;
  const SyncQueueScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
  });
  static const actions = {
    'finalizeDiario': 'Diário de obra',
    'stockCommand': 'Movimentação de estoque',
    'payExpense': 'Pagamento',
  };
  static const states = {
    'pending': 'Salvo no dispositivo',
    'syncing': 'Sincronizando',
    'synced': 'Sincronizado',
    'failed': 'Falha no envio',
    'conflict': 'Revisão necessária',
    'authorization_rejected': 'Acesso removido',
  };
  @override
  Widget build(BuildContext context) => SigoLayout(
    title: 'Fila deste dispositivo',
    activeRoute: '/construtoras/$construtoraId/obra/$obraId/diarios',
    child: StreamBuilder<List<Map<String, dynamic>>>(
      stream: OperationQueue.instance.watch(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Não foi possível ler a fila. Verifique o espaço disponível.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!
            .where(
              (r) =>
                  r['payload']['construtoraId'] == construtoraId &&
                  (obraId.isEmpty || r['payload']['obraId'] == obraId),
            )
            .toList();
        return ListView(
          children: [
            if (obraId.isNotEmpty) LegacyRecovery(c: construtoraId, o: obraId),
            if (OperationQueue.instance.lastError != null)
              const ListTile(
                title: Text(
                  'A fila não pôde ser processada. Os registros salvos foram preservados.',
                ),
              ),
            if (rows.isEmpty)
              const ListTile(title: Text('Nenhuma operação local.')),
            ...rows.map((row) {
              final state = row['state'];
              final retry = ['pending', 'failed'].contains(state);
              return ListTile(
                title: Text(
                  '${actions[row['action']] ?? 'Operação'} · ${states[state] ?? 'Revisão necessária'}',
                ),
                subtitle: Text(
                  state == 'authorization_rejected'
                      ? 'Seu acesso foi removido. Os dados estão preservados para revisão.'
                      : state == 'conflict'
                      ? 'Confira os dados com a administração antes de reenviar.'
                      : state == 'failed'
                      ? 'Envio não confirmado. Verifique a conexão e os anexos.'
                      : '${(row['attachments'] as List).length} anexos preservados',
                ),
                onTap: row['error'] == null
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Detalhes do envio'),
                          content: SelectableText(row['error']),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      ),
                trailing: state == 'synced'
                    ? const Icon(Icons.cloud_done)
                    : retry
                    ? IconButton(
                        tooltip: 'Tentar enviar',
                        icon: const Icon(Icons.sync),
                        onPressed: () =>
                            OperationQueue.instance.sync(onlyKey: row['key']),
                      )
                    : null,
              );
            }),
          ],
        );
      },
    ),
  );
}

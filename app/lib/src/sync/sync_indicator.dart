import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'operation_queue.dart';
import 'sync_engine.dart';

/// Provider reativo da lista completa de itens da fila de operações do dispositivo.
final syncQueueStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return OperationQueue.instance.watch();
});

/// Modelo resumido do estado da sincronização para apresentação visual.
class SyncSummary {
  final bool isOnline;
  final SyncEngineStatus engineStatus;
  final int pendingCount;
  final int failedCount;
  final int alertCount; // conflict ou authorization_rejected
  final String? lastError;

  const SyncSummary({
    required this.isOnline,
    required this.engineStatus,
    required this.pendingCount,
    required this.failedCount,
    required this.alertCount,
    this.lastError,
  });

  bool get isSyncing => engineStatus == SyncEngineStatus.syncing;

  bool get hasAlert => alertCount > 0;
  bool get hasFailed => failedCount > 0 || engineStatus == SyncEngineStatus.error;
  bool get isOffline => !isOnline || engineStatus == SyncEngineStatus.offline;
  bool get isSynced => isOnline && !isSyncing && !hasAlert && !hasFailed && pendingCount == 0;
}

/// Provider computado que agrega o estado do SyncEngine e a fila local.
final syncSummaryProvider = Provider<SyncSummary>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final queueAsync = ref.watch(syncQueueStreamProvider);
  final queueItems = queueAsync.value ?? [];

  int pending = 0;
  int failed = 0;
  int alert = 0;

  for (final item in queueItems) {
    final state = item['state'] as String?;
    if (state == 'pending' || state == 'syncing') {
      pending++;
    } else if (state == 'failed') {
      failed++;
    } else if (state == 'conflict' || state == 'authorization_rejected') {
      alert++;
    }
  }

  return SyncSummary(
    isOnline: engine.isOnline,
    engineStatus: engine.status,
    pendingCount: pending,
    failedCount: failed,
    alertCount: alert,
    lastError: engine.lastError,
  );
});

/// Componente visual reativo que exibe o status de conectividade e sincronização no app bar.
class SyncIndicator extends ConsumerStatefulWidget {
  final String? construtoraId;
  final String? obraId;

  const SyncIndicator({
    super.key,
    this.construtoraId,
    this.obraId,
  });

  @override
  ConsumerState<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends ConsumerState<SyncIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(syncSummaryProvider);

    if (summary.isSyncing) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.reset();
      }
    }

    Color iconColor;
    Color bgColor;
    IconData iconData;
    String label;
    String tooltip;
    int? badgeCount;

    if (summary.hasAlert) {
      iconColor = Colors.red.shade700;
      bgColor = Colors.red.shade50;
      iconData = Icons.warning_amber_rounded;
      label = 'Atenção';
      tooltip = 'Atenção: registros com conflito ou acesso revogado';
      badgeCount = summary.alertCount;
    } else if (summary.hasFailed) {
      iconColor = Colors.deepOrange.shade700;
      bgColor = Colors.deepOrange.shade50;
      iconData = Icons.sync_problem;
      label = 'Falha';
      tooltip = 'Falha na sincronização';
      badgeCount = summary.failedCount > 0 ? summary.failedCount : null;
    } else if (summary.isOffline) {
      iconColor = summary.pendingCount > 0 ? Colors.amber.shade900 : Colors.grey.shade600;
      bgColor = summary.pendingCount > 0 ? Colors.amber.shade50 : Colors.grey.shade100;
      iconData = Icons.cloud_off;
      label = summary.pendingCount > 0 ? 'Offline (${summary.pendingCount})' : 'Offline';
      tooltip = summary.pendingCount > 0
          ? 'Offline: ${summary.pendingCount} registro(s) salvo(s) neste dispositivo'
          : 'Modo offline';
      badgeCount = summary.pendingCount > 0 ? summary.pendingCount : null;
    } else if (summary.isSyncing) {
      iconColor = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
      iconData = Icons.sync;
      label = 'Sincronizando...';
      tooltip = 'Sincronizando dados com o servidor...';
      badgeCount = summary.pendingCount > 0 ? summary.pendingCount : null;
    } else {
      iconColor = Colors.teal.shade700;
      bgColor = Colors.teal.shade50;
      iconData = Icons.cloud_done;
      label = 'Sincronizado';
      tooltip = 'Online: todos os registros estão sincronizados';
      badgeCount = null;
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: const Key('sync-indicator'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => showSyncStatusDialog(
          context: context,
          ref: ref,
          construtoraId: widget.construtoraId,
          obraId: widget.obraId,
        ),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              summary.isSyncing
                  ? RotationTransition(
                      turns: _rotationController,
                      child: Icon(
                        iconData,
                        key: const Key('sync-indicator-icon'),
                        size: 18,
                        color: iconColor,
                      ),
                    )
                  : Icon(
                      iconData,
                      key: const Key('sync-indicator-icon'),
                      size: 18,
                      color: iconColor,
                    ),
              const SizedBox(width: 6),
              Text(
                label,
                key: const Key('sync-indicator-label'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  key: const Key('sync-indicator-badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo de detalhes e controle da sincronização
Future<void> showSyncStatusDialog({
  required BuildContext context,
  required WidgetRef ref,
  String? construtoraId,
  String? obraId,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, _) {
          final summary = ref.watch(syncSummaryProvider);
          final engine = ref.watch(syncEngineProvider);

          String statusTitle;
          String statusDescription;
          Color statusColor;
          IconData statusIcon;

          if (summary.hasAlert) {
            statusTitle = 'Revisão Necessária';
            statusDescription =
                'Existem registros locais que requerem revisão administrativa ou tiveram permissão recusada. Os dados permanecem preservados no seu dispositivo.';
            statusColor = Colors.red.shade700;
            statusIcon = Icons.warning_amber_rounded;
          } else if (summary.hasFailed) {
            statusTitle = 'Falha no Envio';
            statusDescription =
                'Ocorreu uma falha na tentativa de envio dos dados. Verifique sua conexão e tente novamente.';
            statusColor = Colors.deepOrange.shade700;
            statusIcon = Icons.sync_problem;
          } else if (summary.isOffline) {
            statusTitle = 'Modo Offline';
            statusDescription = summary.pendingCount > 0
                ? 'Você está desconectado. Há ${summary.pendingCount} operação(ões) salva(s) localmente neste dispositivo e prontas para envio automático assim que a conexão retornar.'
                : 'Você está desconectado. As alterações feitas serão armazenadas com segurança no dispositivo.';
            statusColor = summary.pendingCount > 0 ? Colors.amber.shade900 : Colors.grey.shade700;
            statusIcon = Icons.cloud_off;
          } else if (summary.isSyncing) {
            statusTitle = 'Sincronizando';
            statusDescription =
                'Transmitindo registros locais para o servidor em segundo plano...';
            statusColor = Colors.blue.shade700;
            statusIcon = Icons.sync;
          } else {
            statusTitle = 'Tudo Sincronizado';
            statusDescription =
                'Sua conexão está ativa e todos os registros deste dispositivo estão sincronizados com a nuvem.';
            statusColor = Colors.teal.shade700;
            statusIcon = Icons.cloud_done;
          }

          return AlertDialog(
            key: const Key('sync-status-dialog'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusDescription,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildStatusRow(
                    label: 'Conexão',
                    value: summary.isOnline ? 'Online' : 'Offline',
                    valueColor: summary.isOnline ? Colors.teal.shade700 : Colors.grey.shade700,
                  ),
                  _buildStatusRow(
                    label: 'Operações locais pendentes',
                    value: '${summary.pendingCount}',
                  ),
                  if (summary.failedCount > 0)
                    _buildStatusRow(
                      label: 'Operações com falha',
                      value: '${summary.failedCount}',
                      valueColor: Colors.deepOrange.shade700,
                    ),
                  if (summary.alertCount > 0)
                    _buildStatusRow(
                      label: 'Requerem atenção',
                      value: '${summary.alertCount}',
                      valueColor: Colors.red.shade700,
                    ),
                  if (summary.lastError != null && summary.lastError!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Último aviso: ${summary.lastError}',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (construtoraId != null && construtoraId.isNotEmpty)
                TextButton.icon(
                  key: const Key('view-queue-button'),
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Ver fila local'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (obraId != null && obraId.isNotEmpty) {
                      context.go('/construtora/$construtoraId/obra/$obraId/diarios/sync');
                    } else {
                      context.go('/construtora/$construtoraId/sync');
                    }
                  },
                ),
              ElevatedButton.icon(
                key: const Key('sync-now-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sincronizar agora'),
                onPressed: summary.isSyncing
                    ? null
                    : () async {
                        Navigator.of(dialogContext).pop();
                        await engine.syncNow(
                          construtoraId: construtoraId,
                          obraId: obraId,
                        );
                      },
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildStatusRow({
  required String label,
  required String value,
  Color? valueColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    ),
  );
}

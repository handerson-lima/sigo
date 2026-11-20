import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/user_repository.dart';
import '../../etapas/domain/etapa.dart';
import '../../lotes/domain/lote.dart';
import '../../obras/presentation/current_permissions_provider.dart';
import '../../quadras/domain/quadra.dart';
import '../data/loteamento_repository.dart';
import '../domain/loteamento.dart';

/// Resumo agregado de métricas de um loteamento (quadras, lotes e progresso).
@immutable
class LoteamentoSummary {
  final int totalQuadras;
  final int totalLotes;
  final int lotesConcluidos;
  final int lotesEmAndamento;
  final int lotesPendentes;
  final int progressoMedio;

  const LoteamentoSummary({
    required this.totalQuadras,
    required this.totalLotes,
    required this.lotesConcluidos,
    required this.lotesEmAndamento,
    required this.lotesPendentes,
    required this.progressoMedio,
  });

  bool get isComplete =>
      totalLotes > 0 &&
      (progressoMedio >= 100 || lotesConcluidos >= totalLotes);

  bool get hasAnyActivity =>
      progressoMedio > 0 || lotesConcluidos > 0 || lotesEmAndamento > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoteamentoSummary &&
          runtimeType == other.runtimeType &&
          totalQuadras == other.totalQuadras &&
          totalLotes == other.totalLotes &&
          lotesConcluidos == other.lotesConcluidos &&
          lotesEmAndamento == other.lotesEmAndamento &&
          lotesPendentes == other.lotesPendentes &&
          progressoMedio == other.progressoMedio;

  @override
  int get hashCode => Object.hash(
    totalQuadras,
    totalLotes,
    lotesConcluidos,
    lotesEmAndamento,
    lotesPendentes,
    progressoMedio,
  );
}

/// Agrega em memória as métricas de quadras e lotes por `loteamentoId`.
Map<String, LoteamentoSummary> computeLoteamentoSummaries({
  required Iterable<Quadra> quadras,
  required Iterable<Lote> lotes,
}) {
  final quadraCounts = <String, int>{};
  final loteamentoIds = <String>{};

  for (final quadra in quadras) {
    final id = quadra.loteamentoId.trim();
    if (id.isEmpty) continue;
    loteamentoIds.add(id);
    quadraCounts[id] = (quadraCounts[id] ?? 0) + 1;
  }

  final lotesByLoteamento = <String, List<Lote>>{};
  for (final lote in lotes) {
    final id = lote.loteamentoId.trim();
    if (id.isEmpty) continue;
    loteamentoIds.add(id);
    lotesByLoteamento.putIfAbsent(id, () => <Lote>[]).add(lote);
  }

  final result = <String, LoteamentoSummary>{};
  for (final id in loteamentoIds) {
    final items = lotesByLoteamento[id] ?? const <Lote>[];
    var concluidos = 0;
    var emAndamento = 0;
    var pendentes = 0;
    var progressSum = 0;

    for (final lote in items) {
      final progress = lote.progressoPercentual.clamp(0, 100);
      progressSum += progress;

      final totalEtapas = lote.etapasTotalCount > 0 ? lote.etapasTotalCount : 5;
      final etapasConcluidas = lote.etapasConcluidasCount.clamp(0, totalEtapas);

      final isComplete = progress >= 100 || etapasConcluidas >= totalEtapas;
      final hasAnyActivity =
          progress > 0 ||
          etapasConcluidas > 0 ||
          lote.statusEtapasMap.values.any(
            (status) =>
                status == EtapaStatus.emAndamento ||
                status == EtapaStatus.concluida,
          );

      if (isComplete) {
        concluidos++;
      } else if (hasAnyActivity) {
        emAndamento++;
      } else {
        pendentes++;
      }
    }

    final totalLotes = items.length;
    final progressoMedio = totalLotes > 0
        ? (progressSum / totalLotes).round().clamp(0, 100)
        : 0;

    result[id] = LoteamentoSummary(
      totalQuadras: quadraCounts[id] ?? 0,
      totalLotes: totalLotes,
      lotesConcluidos: concluidos,
      lotesEmAndamento: emAndamento,
      lotesPendentes: pendentes,
      progressoMedio: progressoMedio,
    );
  }

  return result;
}

Quadra? _quadraFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
  final raw = doc.data();
  if (!doc.exists || raw == null) return null;
  try {
    final data = Map<String, dynamic>.from(raw);
    data['id'] ??= doc.id;
    return Quadra.fromJson(data).copyWith(id: doc.id);
  } catch (_) {
    return null;
  }
}

Lote? _loteFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
  final raw = doc.data();
  if (!doc.exists || raw == null) return null;
  try {
    final data = Map<String, dynamic>.from(raw);
    data['id'] ??= doc.id;
    return Lote.fromJson(data).copyWith(id: doc.id);
  } catch (_) {
    return null;
  }
}

Stream<Map<String, LoteamentoSummary>> _watchLoteamentoSummaries(
  FirebaseFirestore firestore,
  String construtoraId, {
  List<String>? scopedLoteamentoIds,
}) {
  late final StreamController<Map<String, LoteamentoSummary>> controller;
  final subs = <StreamSubscription<dynamic>>[];

  final quadrasByChunk = <int, List<Quadra>>{};
  final lotesByChunk = <int, List<Lote>>{};
  var expectedQuadraChunks = 0;
  var expectedLoteChunks = 0;
  final readyQuadraChunks = <int>{};
  final readyLoteChunks = <int>{};

  void emitIfReady() {
    if (controller.isClosed) return;
    if (readyQuadraChunks.length < expectedQuadraChunks ||
        readyLoteChunks.length < expectedLoteChunks) {
      return;
    }
    final allQuadras = <String, Quadra>{};
    for (final list in quadrasByChunk.values) {
      for (final q in list) {
        allQuadras[q.id] = q;
      }
    }
    final allLotes = <String, Lote>{};
    for (final list in lotesByChunk.values) {
      for (final l in list) {
        allLotes[l.id] = l;
      }
    }
    controller.add(
      computeLoteamentoSummaries(
        quadras: allQuadras.values,
        lotes: allLotes.values,
      ),
    );
  }

  List<List<String>> buildChunks(List<String> ids) {
    const chunkSize = 10;
    return [
      for (var i = 0; i < ids.length; i += chunkSize)
        ids.sublist(i, i + chunkSize < ids.length ? i + chunkSize : ids.length),
    ];
  }

  controller = StreamController<Map<String, LoteamentoSummary>>(
    onListen: () {
      if (scopedLoteamentoIds == null) {
        expectedQuadraChunks = 1;
        expectedLoteChunks = 1;
        subs.add(
          firestore
              .collection('quadras')
              .where('construtoraId', isEqualTo: construtoraId)
              .snapshots()
              .map(
                (snap) => snap.docs
                    .map(_quadraFromSnapshot)
                    .whereType<Quadra>()
                    .toList(),
              )
              .listen(
                (quadras) {
                  quadrasByChunk[0] = quadras;
                  readyQuadraChunks.add(0);
                  emitIfReady();
                },
                onError: (_, _) {
                  quadrasByChunk[0] ??= const [];
                  readyQuadraChunks.add(0);
                  emitIfReady();
                },
              ),
        );
        subs.add(
          firestore
              .collection('lotes')
              .where('construtoraId', isEqualTo: construtoraId)
              .snapshots()
              .map(
                (snap) =>
                    snap.docs.map(_loteFromSnapshot).whereType<Lote>().toList(),
              )
              .listen(
                (lotes) {
                  lotesByChunk[0] = lotes;
                  readyLoteChunks.add(0);
                  emitIfReady();
                },
                onError: (_, _) {
                  lotesByChunk[0] ??= const [];
                  readyLoteChunks.add(0);
                  emitIfReady();
                },
              ),
        );
        return;
      }

      if (scopedLoteamentoIds.isEmpty) {
        controller.add(const <String, LoteamentoSummary>{});
        return;
      }

      final chunks = buildChunks(scopedLoteamentoIds);
      expectedQuadraChunks = chunks.length;
      expectedLoteChunks = chunks.length;
      for (var i = 0; i < chunks.length; i++) {
        final chunkIndex = i;
        final chunk = chunks[chunkIndex];
        subs.add(
          firestore
              .collection('quadras')
              .where('construtoraId', isEqualTo: construtoraId)
              .where('loteamentoId', whereIn: chunk)
              .snapshots()
              .map(
                (snap) => snap.docs
                    .map(_quadraFromSnapshot)
                    .whereType<Quadra>()
                    .toList(),
              )
              .listen(
                (quadras) {
                  quadrasByChunk[chunkIndex] = quadras;
                  readyQuadraChunks.add(chunkIndex);
                  emitIfReady();
                },
                onError: (_, _) {
                  quadrasByChunk[chunkIndex] ??= const [];
                  readyQuadraChunks.add(chunkIndex);
                  emitIfReady();
                },
              ),
        );
        subs.add(
          firestore
              .collection('lotes')
              .where('construtoraId', isEqualTo: construtoraId)
              .where('loteamentoId', whereIn: chunk)
              .snapshots()
              .map(
                (snap) =>
                    snap.docs.map(_loteFromSnapshot).whereType<Lote>().toList(),
              )
              .listen(
                (lotes) {
                  lotesByChunk[chunkIndex] = lotes;
                  readyLoteChunks.add(chunkIndex);
                  emitIfReady();
                },
                onError: (_, _) {
                  lotesByChunk[chunkIndex] ??= const [];
                  readyLoteChunks.add(chunkIndex);
                  emitIfReady();
                },
              ),
        );
      }
    },
    onCancel: () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    },
  );

  return controller.stream;
}

/// Fornece o mapa `loteamentoId -> LoteamentoSummary` em tempo real para uma
/// construtora, respeitando o escopo vinculado do usuário e com fallback seguro
/// quando o Firebase não está inicializado.
final loteamentoSummaryMapProvider = StreamProvider.autoDispose
    .family<Map<String, LoteamentoSummary>, String>((ref, construtoraId) {
      if (Firebase.apps.isEmpty) {
        return Stream.value(const <String, LoteamentoSummary>{});
      }

      final isDev = ref.watch(trustedDevProvider).value == true;
      final cm = ref.watch(construtoraPermissionProvider(construtoraId)).value;
      if (isDev || hasGlobalLotesAccess(cm)) {
        try {
          return _watchLoteamentoSummaries(
            FirebaseFirestore.instance,
            construtoraId,
          );
        } catch (_) {
          return Stream.value(const <String, LoteamentoSummary>{});
        }
      }

      if (cm?['isActive'] != true) {
        return Stream.value(const <String, LoteamentoSummary>{});
      }

      final loteamentosAsync = ref.watch(
        watchLoteamentosProvider((construtoraId: construtoraId)),
      );
      if (loteamentosAsync.isLoading && !loteamentosAsync.hasValue) {
        return const Stream.empty();
      }
      final ids =
          (loteamentosAsync.value ?? const <Loteamento>[])
              .map((l) => l.id.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (ids.isEmpty) {
        return Stream.value(const <String, LoteamentoSummary>{});
      }

      try {
        return _watchLoteamentoSummaries(
          FirebaseFirestore.instance,
          construtoraId,
          scopedLoteamentoIds: ids,
        );
      } catch (_) {
        return Stream.value(const <String, LoteamentoSummary>{});
      }
    });

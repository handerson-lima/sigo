import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../etapas/domain/etapa.dart';
import '../../lotes/domain/lote.dart';
import '../../quadras/domain/quadra.dart';

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
  String construtoraId,
) {
  late final StreamController<Map<String, LoteamentoSummary>> controller;
  StreamSubscription<List<Quadra>>? quadrasSub;
  StreamSubscription<List<Lote>>? lotesSub;

  List<Quadra>? latestQuadras;
  List<Lote>? latestLotes;

  void emitIfReady() {
    if (controller.isClosed) return;
    if (latestQuadras == null || latestLotes == null) return;
    controller.add(
      computeLoteamentoSummaries(
        quadras: latestQuadras!,
        lotes: latestLotes!,
      ),
    );
  }

  controller = StreamController<Map<String, LoteamentoSummary>>(
    onListen: () {
      quadrasSub = firestore
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
              latestQuadras = quadras;
              emitIfReady();
            },
            onError: (_, _) {
              latestQuadras ??= const [];
              emitIfReady();
            },
          );

      lotesSub = firestore
          .collection('lotes')
          .where('construtoraId', isEqualTo: construtoraId)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map(_loteFromSnapshot).whereType<Lote>().toList(),
          )
          .listen(
            (lotes) {
              latestLotes = lotes;
              emitIfReady();
            },
            onError: (_, _) {
              latestLotes ??= const [];
              emitIfReady();
            },
          );
    },
    onCancel: () async {
      await quadrasSub?.cancel();
      await lotesSub?.cancel();
    },
  );

  return controller.stream;
}

/// Fornece o mapa `loteamentoId -> LoteamentoSummary` em tempo real para uma
/// construtora, com fallback seguro quando o Firebase não está inicializado.
final loteamentoSummaryMapProvider = StreamProvider.autoDispose
    .family<Map<String, LoteamentoSummary>, String>((ref, construtoraId) {
      if (Firebase.apps.isEmpty) {
        return Stream.value(const <String, LoteamentoSummary>{});
      }
      try {
        return _watchLoteamentoSummaries(
          FirebaseFirestore.instance,
          construtoraId,
        );
      } catch (_) {
        return Stream.value(const <String, LoteamentoSummary>{});
      }
    });

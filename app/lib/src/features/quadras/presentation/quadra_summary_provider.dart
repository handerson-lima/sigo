import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../etapas/domain/etapa.dart';
import '../data/quadra_repository.dart';

/// Resumo agregado dos lotes pertencentes a uma quadra.
class QuadraSummary {
  final int totalLotes;
  final int concluidos;
  final int emAndamento;
  final int pendentes;
  final int progressoMedio;

  const QuadraSummary({
    required this.totalLotes,
    required this.concluidos,
    required this.emAndamento,
    required this.pendentes,
    required this.progressoMedio,
  });

  static const empty = QuadraSummary(
    totalLotes: 0,
    concluidos: 0,
    emAndamento: 0,
    pendentes: 0,
    progressoMedio: 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuadraSummary &&
          runtimeType == other.runtimeType &&
          totalLotes == other.totalLotes &&
          concluidos == other.concluidos &&
          emAndamento == other.emAndamento &&
          pendentes == other.pendentes &&
          progressoMedio == other.progressoMedio;

  @override
  int get hashCode => Object.hash(
    totalLotes,
    concluidos,
    emAndamento,
    pendentes,
    progressoMedio,
  );
}

class _QuadraAccumulator {
  int totalLotes = 0;
  int concluidos = 0;
  int emAndamento = 0;
  int pendentes = 0;
  int somaProgresso = 0;

  QuadraSummary toSummary() {
    final media = totalLotes == 0
        ? 0
        : (somaProgresso / totalLotes).round().clamp(0, 100);
    return QuadraSummary(
      totalLotes: totalLotes,
      concluidos: concluidos,
      emAndamento: emAndamento,
      pendentes: pendentes,
      progressoMedio: media,
    );
  }
}

/// Agrega documentos brutos da coleção `lotes` em memória por `quadraId`.
Map<String, QuadraSummary> aggregateQuadraSummaries(
  Iterable<Map<String, dynamic>> loteDocs,
) {
  final accByQuadra = <String, _QuadraAccumulator>{};

  for (final doc in loteDocs) {
    final quadraId = (doc['quadraId']?.toString() ?? '').trim();
    if (quadraId.isEmpty) continue;

    final rawProgress = doc['progressoPercentual'];
    final progress = rawProgress is num && rawProgress.isFinite
        ? rawProgress.round().clamp(0, 100)
        : 0;

    final rawTotalEtapas = doc['etapasTotalCount'];
    final totalEtapas =
        rawTotalEtapas is num &&
            rawTotalEtapas.isFinite &&
            rawTotalEtapas.round() > 0
        ? rawTotalEtapas.round()
        : 5;

    final rawConcluidas = doc['etapasConcluidasCount'];
    final concluidas = rawConcluidas is num && rawConcluidas.isFinite
        ? rawConcluidas.round().clamp(0, totalEtapas)
        : 0;

    var hasEtapaActivity = false;
    final rawStatusMap = doc['statusEtapasMap'];
    if (rawStatusMap is Map) {
      for (final value in rawStatusMap.values) {
        final status = value?.toString().trim();
        if (status == EtapaStatus.emAndamento ||
            status == EtapaStatus.concluida) {
          hasEtapaActivity = true;
          break;
        }
      }
    }

    final isComplete = progress >= 100 || concluidas >= totalEtapas;
    final hasAnyActivity = progress > 0 || concluidas > 0 || hasEtapaActivity;

    final acc = accByQuadra.putIfAbsent(quadraId, _QuadraAccumulator.new);
    acc.totalLotes++;
    acc.somaProgresso += isComplete ? 100 : progress;

    if (isComplete) {
      acc.concluidos++;
    } else if (hasAnyActivity) {
      acc.emAndamento++;
    } else {
      acc.pendentes++;
    }
  }

  return accByQuadra.map((id, acc) => MapEntry(id, acc.toSummary()));
}

/// Assina os lotes de um loteamento (uma única query) e agrupa as métricas por quadraId.
/// Retorna mapa vazio com segurança caso o Firebase não esteja inicializado (ex.: testes de widget).
final quadraSummaryMapProvider = StreamProvider.autoDispose
    .family<Map<String, QuadraSummary>, QuadraParams>((ref, params) {
      if (Firebase.apps.isEmpty) {
        return Stream.value(const <String, QuadraSummary>{});
      }
      try {
        return FirebaseFirestore.instance
            .collection('lotes')
            .where('construtoraId', isEqualTo: params.construtoraId)
            .where('loteamentoId', isEqualTo: params.loteamentoId)
            .snapshots()
            .map(
              (snapshot) => aggregateQuadraSummaries(
                snapshot.docs.map((doc) => doc.data()),
              ),
            );
      } catch (_) {
        return Stream.value(const <String, QuadraSummary>{});
      }
    });

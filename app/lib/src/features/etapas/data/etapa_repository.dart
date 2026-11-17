import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts.dart';
import '../domain/etapa.dart';

final etapaRepositoryProvider = Provider<EtapaRepository>((ref) {
  return EtapaRepository(FirebaseFirestore.instance);
});

class EtapaRepository {
  final FirebaseFirestore _firestore;

  EtapaRepository(this._firestore);

  static CollectionReference<Etapa> etapasCollection(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('etapas')
      .withConverter<Etapa>(
        fromFirestore: (snapshot, _) => Etapa.fromJson(snapshot.data()!),
        toFirestore: (etapa, _) => etapa.toJson(),
      );

  CollectionReference<Etapa> _etapasRef() => etapasCollection(_firestore);

  Stream<List<Etapa>> watchEtapas(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
  ) {
    return _etapasRef()
        .where('construtoraId', isEqualTo: construtoraId)
        .where('loteamentoId', isEqualTo: loteamentoId)
        .where('quadraId', isEqualTo: quadraId)
        .where('loteId', isEqualTo: loteId)
        .orderBy('ordem')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createEtapa(Etapa etapa) async {
    final docRef = _etapasRef().doc(etapa.id);
    await docRef.set(etapa);
  }

  Future<void> assignResponsavel(String etapaId, String? responsavelId) async {
    await _etapasRef().doc(etapaId).update({'responsavelId': responsavelId});
  }

  static List<Etapa> buildDefaultEtapas({
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
    required String Function(EtapaTipo) newId,
    required DateTime now,
  }) {
    return EtapaTipo.values
        .map(
          (tipo) => Etapa(
            id: newId(tipo),
            construtoraId: construtoraId,
            loteamentoId: loteamentoId,
            quadraId: quadraId,
            loteId: loteId,
            nome: tipo.label,
            ordem: tipo.ordem,
            status: EtapaStatus.pendente,
            percentual: 0,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();
  }

  static void appendDefaultEtapasWrites({
    required FirebaseFirestore firestore,
    required List<FirestoreBatchWrite> operations,
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
    required DateTime now,
  }) {
    final etapasRef = etapasCollection(firestore);
    final etapas = buildDefaultEtapas(
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      loteId: loteId,
      newId: (tipo) => '${loteId}_${tipo.name}',
      now: now,
    );
    for (final etapa in etapas) {
      operations.add((batch) {
        batch.set(etapasRef.doc(etapa.id), etapa, SetOptions(merge: true));
      });
    }
  }

  Future<void> createDefaultEtapas({
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
    WriteBatch? batch,
  }) async {
    final etapasDefault = buildDefaultEtapas(
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      loteId: loteId,
      newId: (tipo) => '${loteId}_${tipo.name}',
      now: DateTime.now(),
    );

    final localBatch = batch ?? _firestore.batch();
    for (final etapa in etapasDefault) {
      localBatch.set(
        _etapasRef().doc(etapa.id),
        etapa,
        SetOptions(merge: true),
      );
    }

    if (batch == null) {
      await localBatch.commit();
    }
  }

  Future<void> updateEtapaProgresso({
    required String loteId,
    required String etapaId,
    required String status,
    int? percentual,
    String? construtoraId,
    String? loteamentoId,
    String? quadraId,
    EtapaTipo? tipo,
    WriteBatch? batch,
  }) async {
    if (!EtapaStatus.values.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Status de etapa inválido');
    }

    final effectivePercentual = switch (status) {
      EtapaStatus.pendente => 0,
      EtapaStatus.concluida => 100,
      EtapaStatus.emAndamento => (percentual ?? 50).clamp(0, 100),
      _ => 0,
    };

    final loteDocRef = _firestore.collection('lotes').doc(loteId);
    final loteSnap = await loteDocRef.get();
    if (!loteSnap.exists || loteSnap.data() == null) {
      throw StateError('Lote $loteId não encontrado');
    }
    final loteData = loteSnap.data()!;
    final resolvedConstrutoraId =
        construtoraId ?? (loteData['construtoraId'] as String);
    final resolvedLoteamentoId =
        loteamentoId ?? (loteData['loteamentoId'] as String);
    final resolvedQuadraId = quadraId ?? (loteData['quadraId'] as String);

    final etapasSnap = await _etapasRef()
        .where('construtoraId', isEqualTo: resolvedConstrutoraId)
        .where('loteId', isEqualTo: loteId)
        .get();

    final existingById = <String, Etapa>{};
    final byTipo = <EtapaTipo, Etapa>{};
    for (final doc in etapasSnap.docs) {
      final etapa = doc.data();
      existingById[etapa.id] = etapa;
      final resolved = etapa.tipo;
      if (resolved != null) {
        byTipo[resolved] = etapa;
      }
    }

    final existingTarget = existingById[etapaId];
    final targetTipo =
        tipo ?? existingTarget?.tipo ?? resolveEtapaTipo(id: etapaId);
    if (targetTipo == null) {
      throw ArgumentError.value(
        etapaId,
        'etapaId',
        'Não foi possível resolver o EtapaTipo da etapa',
      );
    }

    final now = DateTime.now();
    final createdTipos = <EtapaTipo>{};
    for (final t in EtapaTipo.values) {
      if (!byTipo.containsKey(t)) {
        final newId = (t == targetTipo && existingTarget == null)
            ? etapaId
            : '${loteId}_${t.name}';
        byTipo[t] = Etapa(
          id: newId,
          construtoraId: resolvedConstrutoraId,
          loteamentoId: resolvedLoteamentoId,
          quadraId: resolvedQuadraId,
          loteId: loteId,
          nome: t.label,
          ordem: t.ordem,
          status: EtapaStatus.pendente,
          percentual: 0,
          createdAt: now,
          updatedAt: now,
        );
        createdTipos.add(t);
      }
    }

    final targetBefore = existingTarget ?? byTipo[targetTipo]!;
    final updatedTarget = targetBefore.copyWith(
      status: status,
      percentual: effectivePercentual,
      updatedAt: now,
    );
    byTipo[targetTipo] = updatedTarget;

    final localBatch = batch ?? _firestore.batch();

    for (final createdTipo in createdTipos) {
      final createdEtapa = byTipo[createdTipo]!;
      localBatch.set(_etapasRef().doc(createdEtapa.id), createdEtapa);
    }

    if (!createdTipos.contains(targetTipo)) {
      localBatch.update(_firestore.collection('etapas').doc(targetBefore.id), {
        'status': status,
        'percentual': effectivePercentual,
        'updatedAt': now.toIso8601String(),
      });
    }

    final sumPercentuais = byTipo.values.fold<int>(
      0,
      (acc, etapa) => acc + etapa.percentual,
    );
    final progressoPercentual =
        (sumPercentuais / EtapaTipo.values.length).round().clamp(0, 100);
    final etapasConcluidasCount = byTipo.values
        .where((etapa) => etapa.status == EtapaStatus.concluida)
        .length;
    final statusEtapasMap = <String, String>{
      for (final t in EtapaTipo.values) t.name: byTipo[t]!.status,
    };

    localBatch.update(loteDocRef, {
      'progressoPercentual': progressoPercentual,
      'etapasConcluidasCount': etapasConcluidasCount,
      'etapasTotalCount': EtapaTipo.values.length,
      'statusEtapasMap': statusEtapasMap,
      'updatedAt': now.toIso8601String(),
    });

    if (batch == null) {
      await localBatch.commit();
    }
  }
}

typedef EtapaParams = ({
  String construtoraId,
  String loteamentoId,
  String quadraId,
  String loteId,
});

final watchEtapasProvider = StreamProvider.family<List<Etapa>, EtapaParams>((
  ref,
  params,
) {
  final repo = ref.watch(etapaRepositoryProvider);
  return repo.watchEtapas(
    params.construtoraId,
    params.loteamentoId,
    params.quadraId,
    params.loteId,
  );
});

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
        fromFirestore: (snapshot, _) {
          final data = Map<String, dynamic>.from(snapshot.data()!);
          data['id'] ??= snapshot.id;
          return Etapa.fromJson(data).copyWith(id: snapshot.id);
        },
        toFirestore: (etapa, _) => etapa.toJson(),
      );

  Etapa? _etapaFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final raw = doc.data();
    if (!doc.exists || raw == null) return null;
    final data = Map<String, dynamic>.from(raw);
    data['id'] ??= doc.id;
    return Etapa.fromJson(data).copyWith(id: doc.id);
  }

  Stream<List<Etapa>> watchEtapas(
    String construtoraId,
    String loteamentoId,
    String quadraId,
    String loteId,
  ) {
    return _firestore
        .collection('etapas')
        .where('construtoraId', isEqualTo: construtoraId)
        .where('loteamentoId', isEqualTo: loteamentoId)
        .where('quadraId', isEqualTo: quadraId)
        .where('loteId', isEqualTo: loteId)
        .orderBy('ordem')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(_etapaFromSnapshot)
              .whereType<Etapa>()
              .toList(),
        );
  }

  Future<void> createEtapa(Etapa etapa) async {
    final docRef = _firestore.collection('etapas').doc(etapa.id);
    await docRef.set(etapa.toJson());
  }

  Future<void> assignResponsavel(String etapaId, String? responsavelId) async {
    await _firestore.collection('etapas').doc(etapaId).update({
      'responsavelId': responsavelId,
    });
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
    final etapasRawRef = firestore.collection('etapas');
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
        batch.set(etapasRawRef.doc(etapa.id), etapa.toJson(), SetOptions(merge: true));
      });
    }
  }

  void addDefaultEtapasToBatch({
    required WriteBatch batch,
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
    required DateTime now,
  }) {
    final etapasDefault = buildDefaultEtapas(
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      loteId: loteId,
      newId: (tipo) => '${loteId}_${tipo.name}',
      now: now,
    );
    final etapasRawRef = _firestore.collection('etapas');
    for (final etapa in etapasDefault) {
      batch.set(etapasRawRef.doc(etapa.id), etapa.toJson(), SetOptions(merge: true));
    }
  }

  Future<void> createDefaultEtapas({
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
    WriteBatch? batch,
  }) async {
    final now = DateTime.now();
    if (batch != null) {
      addDefaultEtapasToBatch(
        batch: batch,
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
        loteId: loteId,
        now: now,
      );
      return;
    }

    final existingSnap = await _firestore
        .collection('etapas')
        .where('construtoraId', isEqualTo: construtoraId)
        .where('loteId', isEqualTo: loteId)
        .get();
    final existingIds = <String>{};
    final existingTipos = <EtapaTipo>{};
    for (final doc in existingSnap.docs) {
      final etapa = _etapaFromSnapshot(doc);
      if (etapa == null) continue;
      existingIds.add(etapa.id);
      final resolved = etapa.tipo;
      if (resolved != null) {
        existingTipos.add(resolved);
      }
    }

    final etapasDefault = buildDefaultEtapas(
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      loteId: loteId,
      newId: (tipo) => '${loteId}_${tipo.name}',
      now: now,
    );

    final missing = etapasDefault
        .where(
          (etapa) =>
              !existingIds.contains(etapa.id) &&
              (etapa.tipo == null || !existingTipos.contains(etapa.tipo)),
        )
        .toList();
    if (missing.isEmpty) return;

    final localBatch = _firestore.batch();
    final etapasRawRef = _firestore.collection('etapas');
    for (final etapa in missing) {
      localBatch.set(
        etapasRawRef.doc(etapa.id),
        etapa.toJson(),
        SetOptions(merge: true),
      );
    }
    await localBatch.commit();
  }

  void _validateFk(
    String? passed,
    String actual,
    String fieldName,
    String loteId,
  ) {
    if (passed != null && passed != actual) {
      throw ArgumentError.value(
        passed,
        fieldName,
        '$fieldName não corresponde ao lote $loteId',
      );
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
    if (loteId.trim().isEmpty) {
      throw ArgumentError.value(loteId, 'loteId', 'ID do lote inválido');
    }
    if (etapaId.trim().isEmpty) {
      throw ArgumentError.value(etapaId, 'etapaId', 'ID da etapa inválido');
    }
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
    final preLoteSnap = await loteDocRef.get();
    final preLoteData = preLoteSnap.data();
    if (!preLoteSnap.exists || preLoteData == null) {
      throw StateError('Lote $loteId não encontrado');
    }
    final preConstrutoraId = preLoteData['construtoraId'] as String;
    final preLoteamentoId = preLoteData['loteamentoId'] as String;
    final preQuadraId = preLoteData['quadraId'] as String;
    _validateFk(construtoraId, preConstrutoraId, 'construtoraId', loteId);
    _validateFk(loteamentoId, preLoteamentoId, 'loteamentoId', loteId);
    _validateFk(quadraId, preQuadraId, 'quadraId', loteId);

    final preEtapasSnap = await _firestore
        .collection('etapas')
        .where('construtoraId', isEqualTo: preConstrutoraId)
        .where('loteId', isEqualTo: loteId)
        .get();

    void applyUpdate({
      required Map<String, dynamic> loteData,
      required Map<String, Etapa> allDocsById,
      required void Function(String id, Etapa etapa) setEtapa,
      required void Function(String id, Map<String, dynamic> updates)
      updateEtapa,
      required void Function(Map<String, dynamic> updates) updateLote,
    }) {
      final resolvedConstrutoraId = loteData['construtoraId'] as String;
      final resolvedLoteamentoId = loteData['loteamentoId'] as String;
      final resolvedQuadraId = loteData['quadraId'] as String;
      _validateFk(
        construtoraId,
        resolvedConstrutoraId,
        'construtoraId',
        loteId,
      );
      _validateFk(loteamentoId, resolvedLoteamentoId, 'loteamentoId', loteId);
      _validateFk(quadraId, resolvedQuadraId, 'quadraId', loteId);

      final directTarget = allDocsById[etapaId];
      if (directTarget != null &&
          (directTarget.loteId != loteId ||
              directTarget.construtoraId != resolvedConstrutoraId ||
              directTarget.loteamentoId != resolvedLoteamentoId ||
              directTarget.quadraId != resolvedQuadraId)) {
        throw ArgumentError.value(
          etapaId,
          'etapaId',
          'Etapa $etapaId pertence a outro lote',
        );
      }

      final existingById = <String, Etapa>{};
      final byTipo = <EtapaTipo, Etapa>{};
      for (final etapa in allDocsById.values) {
        if (etapa.loteId != loteId) continue;
        existingById[etapa.id] = etapa;
        final resolved = etapa.tipo;
        if (resolved != null) {
          byTipo[resolved] = etapa;
        }
      }

      final existingTarget = existingById[etapaId];
      final idTipo = resolveEtapaTipo(id: etapaId);
      final existingTipo = existingTarget?.tipo;
      final targetTipo = tipo ?? existingTipo ?? idTipo;
      if (targetTipo == null) {
        throw ArgumentError.value(
          etapaId,
          'etapaId',
          'Não foi possível resolver o EtapaTipo da etapa',
        );
      }
      if (existingTipo != null && existingTipo != targetTipo) {
        throw ArgumentError.value(
          etapaId,
          'etapaId',
          'Etapa $etapaId não corresponde ao tipo ${targetTipo.name}',
        );
      }
      if (idTipo != null && idTipo != targetTipo) {
        throw ArgumentError.value(
          etapaId,
          'etapaId',
          'Etapa $etapaId não corresponde ao tipo ${targetTipo.name}',
        );
      }
      if (existingTarget == null) {
        if (byTipo.containsKey(targetTipo)) {
          throw ArgumentError.value(
            etapaId,
            'etapaId',
            'Etapa $etapaId não pertence ao lote $loteId',
          );
        }
        if (idTipo != null &&
            etapaId != '${loteId}_${idTipo.name}' &&
            etapaId != idTipo.name) {
          throw ArgumentError.value(
            etapaId,
            'etapaId',
            'Etapa $etapaId não pertence ao lote $loteId',
          );
        }
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

      for (final createdTipo in createdTipos) {
        final createdEtapa = byTipo[createdTipo]!;
        setEtapa(createdEtapa.id, createdEtapa);
      }

      if (!createdTipos.contains(targetTipo)) {
        updateEtapa(targetBefore.id, {
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

      updateLote({
        'progressoPercentual': progressoPercentual,
        'etapasConcluidasCount': etapasConcluidasCount,
        'etapasTotalCount': EtapaTipo.values.length,
        'statusEtapasMap': statusEtapasMap,
        'updatedAt': now.toIso8601String(),
      });
    }

    if (batch != null) {
      final allDocsById = <String, Etapa>{};
      for (final doc in preEtapasSnap.docs) {
        final etapa = _etapaFromSnapshot(doc);
        if (etapa != null) {
          allDocsById[doc.id] = etapa;
        }
      }
      if (!allDocsById.containsKey(etapaId)) {
        final directSnap = await _firestore
            .collection('etapas')
            .doc(etapaId)
            .get();
        final directEtapa = _etapaFromSnapshot(directSnap);
        if (directEtapa != null) {
          allDocsById[etapaId] = directEtapa;
        }
      }
      applyUpdate(
        loteData: preLoteData,
        allDocsById: allDocsById,
        setEtapa: (id, etapa) =>
            batch.set(_firestore.collection('etapas').doc(id), etapa.toJson()),
        updateEtapa: (id, updates) =>
            batch.update(_firestore.collection('etapas').doc(id), updates),
        updateLote: (updates) => batch.update(loteDocRef, updates),
      );
      return;
    }

    final candidateIds = <String>{
      ...preEtapasSnap.docs.map((d) => d.id),
      for (final t in EtapaTipo.values) '${loteId}_${t.name}',
      etapaId,
    };

    await _firestore.runTransaction((transaction) async {
      final txLoteSnap = await transaction.get(loteDocRef);
      final txLoteData = txLoteSnap.data();
      if (!txLoteSnap.exists || txLoteData == null) {
        throw StateError('Lote $loteId não encontrado');
      }

      final allDocsById = <String, Etapa>{};
      for (final id in candidateIds) {
        final snap = await transaction.get(
          _firestore.collection('etapas').doc(id),
        );
        final etapa = _etapaFromSnapshot(snap);
        if (etapa != null) {
          allDocsById[id] = etapa;
        }
      }

      applyUpdate(
        loteData: txLoteData,
        allDocsById: allDocsById,
        setEtapa: (id, etapa) => transaction.set(
          _firestore.collection('etapas').doc(id),
          etapa.toJson(),
        ),
        updateEtapa: (id, updates) => transaction.update(
          _firestore.collection('etapas').doc(id),
          updates,
        ),
        updateLote: (updates) => transaction.update(loteDocRef, updates),
      );
    });
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

import '../../../sync/read_cache.dart';
import '../../../sync/operation_queue.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/material.dart'
    as mat; // alias para evitar conflito com flutter/material
import '../domain/movimentacao.dart';

final almoxarifadoRepositoryProvider = Provider<AlmoxarifadoRepository>((ref) {
  return AlmoxarifadoRepository(FirebaseFirestore.instance);
});

class AlmoxarifadoRepository {
  final FirebaseFirestore? _firestore;

  AlmoxarifadoRepository([this._firestore]);

  CollectionReference<mat.Material> _materiaisRef(String construtoraId) =>
      (_firestore ?? FirebaseFirestore.instance)
          .collection('construtoras')
          .doc(construtoraId)
          .collection('materiais')
          .withConverter<mat.Material>(
            fromFirestore: (snapshot, _) =>
                mat.Material.fromJson(snapshot.data()!),
            toFirestore: (material, _) => material.toJson(),
          );

  Stream<List<mat.Material>> watchMateriais(String construtoraId) => cachedList(
    'construtoras/$construtoraId/estoque/materiais',
    _livewatchMateriais(construtoraId),
    (m) => m.toJson(),
    (d) => mat.Material.fromJson(Map<String, dynamic>.from(d)),
  );

  Stream<List<mat.Material>> _livewatchMateriais(String construtoraId) {
    return _materiaisRef(construtoraId)
        .snapshots(includeMetadataChanges: true)
        .where((s) => !s.metadata.isFromCache)
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  Future<void> createMaterial(mat.Material material) async {
    if (material.currentQuantity != 0 ||
        (material.quantityUnits != null && material.quantityUnits != 0)) {
      throw ArgumentError('Material novo inicia com saldo zero');
    }
    final m = mat.Material(
      id: material.id,
      construtoraId: material.construtoraId,
      name: material.name,
      unit: material.unit,
      currentQuantity: 0.0,
      quantityUnits: 0,
      quantityScale: material.quantityScale ?? 1000,
      schemaVersion: material.schemaVersion ?? 2,
    );
    await _materiaisRef(m.construtoraId).doc(m.id).set(m);
  }

  /// Registra uma movimentação e atualiza o saldo usando Transaction para garantir consistência
  Future<void> registrarMovimentacao(
    String construtoraId,
    Movimentacao mov,
  ) async {
    await OperationQueue.instance.enqueue('stockCommand', {
      'operationId': mov.id,
      'construtoraId': construtoraId,
      'materialId': mov.materialId,
      'type': mov.commandType ?? mov.type.name,
      'quantity': mov.quantity,
      if (mov.quantityUnits != null) 'quantityUnits': mov.quantityUnits,
      if (mov.quantityScale != null) 'quantityScale': mov.quantityScale,
      if (mov.deltaUnits != null) 'deltaUnits': mov.deltaUnits,
      'obraId': mov.obraId,
      'loteId': mov.loteId,
      'observacao': mov.observacao,
      'evidence': mov.evidence,
      'nfNumber': mov.nfNumber,
      'fornecedor': mov.fornecedor,
      'apropriacaoLote': mov.apropriacaoLote,
      'solicitante': mov.solicitante,
      'reversalId': mov.reversalId,
      'valorItensCentavos': mov.valorItensCentavos,
      'freteCentavos': mov.freteCentavos,
      'despesasCentavos': mov.despesasCentavos,
      'descontoCentavos': mov.descontoCentavos,
      'custoTotalCentavos': mov.custoTotalCentavos,
      'custoUnitarioCentavos': mov.custoUnitarioCentavos,
    });
  }
}

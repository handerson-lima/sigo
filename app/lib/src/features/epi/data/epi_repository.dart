import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/read_cache.dart';
import '../domain/epi_event.dart';
import '../domain/epi_item.dart';
import '../domain/termo_epi.dart';

final epiRepositoryProvider = Provider<EpiRepository>((ref) {
  return EpiRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
});

final catalogoEpisStreamProvider =
    StreamProvider.family<List<EpiItem>, String>((ref, construtoraId) {
  return ref.watch(epiRepositoryProvider).watchCatalogo(construtoraId);
});

final epiEventsObraStreamProvider =
    StreamProvider.family<List<EpiEvent>, ({String construtoraId, String obraId})>((ref, arg) {
  return ref.watch(epiRepositoryProvider).watchEventsPorObra(arg.construtoraId, arg.obraId);
});

final epiEventsFuncionarioStreamProvider =
    StreamProvider.family<List<EpiEvent>, ({String construtoraId, String obraId, String funcionarioId})>((ref, arg) {
  return ref.watch(epiRepositoryProvider).watchEventsPorFuncionario(arg.construtoraId, arg.obraId, arg.funcionarioId);
});

final termosFuncionarioStreamProvider =
    StreamProvider.family<List<TermoEpi>, ({String construtoraId, String obraId, String funcionarioId})>((ref, arg) {
  return ref.watch(epiRepositoryProvider).watchTermosPorFuncionario(arg.construtoraId, arg.obraId, arg.funcionarioId);
});

class EpiRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  EpiRepository(this._firestore, [FirebaseStorage? storage])
      : _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _catalogoRef(String construtoraId) =>
      _firestore.collection('construtoras').doc(construtoraId).collection('catalogo_epis');

  CollectionReference<Map<String, dynamic>> _eventsRef(String construtoraId, String obraId) =>
      _firestore.collection('construtoras').doc(construtoraId).collection('obras').doc(obraId).collection('epi_events');

  CollectionReference<Map<String, dynamic>> _termosRef(String construtoraId, String obraId) =>
      _firestore.collection('construtoras').doc(construtoraId).collection('obras').doc(obraId).collection('termos_epi');

  Stream<List<EpiItem>> watchCatalogo(String construtoraId) {
    return cachedList(
      'construtoras/$construtoraId/catalogo_epis',
      _liveWatchCatalogo(construtoraId),
      (item) => item.toMap(),
      (data) => EpiItem.fromMap(Map<String, dynamic>.from(data), data['id'] ?? ''),
    );
  }

  Stream<List<EpiItem>> _liveWatchCatalogo(String construtoraId) {
    return _catalogoRef(construtoraId).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => EpiItem.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      return list;
    });
  }

  Future<void> saveEpiItem(EpiItem item) async {
    await _catalogoRef(item.construtoraId).doc(item.id).set(
          item.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> toggleEpiStatus(String construtoraId, String epiId, bool isActive) async {
    await _catalogoRef(construtoraId).doc(epiId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<EpiEvent>> watchEventsPorObra(String construtoraId, String obraId) {
    return _eventsRef(construtoraId, obraId)
        .orderBy('dataEvento', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => EpiEvent.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<EpiEvent>> watchEventsPorFuncionario(String construtoraId, String obraId, String funcionarioId) {
    return _eventsRef(construtoraId, obraId)
        .where('funcionarioId', isEqualTo: funcionarioId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => EpiEvent.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.dataEvento.compareTo(a.dataEvento));
      return list;
    });
  }

  Stream<List<TermoEpi>> watchTermosPorFuncionario(String construtoraId, String obraId, String funcionarioId) {
    return _termosRef(construtoraId, obraId)
        .where('funcionarioId', isEqualTo: funcionarioId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => TermoEpi.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.dataAssinatura.compareTo(a.dataAssinatura));
      return list;
    });
  }

  Future<String?> uploadAssinatura({
    required String construtoraId,
    required String obraId,
    required String funcionarioId,
    required Uint8List bytes,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'construtoras/$construtoraId/obras/$obraId/epis/$funcionarioId/termo_${timestamp}_assinatura.png';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    return path;
  }

  Future<void> registrarEntrega({
    required EpiEvent event,
    TermoEpi? termo,
    Uint8List? assinaturaBytes,
  }) async {
    String? storagePath;
    if (assinaturaBytes != null && termo != null) {
      storagePath = await uploadAssinatura(
        construtoraId: event.construtoraId,
        obraId: event.obraId,
        funcionarioId: event.funcionarioId,
        bytes: assinaturaBytes,
      );
    }

    final batch = _firestore.batch();

    String? termoId = event.termoId;
    if (termo != null) {
      termoId = termo.id;
      final termoDoc = _termosRef(event.construtoraId, event.obraId).doc(termo.id);
      final finalTermo = storagePath != null
          ? TermoEpi(
              id: termo.id,
              construtoraId: termo.construtoraId,
              obraId: termo.obraId,
              funcionarioId: termo.funcionarioId,
              funcionarioNome: termo.funcionarioNome,
              funcionarioCpf: termo.funcionarioCpf,
              itens: termo.itens,
              textoLegal: termo.textoLegal,
              tipoConfirmacao: termo.tipoConfirmacao,
              assinaturaStoragePath: storagePath,
              hashSha256: termo.hashSha256,
              dataAssinatura: termo.dataAssinatura,
              responsavelUid: termo.responsavelUid,
            )
          : termo;
      batch.set(termoDoc, finalTermo.toMap());
    }

    final eventDoc = _eventsRef(event.construtoraId, event.obraId).doc(event.id);
    final finalEvent = event.copyWith(termoId: termoId);
    batch.set(eventDoc, finalEvent.toMap());

    await batch.commit();
  }

  Future<void> registrarDevolucaoOuBaixa({
    required String construtoraId,
    required String obraId,
    required String eventoOriginalId,
    required String tipoEvento, // devolucao, baixa_descarte
    required String responsavelUid,
    required String responsavelNome,
    String? motivo,
  }) async {
    final origDoc = await _eventsRef(construtoraId, obraId).doc(eventoOriginalId).get();
    if (!origDoc.exists) return;

    final origData = origDoc.data()!;
    final statusAtual = origData['status'] as String? ?? 'ativo';
    if (statusAtual == 'devolvido' || statusAtual == 'baixado') {
      // Evento já foi finalizado anteriormente, evita operação duplicada
      return;
    }

    final novoStatus = tipoEvento == 'devolucao' ? 'devolvido' : 'baixado';

    final batch = _firestore.batch();
    // Atualiza status do original
    batch.update(_eventsRef(construtoraId, obraId).doc(eventoOriginalId), {
      'status': novoStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Cria novo evento de devolução/baixa
    final newId = _eventsRef(construtoraId, obraId).doc().id;
    final devEvent = EpiEvent(
      id: newId,
      construtoraId: construtoraId,
      obraId: obraId,
      funcionarioId: origData['funcionarioId'] ?? '',
      funcionarioNome: origData['funcionarioNome'] ?? '',
      epiId: origData['epiId'] ?? '',
      epiNome: origData['epiNome'] ?? '',
      caNumero: origData['caNumero'] ?? '',
      tipoEvento: tipoEvento,
      quantidade: (origData['quantidade'] as num?)?.toInt() ?? 1,
      motivo: motivo,
      dataEvento: DateTime.now(),
      responsavelUid: responsavelUid,
      responsavelNome: responsavelNome,
      status: novoStatus,
    );
    batch.set(_eventsRef(construtoraId, obraId).doc(newId), devEvent.toMap());

    await batch.commit();
  }
}

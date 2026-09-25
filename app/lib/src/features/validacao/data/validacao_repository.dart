import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/read_cache.dart';
import '../domain/validacao_template.dart';
import '../domain/validacao_vistoria.dart';

final validacaoRepositoryProvider = Provider<ValidacaoRepository>((ref) {
  return ValidacaoRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
});

final templatesListStreamProvider =
    StreamProvider.family<List<ValidacaoTemplate>, String>((
      ref,
      construtoraId,
    ) {
      return ref
          .watch(validacaoRepositoryProvider)
          .watchTemplates(construtoraId);
    });

final loteVistoriasStreamProvider =
    StreamProvider.family<
      List<ValidacaoVistoria>,
      ({String construtoraId, String obraId, String loteId})
    >((ref, arg) {
      return ref
          .watch(validacaoRepositoryProvider)
          .watchVistoriasLote(arg.construtoraId, arg.obraId, arg.loteId);
    });

final vistoriaDetailsFutureProvider =
    FutureProvider.family<
      ValidacaoVistoria?,
      ({String construtoraId, String obraId, String loteId, String validacaoId})
    >((ref, arg) {
      return ref
          .watch(validacaoRepositoryProvider)
          .getVistoria(
            arg.construtoraId,
            arg.obraId,
            arg.loteId,
            arg.validacaoId,
          );
    });

class ValidacaoRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ValidacaoRepository(this._firestore, [FirebaseStorage? storage])
    : _storage = storage ?? FirebaseStorage.instance;

  // Coleção corporativa de templates
  CollectionReference<Map<String, dynamic>> _templatesRef(
    String construtoraId,
  ) => _firestore
      .collection('construtoras')
      .doc(construtoraId)
      .collection('validacao_templates');

  // Subcoleção de validações por lote
  CollectionReference<Map<String, dynamic>> _vistoriasRef(
    String construtoraId,
    String obraId,
    String loteId,
  ) => _firestore
      .collection('construtoras')
      .doc(construtoraId)
      .collection('obras')
      .doc(obraId)
      .collection('lotes')
      .doc(loteId)
      .collection('validacoes');

  // --- TEMPLATES ---

  Stream<List<ValidacaoTemplate>> watchTemplates(
    String construtoraId, {
    bool apenasAtivos = false,
  }) {
    return cachedList(
      'construtoras/$construtoraId/validacao_templates',
      _liveWatchTemplates(construtoraId, apenasAtivos: apenasAtivos),
      (item) => item.toMap(),
      (data) => ValidacaoTemplate.fromMap(
        Map<String, dynamic>.from(data),
        data['id'] as String?,
      ),
    );
  }

  Stream<List<ValidacaoTemplate>> _liveWatchTemplates(
    String construtoraId, {
    bool apenasAtivos = false,
  }) {
    Query<Map<String, dynamic>> query = _templatesRef(construtoraId);
    if (apenasAtivos) {
      query = query.where('ativo', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ValidacaoTemplate.fromMap(doc.data(), doc.id))
          .toList();
      list.sort(
        (a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()),
      );
      return list;
    });
  }

  Future<ValidacaoTemplate?> getTemplate(
    String construtoraId,
    String templateId,
  ) async {
    final doc = await _templatesRef(construtoraId).doc(templateId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ValidacaoTemplate.fromMap(doc.data()!, doc.id);
  }

  Future<void> saveTemplate(ValidacaoTemplate template) async {
    await _templatesRef(template.construtoraId)
        .doc(template.id)
        .set(template.toMap(), SetOptions(merge: true));
  }

  Future<void> toggleTemplateAtivo(
    String construtoraId,
    String templateId,
    bool ativo,
  ) async {
    await _templatesRef(construtoraId).doc(templateId).update({
      'ativo': ativo,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // --- VISTORIAS DE LOTE ---

  Stream<List<ValidacaoVistoria>> watchVistoriasLote(
    String construtoraId,
    String obraId,
    String loteId,
  ) {
    return cachedList(
      'construtoras/$construtoraId/obras/$obraId/lotes/$loteId/validacoes',
      _liveWatchVistorias(construtoraId, obraId, loteId),
      (item) => item.toMap(),
      (data) => ValidacaoVistoria.fromMap(
        Map<String, dynamic>.from(data),
        data['id'] as String?,
      ),
    );
  }

  Stream<List<ValidacaoVistoria>> _liveWatchVistorias(
    String construtoraId,
    String obraId,
    String loteId,
  ) {
    return _vistoriasRef(construtoraId, obraId, loteId).snapshots().map((
      snapshot,
    ) {
      final list = snapshot.docs
          .map((doc) => ValidacaoVistoria.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.dataVistoria.compareTo(a.dataVistoria));
      return list;
    });
  }

  Future<ValidacaoVistoria?> getVistoria(
    String construtoraId,
    String obraId,
    String loteId,
    String validacaoId,
  ) async {
    final doc = await _vistoriasRef(
      construtoraId,
      obraId,
      loteId,
    ).doc(validacaoId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ValidacaoVistoria.fromMap(doc.data()!, doc.id);
  }

  Future<void> saveVistoria(ValidacaoVistoria vistoria) async {
    await _vistoriasRef(
      vistoria.construtoraId,
      vistoria.obraId,
      vistoria.loteId,
    ).doc(vistoria.id).set(vistoria.toMap(), SetOptions(merge: true));
  }

  Future<void> reabrirVistoria(
    String construtoraId,
    String obraId,
    String loteId,
    String validacaoId,
  ) async {
    await _vistoriasRef(construtoraId, obraId, loteId).doc(validacaoId).update({
      'status': ValidacaoStatus.reaberto.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // --- UPLOAD DE EVIDÊNCIAS FOTOGRÁFICAS ---

  Future<String> uploadFotoEvidencia({
    required String construtoraId,
    required String obraId,
    required String loteId,
    required String validacaoId,
    required String fotoId,
    required Uint8List imageBytes,
  }) async {
    final storagePath =
        'construtoras/$construtoraId/obras/$obraId/validacao/$loteId/$validacaoId/$fotoId.jpg';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'construtoraId': construtoraId,
        'obraId': obraId,
        'loteId': loteId,
        'validacaoId': validacaoId,
        'fotoId': fotoId,
      },
    );

    await ref.putData(imageBytes, metadata);
    try {
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (_) {
      // Fallback em ambiente de teste ou offline: retorna o caminho relativo do storage
      return 'gs://$storagePath';
    }
  }
}

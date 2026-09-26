import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final loteamentosImportRepositoryProvider = Provider<LoteamentosImportRepository>((ref) {
  return LoteamentosImportRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
});

class LoteamentosImportRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  LoteamentosImportRepository(this._firestore, this._storage);

  /// Realiza o upload do arquivo DXF para o Cloud Storage
  /// Retorna o identificador gerado que pode ser usado como ID do rascunho
  Future<String> uploadDxf({
    required String userId,
    required Uint8List fileBytes,
    required String filename,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // O arquivo é salvo com um prefixo único
    final uniqueFilename = '${timestamp}_$filename';
    final path = 'loteamentos_drafts_uploads/$userId/$uniqueFilename';
    final ref = _storage.ref(path);

    await ref.putData(
      fileBytes,
      SettableMetadata(contentType: 'application/dxf'),
    );
    
    // Retorna o identificador único para escutar no Firestore
    return uniqueFilename;
  }

  /// Escuta a criação/atualização do rascunho na coleção loteamentos_drafts
  Stream<Map<String, dynamic>?> watchDraft(String draftId) {
    return _firestore
        .collection('loteamentos_drafts')
        .doc(draftId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }
}

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final loteamentosImportRepositoryProvider =
    Provider<LoteamentosImportRepository>((ref) {
      return LoteamentosImportRepository(
        FirebaseFirestore.instance,
        FirebaseStorage.instance,
      );
    });

class LoteamentosImportRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  LoteamentosImportRepository(this._firestore, this._storage);

  /// Realiza o upload do arquivo DXF para o Cloud Storage.
  /// Retorna o identificador gerado que pode ser usado como ID do rascunho
  Future<String> uploadDxf({
    required String userId,
    required String construtoraId,
    required Uint8List fileBytes,
    required String filename,
  }) async {
    return uploadFile(
      userId: userId,
      construtoraId: construtoraId,
      fileBytes: fileBytes,
      filename: filename,
    );
  }

  /// Envia exclusivamente um DXF para criar um rascunho revisável.
  Future<String> uploadFile({
    required String userId,
    required String construtoraId,
    required Uint8List fileBytes,
    required String filename,
  }) async {
    final loteamentoName = loteamentoNameFromFilename(filename);
    if (loteamentoName == null) {
      throw ArgumentError.value(
        filename,
        'filename',
        'Envie um arquivo DXF válido',
      );
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // O arquivo é salvo com um prefixo único
    final uniqueFilename = '${timestamp}_$filename';
    final path = 'loteamentos_drafts_uploads/$userId/$uniqueFilename';
    final ref = _storage.ref(path);

    await ref.putData(
      fileBytes,
      SettableMetadata(
        contentType: 'application/dxf',
        customMetadata: {
          'construtoraId': construtoraId,
          'loteamentoName': loteamentoName,
        },
      ),
    );

    // Retorna o identificador único para escutar no Firestore
    return uniqueFilename;
  }

  static String? loteamentoNameFromFilename(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot <= 0 ||
        !const {
          '.dxf',
        }.contains(filename.substring(lastDot).toLowerCase())) {
      return null;
    }
    final name = filename.substring(0, lastDot).trim();
    return name.isEmpty ? null : name;
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

  /// Atualiza as propriedades de uma feature específica no rascunho
  Future<void> updateDraftFeature(
    String draftId,
    int featureIndex,
    Map<String, dynamic> newProperties,
  ) async {
    final docRef = _firestore.collection('loteamentos_drafts').doc(draftId);

    // Roda em uma transação para garantir que o array não seja sobrescrito incorretamente
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Rascunho não encontrado');
      }

      final data = snapshot.data()!;
      final features = List<dynamic>.from(data['features'] ?? []);

      if (featureIndex < 0 || featureIndex >= features.length) {
        throw Exception('Índice da feature inválido');
      }

      if (features[featureIndex] is! Map) {
        throw Exception('Feature at index $featureIndex is not a valid Map.');
      }
      final feature = Map<String, dynamic>.from(features[featureIndex] as Map);
      final currentProperties = Map<String, dynamic>.from(
        feature['properties'] ?? {},
      );

      currentProperties.addAll(newProperties);
      feature['properties'] = currentProperties;

      features[featureIndex] = feature;

      transaction.update(docRef, {'features': features});
    });
  }

  /// Atualiza o status do rascunho inteiro para aprovado
  Future<void> approveDraft(String draftId) async {
    final docRef = _firestore.collection('loteamentos_drafts').doc(draftId);
    await docRef.update({'status': 'aprovado'});
  }
}

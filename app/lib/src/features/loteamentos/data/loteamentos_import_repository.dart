import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ConsolidationRequester = Future<void> Function(String draftId);

/// Arquivo selecionado pelo usuário para envio ao pipeline de importação.
class ImportUploadFile {
  final Uint8List bytes;
  final String filename;

  const ImportUploadFile({
    required this.bytes,
    required this.filename,
  });
}

final loteamentosImportRepositoryProvider =
    Provider<LoteamentosImportRepository>((ref) {
      return LoteamentosImportRepository(
        FirebaseFirestore.instance,
        FirebaseStorage.instance,
        requestConsolidation: (draftId) async {
          final callable = FirebaseFunctions.instanceFor(
            region: 'us-east1',
          ).httpsCallable('consolidar_loteamento_manual');
          await callable.call({'draftId': draftId});
        },
      );
    });

class LoteamentosImportRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Seam injetável para o retry manual da consolidação. No app é ligado à
  /// callable `consolidar_loteamento_manual`; nos testes pode ser substituído.
  final ConsolidationRequester? requestConsolidation;

  LoteamentosImportRepository(
    this._firestore,
    this._storage, {
    this.requestConsolidation,
  });

  /// Realiza o upload do arquivo DXF para o Cloud Storage.
  /// Retorna o identificador gerado que pode ser usado como ID do rascunho.
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

  /// Envia um arquivo PDF, DXF ou DWF para criar ou complementar um rascunho
  /// tabular revisável.
  Future<String> uploadFile({
    required String userId,
    required String construtoraId,
    required Uint8List fileBytes,
    required String filename,
    String? draftId,
    String? targetLoteamentoId,
    String? loteamentoNameOverride,
    int? fileIndex,
  }) async {
    final parsedName = loteamentoNameFromFilename(filename);
    final contentType = contentTypeFromFilename(filename);
    if (parsedName == null || contentType == null) {
      throw ArgumentError.value(
        filename,
        'filename',
        'Envie um arquivo PDF, DXF ou DWF válido',
      );
    }

    final effectiveLoteamentoName =
        (loteamentoNameOverride != null &&
                loteamentoNameOverride.trim().isNotEmpty)
            ? loteamentoNameOverride.trim()
            : parsedName;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = fileIndex != null ? '${timestamp}_$fileIndex' : '$timestamp';
    final uniqueFilename = '${prefix}_$filename';
    final effectiveDraftId =
        (draftId != null && draftId.trim().isNotEmpty)
            ? draftId.trim()
            : uniqueFilename;

    final path = 'loteamentos_drafts_uploads/$userId/$uniqueFilename';
    final ref = _storage.ref(path);

    final customMetadata = <String, String>{
      'construtoraId': construtoraId,
      'loteamentoName': effectiveLoteamentoName,
      'originalFilename': filename,
      if (draftId != null && draftId.trim().isNotEmpty)
        'draftId': effectiveDraftId,
      if (targetLoteamentoId != null && targetLoteamentoId.trim().isNotEmpty)
        'targetLoteamentoId': targetLoteamentoId.trim(),
    };

    await ref.putData(
      fileBytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: customMetadata,
      ),
    );

    return effectiveDraftId;
  }

  /// Envia um ou mais arquivos PDF, DXF ou DWF para o mesmo rascunho.
  ///
  /// Quando múltiplos arquivos são enviados juntos, todos recebem o mesmo
  /// `draftId` nos metadados customizados do Storage para que o backend faça
  /// merge transacional de `items` e `sourceFiles` em `loteamentos_drafts/{draftId}`.
  Future<String> uploadFiles({
    required String userId,
    required String construtoraId,
    required List<ImportUploadFile> files,
    String? targetLoteamentoId,
    String? loteamentoNameOverride,
  }) async {
    if (files.isEmpty) {
      throw ArgumentError.value(
        files,
        'files',
        'Selecione ao menos um arquivo PDF, DXF ou DWF',
      );
    }

    for (final file in files) {
      if (loteamentoNameFromFilename(file.filename) == null ||
          contentTypeFromFilename(file.filename) == null) {
        throw ArgumentError.value(
          file.filename,
          'files',
          'Envie apenas arquivos PDF, DXF ou DWF válidos',
        );
      }
    }

    if (files.length == 1) {
      final only = files.first;
      return uploadFile(
        userId: userId,
        construtoraId: construtoraId,
        fileBytes: only.bytes,
        filename: only.filename,
        targetLoteamentoId: targetLoteamentoId,
        loteamentoNameOverride: loteamentoNameOverride,
      );
    }

    final sharedDraftId =
        'draft_${DateTime.now().toUtc().millisecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}';
    final defaultLoteamentoName =
        (loteamentoNameOverride != null &&
                loteamentoNameOverride.trim().isNotEmpty)
            ? loteamentoNameOverride.trim()
            : loteamentoNameFromFilename(files.first.filename)!;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      await uploadFile(
        userId: userId,
        construtoraId: construtoraId,
        fileBytes: file.bytes,
        filename: file.filename,
        draftId: sharedDraftId,
        targetLoteamentoId: targetLoteamentoId,
        loteamentoNameOverride: defaultLoteamentoName,
        fileIndex: i,
      );
    }

    return sharedDraftId;
  }

  static String? contentTypeFromFilename(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot <= 0) {
      return null;
    }
    switch (filename.substring(lastDot).toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.dxf':
        return 'application/dxf';
      case '.dwf':
        return 'application/x-dwf';
      default:
        return null;
    }
  }

  static String? loteamentoNameFromFilename(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot <= 0 || contentTypeFromFilename(filename) == null) {
      return null;
    }
    final name = filename.substring(0, lastDot).trim();
    return name.isEmpty ? null : name;
  }

  /// Escuta a criação/atualização do rascunho na coleção `loteamentos_drafts`.
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

  /// Persiste alterações da revisão tabular no documento `loteamentos_drafts/{draftId}`.
  Future<void> saveDraftReview({
    required String draftId,
    required Map<String, dynamic> loteamento,
    String? targetLoteamentoId,
    required List<Map<String, dynamic>> items,
  }) async {
    final docRef = _firestore.collection('loteamentos_drafts').doc(draftId);
    final normalizedTarget =
        (targetLoteamentoId != null && targetLoteamentoId.trim().isNotEmpty)
            ? targetLoteamentoId.trim()
            : null;

    await docRef.update({
      'loteamento': loteamento,
      'targetLoteamentoId': normalizedTarget,
      'items': items,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Atualiza as propriedades de uma feature específica no rascunho legado.
  @Deprecated('Fluxo geométrico substituído pela revisão tabular (saveDraftReview)')
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

  /// Atualiza o status do rascunho inteiro para aprovado e registra a
  /// solicitação de consolidação consumida pelo backend.
  Future<void> approveDraft(String draftId) async {
    await _commitApproval(draftId: draftId, extraFields: const {});
  }

  /// Persiste os dados revisados do rascunho tabular (`loteamento`,
  /// `targetLoteamentoId`, `items`), marca `status: 'aprovado'`, grava
  /// `consolidationRequestId` e `updatedAt` e dispara a consolidação.
  Future<void> approveTabularDraft({
    required String draftId,
    required Map<String, dynamic> loteamento,
    String? targetLoteamentoId,
    required List<Map<String, dynamic>> items,
  }) async {
    final normalizedTarget =
        (targetLoteamentoId != null && targetLoteamentoId.trim().isNotEmpty)
            ? targetLoteamentoId.trim()
            : null;
    await _commitApproval(
      draftId: draftId,
      extraFields: {
        'loteamento': loteamento,
        'targetLoteamentoId': normalizedTarget,
        'items': items,
      },
    );
  }

  Future<void> _commitApproval({
    required String draftId,
    required Map<String, dynamic> extraFields,
  }) async {
    final docRef = _firestore.collection('loteamentos_drafts').doc(draftId);
    final requestId =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
    final payload = <String, dynamic>{
      ...extraFields,
      'status': 'aprovado',
      // Cada confirmação cria uma solicitação distinta, inclusive quando o
      // rascunho já está aprovado e precisa ser consolidado novamente.
      'consolidationRequestId': requestId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    await docRef.update(payload);
    // Retry manual do design: se o gatilho não disparar, a callable consolida.
    // Uma falha aqui não bloqueia a aprovação já persistida.
    try {
      await requestConsolidation?.call(draftId);
    } catch (_) {
      // Ignorado de propósito: a consolidação permanece recuperável.
    }
  }
}

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../sync/blob_attachment.dart';
import '../../../sync/operation_queue.dart';
import '../../../sync/read_cache.dart';
import '../domain/diario.dart';

final diarioRepositoryProvider = Provider<DiarioRepository>(
  (ref) =>
      DiarioRepository(FirebaseFirestore.instance, FirebaseStorage.instance),
);

class DiarioRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  DiarioRepository(this._firestore, this._storage);
  Stream<List<DiarioObra>> watchDiarios(String c, String o) => cachedList(
    'diarios/$c/$o',
    _firestore
        .collection('construtoras/$c/obras/$o/diarios')
        .orderBy('date', descending: true)
        .snapshots(includeMetadataChanges: true)
        .where((s) => !s.metadata.isFromCache)
        .map((s) => s.docs.map((d) => DiarioObra.fromJson(d.data())).toList()),
    (value) => value.toJson(),
    (value) => DiarioObra.fromJson(Map<String, dynamic>.from(value)),
  );
  Stream<List<DiarioObra>> watchPendingDiarios(String c, String o) =>
      OperationQueue.instance.watch().map(
        (rows) => rows
            .where(
              (r) =>
                  r['action'] == 'finalizeDiario' &&
                  r['payload']['construtoraId'] == c &&
                  r['payload']['obraId'] == o &&
                  r['state'] != 'synced',
            )
            .map(
              (r) => DiarioObra.fromJson({
                ...Map<String, dynamic>.from(r['payload']['diario']),
                'isPendingSync': true,
              }),
            )
            .toList(),
      );
  Future<void> createDiario(DiarioObra diario, List<Uint8List> photos) async {
    final user = FirebaseAuth.instance.currentUser?.uid;
    if (user == null || user != diario.responsavelId) {
      throw StateError('Sessão inválida');
    }
    final attachments = <Map<String, dynamic>>[];
    for (final bytes in photos) {
      final id = const Uuid().v4();
      final path =
          'construtoras/${diario.construtoraId}/obras/${diario.obraId}/diarios/${diario.id}/$user/$id';
      attachments.add(buildBlobAttachment(
        bytes: bytes,
        storagePath: path,
        id: id,
      ));
    }
    await OperationQueue.instance.enqueue('finalizeDiario', {
      'construtoraId': diario.construtoraId,
      'obraId': diario.obraId,
      'operationId': diario.id,
      'diario': diario.toJson(),
      'attachments': attachments
          .map((a) => {'id': a['id'], 'size': a['size'], 'sha256': a['sha256']})
          .toList(),
    }, attachments: attachments);
  }

  Future<void> syncDiario(DiarioObra diario) async {
    final rows = await OperationQueue.instance.list();
    final found = rows
        .where(
          (r) =>
              r['action'] == 'finalizeDiario' &&
              r['payload']['diario']['id'] == diario.id,
        )
        .toList();
    if (found.isEmpty) {
      throw StateError(
        'Pendência legada: importar os arquivos no dispositivo original; não foi sincronizada',
      );
    }
    await OperationQueue.instance.sync(onlyKey: found.first['key']);
    final current = (await OperationQueue.instance.list()).firstWhere(
      (r) => r['key'] == found.first['key'],
    );
    if (current['state'] != 'synced') {
      throw StateError(current['error'] ?? current['state']);
    }
  }

  // Converts legacy token URLs to an authenticated Storage SDK read; no new tokens.
  Future<Uint8List?> readPhoto(String value) =>
      (value.startsWith('https://') || value.startsWith('gs://')
              ? _storage.refFromURL(value)
              : _storage.ref(value))
          .getData(10 * 1024 * 1024);
}

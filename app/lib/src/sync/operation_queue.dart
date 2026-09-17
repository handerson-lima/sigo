import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'queue_store.dart';

typedef QueueStore = Future<String> Function(String action, String input);
typedef QueueUpload = Future<void> Function(
  Map<String, dynamic> attachment,
  Uint8List bytes,
  String uid,
);
typedef QueueExecute = Future<dynamic> Function(
  String action,
  Map<String, dynamic> payload,
);

class OperationQueue {
  OperationQueue({
    required this.sessionUid,
    required this.store,
    required this.upload,
    required this.execute,
    this.autoSync = true,
  });

  static OperationQueue instance = OperationQueue(
    sessionUid: () => FirebaseAuth.instance.currentUser?.uid,
    store: queueStore,
    upload: _firebaseUpload,
    execute: (action, payload) async {
      final res =
          await FirebaseFunctions.instance.httpsCallable(action).call(payload);
      return res.data;
    },
  );
  final String? Function() sessionUid;
  final QueueStore store;
  final QueueUpload upload;
  final QueueExecute execute;
  final bool autoSync;
  Timer? _timer;
  bool _busy = false;
  String? lastError;

  bool get isBusy => _busy;

  /// Retorna os metadados de versão do schema local para auditoria e diagnóstico.
  Future<Map<String, dynamic>> getSchemaVersion() async {
    try {
      final res = await store('getSchemaVersion', '{}');
      if (res.isNotEmpty && res != 'null') {
        return jsonDecode(res) as Map<String, dynamic>;
      }
    } catch (_) {
      // Retorna fallback seguro se a consulta não puder ser concluída
    }
    return const {'version': 3};
  }

  static Future<void> _firebaseUpload(
    Map<String, dynamic> a,
    Uint8List bytes,
    String uid,
  ) async {
    final ref = FirebaseStorage.instance.ref(a['path'] as String);
    Future<bool> uploaded() async {
      try {
        final meta = await ref.getMetadata();
        if (meta.size != a['size'] ||
            meta.customMetadata?['sha256'] != a['sha256']) {
          throw StateError('Anexo remoto divergente. Solicite revisão.');
        }
        return true;
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') return false;
        rethrow;
      }
    }

    if (await uploaded()) return;
    try {
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: a['contentType'],
          customMetadata: {'sha256': a['sha256'], 'owner': uid},
        ),
      );
    } on FirebaseException catch (e) {
      // Outra aba pode ter concluído o mesmo objeto entre getMetadata e putData.
      if (e.code == 'unauthorized' && await uploaded()) return;
      rethrow;
    }
  }

  void start() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(sync()),
    );
    unawaited(sync());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<dynamic> _callStore(String action, Map<String, dynamic> args) async =>
      jsonDecode(await store(action, jsonEncode(args)));

  Future<List<Map<String, dynamic>>> list({
    String? construtoraId,
    String? obraId,
    String? action,
  }) async {
    final user = sessionUid();
    if (user == null) return [];
    final args = <String, dynamic>{'uid': user};
    if (construtoraId != null) args['construtoraId'] = construtoraId;
    if (obraId != null) args['obraId'] = obraId;
    if (action != null) args['action'] = action;
    final result = await _callStore('list', args) as List;
    if (sessionUid() != user) return [];
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Stream<List<Map<String, dynamic>>> watch({
    String? construtoraId,
    String? obraId,
    String? action,
  }) async* {
    while (true) {
      yield await list(
        construtoraId: construtoraId,
        obraId: obraId,
        action: action,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<int> get pendingCount async =>
      (await list()).where((e) => e['state'] == 'pending' || e['state'] == 'syncing').length;

  Future<int> get failedCount async =>
      (await list()).where((e) => e['state'] == 'failed' || e['state'] == 'authorization_rejected' || e['state'] == 'conflict').length;

  Future<int> get syncedCount async =>
      (await list()).where((e) => e['state'] == 'synced').length;

  Future<int> scopedPendingCount({String? construtoraId, String? obraId}) async =>
      (await list(construtoraId: construtoraId, obraId: obraId))
          .where((e) => e['state'] == 'pending' || e['state'] == 'syncing')
          .length;

  Future<int> scopedFailedCount({String? construtoraId, String? obraId}) async =>
      (await list(construtoraId: construtoraId, obraId: obraId))
          .where((e) =>
              e['state'] == 'failed' ||
              e['state'] == 'authorization_rejected' ||
              e['state'] == 'conflict')
          .length;

  Future<int> scopedSyncedCount({String? construtoraId, String? obraId}) async =>
      (await list(construtoraId: construtoraId, obraId: obraId))
          .where((e) => e['state'] == 'synced')
          .length;

  Future<void> enqueue(
    String action,
    Map<String, dynamic> payload, {
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final user = sessionUid();
    if (user == null) throw StateError('Entre para salvar a operação.');
    final construtoraId = payload['construtoraId'] as String?;
    final obraId = payload['obraId'] as String?;
    final storedPayload = {...payload, 'actorUid': user};
    final row = {
      'key': jsonEncode([
        user,
        construtoraId,
        obraId,
        action,
        payload['operationId'],
      ]),
      'uid': user,
      'construtoraId': construtoraId,
      'obraId': obraId,
      'schemaVersion': 1,
      'action': action,
      'payload': storedPayload,
      'attachments': attachments,
      'state': 'pending',
      'error': null,
      'leaseUntil': 0,
      'attempts': 0,
      'nextAttemptAt': 0,
    };
    try {
      final stored = await _callStore('insert', row);
      if (jsonEncode(stored['payload']) != jsonEncode(storedPayload) ||
          jsonEncode(stored['attachments']) != jsonEncode(attachments)) {
        throw StateError('Identificador já utilizado por outra operação.');
      }
    } catch (e) {
      throw StateError(
        'Não foi possível salvar no dispositivo. Verifique o espaço disponível. $e',
      );
    }
    if (autoSync) unawaited(sync());
  }

  Future<void> sync({
    String? onlyKey,
    String? construtoraId,
    String? obraId,
  }) async {
    if (_busy || sessionUid() == null) return;
    _busy = true;
    try {
      final user = sessionUid()!;
      final candidates = await list(
        construtoraId: construtoraId,
        obraId: obraId,
      );
      for (final candidate in candidates) {
        if (sessionUid() != user) break;
        if (onlyKey != null && candidate['key'] != onlyKey) continue;
        final lease = const Uuid().v4();
        final claimed = await _callStore('claim', {
          'key': candidate['key'],
          'uid': user,
          'lease': lease,
          'force': onlyKey != null,
        });
        if (claimed == null) continue;
        final row = Map<String, dynamic>.from(claimed);
        var state = 'synced';
        String? error;
        dynamic result;
        try {
          final payload = Map<String, dynamic>.from(row['payload']);
          for (final raw in row['attachments'] as List) {
            if (sessionUid() != user) {
              throw StateError('Conta alterada. Operação preservada.');
            }
            final a = Map<String, dynamic>.from(raw);
            final bytes = base64Decode(a['bytes'] as String? ?? '');
            if (bytes.isEmpty ||
                bytes.length != a['size'] ||
                sha256.convert(bytes).toString() != a['sha256']) {
              throw StateError(
                'Anexo ausente ou corrompido. Recupere o arquivo original.',
              );
            }
            await upload(a, bytes, user);
          }
          if (sessionUid() != user) {
            throw StateError('Conta alterada. Operação preservada.');
          }
          result = await execute(row['action'], {...payload, 'actorUid': user});
          if (sessionUid() != user) {
            throw StateError('Conta alterada. Operação preservada.');
          }
        } catch (e) {
          error = e.toString();
          state = 'failed';
          final errStr = e.toString().toLowerCase();
          if (e is FirebaseException) {
            if ([
              'permission-denied',
              'unauthorized',
            ].contains(e.code)) {
              state = 'authorization_rejected';
            } else if ([
              'already-exists',
              'failed-precondition',
              'invalid-argument',
            ].contains(e.code)) {
              state = 'conflict';
            }
          } else if (errStr.contains('permission-denied') ||
              errStr.contains('unauthorized') ||
              errStr.contains('não autorizado') ||
              errStr.contains('sem permissão')) {
            state = 'authorization_rejected';
          } else if (errStr.contains('already-exists') ||
              errStr.contains('failed-precondition') ||
              errStr.contains('invalid-argument')) {
            state = 'conflict';
          }
        }
        await _callStore('finish', {
          'key': row['key'],
          'uid': user,
          'lease': lease,
          'state': state,
          'error': error,
          'result': ?result,
        });
      }
      lastError = null;
    } catch (e) {
      // Falha do armazenamento ou logout não podem derrubar o app por um Future não aguardado.
      lastError = 'Não foi possível acessar a fila: $e';
    } finally {
      _busy = false;
    }
  }

  Future<dynamic> getResult(String key) async {
    final rows = await list();
    final found = rows.where((r) => r['key'] == key).toList();
    if (found.isEmpty) return null;
    return found.first['result'];
  }
}

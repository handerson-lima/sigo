import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../sync/queue_store.dart';

final lotePersistidoServiceProvider = Provider<LotePersistidoService>((ref) {
  return LotePersistidoService();
});

class LotePersistidoService {
  final Map<String, String> _inMemoryCache = {};

  String _buildKey(String obraId, String teamId) => 'last_lot:$obraId:$teamId';

  String _getUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    } catch (_) {
      return 'anonymous';
    }
  }

  Future<void> saveDefaultLot({
    required String obraId,
    required String teamId,
    required String lotId,
  }) async {
    final key = _buildKey(obraId, teamId);
    _inMemoryCache[key] = lotId;

    final uid = _getUid();
    try {
      await queueStore(
        'cacheSet',
        jsonEncode({
          'uid': uid,
          'key': jsonEncode([uid, 'lote_persistido/$key']),
          'value': {'lotId': lotId},
        }),
      );
    } catch (_) {
      // Falha silenciosa de persistência secundária mantendo cache em memória
    }
  }

  Future<String?> getDefaultLot({
    required String obraId,
    required String teamId,
  }) async {
    final key = _buildKey(obraId, teamId);
    if (_inMemoryCache.containsKey(key)) {
      return _inMemoryCache[key];
    }

    final uid = _getUid();
    try {
      final res = await queueStore(
        'cacheGet',
        jsonEncode({
          'uid': uid,
          'key': jsonEncode([uid, 'lote_persistido/$key']),
        }),
      );
      if (res.isNotEmpty) {
        final decoded = jsonDecode(res);
        if (decoded is Map && decoded['lotId'] is String) {
          final lotId = decoded['lotId'] as String;
          _inMemoryCache[key] = lotId;
          return lotId;
        }
      }
    } catch (_) {
      // Retorna null se não houver registro
    }

    return null;
  }
}

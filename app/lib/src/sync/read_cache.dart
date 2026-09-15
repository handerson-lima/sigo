import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'queue_store.dart';

Object? _jsonValue(Object? value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  return value;
}

Future<dynamic> _cache(
  String action,
  String uid,
  String path, [
  dynamic value,
]) async => jsonDecode(
  await queueStore(
    action,
    jsonEncode({
      'uid': uid,
      'key': jsonEncode([uid, path]),
      'value': value,
    }, toEncodable: _jsonValue),
  ),
);
Future<void> clearReadCache(String uid) async {
  await _cache('cacheClear', uid, '');
}

/// Cache local só permite leitura. Toda gravação continua autorizada pelo servidor.
Stream<Map<String, dynamic>?> cachedDocument(String path) async* {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    yield null;
    return;
  }
  Map<String, dynamic>? cached;
  try {
    final old = await _cache('cacheGet', uid, path);
    if (old != null) cached = Map<String, dynamic>.from(old);
  } catch (_) {
    /* A leitura online continua disponível se o cache falhar. */
  }
  if (FirebaseAuth.instance.currentUser?.uid != uid) return;
  if (cached != null) yield cached;
  try {
    await for (final doc
        in FirebaseFirestore.instance
            .doc(path)
            .snapshots(includeMetadataChanges: true)) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      if (doc.metadata.isFromCache && !doc.exists && cached != null) continue;
      final value = doc.data();
      if (!doc.metadata.isFromCache) {
        if (value?['isActive'] == false) await clearReadCache(uid);
        try {
          await _cache('cachePut', uid, path, value);
        } catch (_) {}
      }
      yield value;
    }
  } on FirebaseException catch (e) {
    if (['permission-denied', 'unauthenticated'].contains(e.code)) {
      await clearReadCache(uid);
      yield null;
      rethrow;
    }
    if (cached == null) rethrow;
  }
}

Future<T> cachedRead<T>(
  String key,
  Future<T> Function() fetch,
  dynamic Function(T) encode,
  T Function(dynamic) decode,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('Sessão encerrada');
  try {
    final value = await fetch().timeout(const Duration(seconds: 5));
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Conta alterada');
    }
    try {
      await _cache('cachePut', uid, key, encode(value));
    } catch (_) {}
    return value;
  } catch (e) {
    if (FirebaseAuth.instance.currentUser?.uid != uid) rethrow;
    if (e is FirebaseException &&
        ['permission-denied', 'unauthenticated'].contains(e.code)) {
      await clearReadCache(uid);
      rethrow;
    }
    if (e is! TimeoutException &&
        !(e is FirebaseException &&
            ['unavailable', 'deadline-exceeded'].contains(e.code))) {
      rethrow;
    }
    final old = await _cache('cacheGet', uid, key);
    if (old == null) rethrow;
    return decode(old);
  }
}

Stream<List<T>> cachedList<T>(
  String key,
  Stream<List<T>> source,
  dynamic Function(T) encode,
  T Function(dynamic) decode,
) async* {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    yield [];
    return;
  }
  try {
    final old = await _cache('cacheGet', uid, key);
    if (old is List && FirebaseAuth.instance.currentUser?.uid == uid) {
      yield old.map(decode).toList();
    }
  } catch (_) {}
  try {
    await for (final value in source) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      try {
        await _cache('cachePut', uid, key, value.map(encode).toList());
      } catch (_) {}
      yield value;
    }
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      await clearReadCache(uid);
      yield [];
      rethrow;
    }
    if (e.code != 'unavailable') rethrow;
  }
}

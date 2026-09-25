import '../../../sync/read_cache.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';
import 'auth_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authUser = ref.watch(authStateChangesProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(authUser.uid);
});

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  CollectionReference<AppUser> get _usersRef => _firestore
      .collection('users')
      .withConverter<AppUser>(
        fromFirestore: (snapshot, _) {
          final data = snapshot.data()!;
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp)
                .toDate()
                .toIso8601String();
          }
          if (data['updatedAt'] is Timestamp) {
            data['updatedAt'] = (data['updatedAt'] as Timestamp)
                .toDate()
                .toIso8601String();
          }
          return AppUser.fromJson(data);
        },
        toFirestore: (user, _) => user.toJson(),
      );

  Future<AppUser?> getUser(String uid) async {
    final snapshot = await _usersRef.doc(uid).get();
    return snapshot.data();
  }

  Stream<AppUser?> watchUser(String uid) {
    return cachedDocument('users/$uid')
        .map((data) => data == null ? null : AppUser.fromJson(data));
  }

  Future<void> createUser(AppUser user) async {
    await _usersRef.doc(user.id).set(user);
  }
}

final trustedDevProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('dev_roles')
      .doc(user.uid)
      .snapshots()
      .asyncMap((snapshot) async {
        if (snapshot.exists && snapshot.data()?['isActive'] == true) {
          return true;
        }
        // Fallback de transição e auto-provisionamento para dev legítimo com globalRole == 'dev'
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final data = userDoc.data();
          if (data?['globalRole'] == 'dev') {
            await FirebaseFirestore.instance
                .collection('dev_roles')
                .doc(user.uid)
                .set({
                  'isActive': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });
            return true;
          }
        } catch (e) {
          // Ignorar erros de leitura se o usuário não for dev
        }
        return false;
      });
});

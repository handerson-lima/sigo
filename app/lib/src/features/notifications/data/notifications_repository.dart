import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';

class SigoNotification {
  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  SigoNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
    this.expiresAt,
  });

  factory SigoNotification.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return SigoNotification(
      id: id,
      title: data['title'] as String? ?? 'Notificação',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: parseDate(data['createdAt']),
      expiresAt: parseDate(data['expiresAt']),
    );
  }
}

class NotificationsRepository {
  final FirebaseFirestore _firestore;

  NotificationsRepository(this._firestore);

  Stream<List<SigoNotification>> watchNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => SigoNotification.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> markAsRead(String uid, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> deleteNotification(String uid, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(FirebaseFirestore.instance);
});

final userNotificationsProvider =
    StreamProvider.autoDispose<List<SigoNotification>>((ref) {
      final user = ref.watch(authStateChangesProvider).value;
      if (user == null) return Stream.value([]);
      return ref
          .watch(notificationsRepositoryProvider)
          .watchNotifications(user.uid);
    });

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifs = ref.watch(userNotificationsProvider).value ?? [];
  return notifs.where((n) => !n.read).length;
});

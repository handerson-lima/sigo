import '../../../sync/read_cache.dart';
import '../../../core/contracts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/construtora.dart';
import '../domain/construtora_member.dart';

final construtoraRepositoryProvider = Provider<ConstrutoraRepository>((ref) {
  return ConstrutoraRepository(FirebaseFirestore.instance);
});

class ConstrutoraRepository {
  final FirebaseFirestore _firestore;

  ConstrutoraRepository(this._firestore);

  Future<ConstrutoraMember?> getMember(String construtoraId, String userId) =>
      cachedRead(
        'membership/$construtoraId/$userId',
        () => _loadMember(construtoraId, userId),
        (m) => m?.toJson(),
        (d) => d == null
            ? null
            : ConstrutoraMember.fromJson(Map<String, dynamic>.from(d)),
      );

  Future<ConstrutoraMember?> _loadMember(
    String construtoraId,
    String userId,
  ) async {
    final doc = await _firestore
        .collection('construtoras')
        .doc(construtoraId)
        .collection('construtora_members')
        .doc(userId)
        .withConverter<ConstrutoraMember>(
          fromFirestore: (snapshot, _) {
            final data = snapshot.data()!;
            if (data['joinedAt'] is Timestamp) {
              data['joinedAt'] = (data['joinedAt'] as Timestamp)
                  .toDate()
                  .toIso8601String();
            }
            return ConstrutoraMember.fromJson(data);
          },
          toFirestore: (member, _) => member.toJson(),
        )
        .get(const GetOptions(source: Source.server));
    return doc.data();
  }

  // Busca construtoras em que o user é membro (collectionGroup 'construtora_members')
  Future<List<Construtora>> getUserConstrutoras(
    String userId, {
    bool dev = false,
  }) => cachedRead(
    'construtoras/$userId/$dev',
    () => _loadgetUserConstrutoras(userId, dev: dev),
    (items) => items.map((e) => e.toJson()).toList(),
    (data) => (data as List)
        .map((e) => Construtora.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  Future<List<Construtora>> _loadgetUserConstrutoras(
    String userId, {
    bool dev = false,
  }) async {
    if (dev) {
      final all = await _firestore
          .collection('construtoras')
          .get(const GetOptions(source: Source.server));
      return all.docs
          .map(
            (d) => Construtora.fromJson(
              compatibleDates(d.data(), ['createdAt', 'updatedAt']),
            ),
          )
          .toList();
    }
    final querySnapshot = await _firestore
        .collectionGroup('construtora_members')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get(const GetOptions(source: Source.server));

    final construtoraFutures = querySnapshot.docs.map((doc) async {
      // doc.reference é construtoras/{cId}/construtora_members/{uId}
      // o pai do pai é construtoras/{cId}
      final construtoraDoc = await doc.reference.parent.parent!
          .withConverter<Construtora>(
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
              return Construtora.fromJson(data);
            },
            toFirestore: (construtora, _) => construtora.toJson(),
          )
          .get(const GetOptions(source: Source.server));
      return construtoraDoc.data();
    }).toList();

    final results = await Future.wait(construtoraFutures);
    return results.whereType<Construtora>().toList(); // Filtra nulls
  }
}

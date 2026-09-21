import '../../../sync/read_cache.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/obra.dart';
import '../domain/obra_member.dart';
import '../../construtoras/domain/construtora_member.dart';

final obraRepositoryProvider = Provider<ObraRepository>((ref) {
  return ObraRepository(FirebaseFirestore.instance);
});

class ObraRepository {
  final FirebaseFirestore _firestore;

  ObraRepository(this._firestore);

  CollectionReference<Obra> _obrasRef(String construtoraId) => _firestore
      .collection('construtoras')
      .doc(construtoraId)
      .collection('obras')
      .withConverter<Obra>(
        fromFirestore: (snapshot, _) => Obra.fromJson(snapshot.data()!),
        toFirestore: (obra, _) => obra.toJson(),
      );

  CollectionReference<ObraMember> _membersRef(
    String construtoraId,
    String obraId,
  ) =>
      _obrasRef(construtoraId)
          .doc(obraId)
          .collection('members')
          .withConverter<ObraMember>(
            fromFirestore: (snapshot, _) =>
                ObraMember.fromJson(snapshot.data()!),
            toFirestore: (member, _) => member.toJson(),
          );

  Future<void> createObra(Obra obra) async {
    await _obrasRef(obra.construtoraId).doc(obra.id).set(obra);
  }

  Future<void> updateObra(Obra obra) async {
    await _obrasRef(obra.construtoraId).doc(obra.id).update(obra.toJson());
  }

  Future<Obra?> getObra(String construtoraId, String obraId) async {
    final snapshot = await _obrasRef(construtoraId)
        .doc(obraId)
        .get(const GetOptions(source: Source.server));
    return snapshot.data();
  }

  Future<ObraMember?> getMember(
    String construtoraId,
    String obraId,
    String userId,
  ) async {
    final doc = await _membersRef(
      construtoraId,
      obraId,
    ).doc(userId).get(const GetOptions(source: Source.server));
    return doc.data();
  }

  Stream<ObraMember?> watchObraMember(
    String construtoraId,
    String obraId,
    String userId,
  ) {
    return _membersRef(
      construtoraId,
      obraId,
    ).doc(userId).snapshots().map((doc) => doc.data());
  }

  Stream<List<Obra>> watchObras(String construtoraId) {
    return _obrasRef(construtoraId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  /// Agregação cliente (AD-5): um stream por obra, sem `collectionGroup`.
  /// Filtra `isActive` no cliente.
  Stream<List<ObraMember>> watchObraMembers(
    String construtoraId,
    String obraId,
  ) {
    return _membersRef(construtoraId, obraId).snapshots().map(
          (snapshot) => snapshot.docs
              .map((d) => d.data())
              .where((m) => m.isActive)
              .toList(),
        );
  }

  // Se o user for admin da construtora, traz todas as obras dela.
  // Senão, usa collectionGroup('members') e filtra localmente pela construtora.
  Future<List<Obra>> getConstrutoraObras(
    String construtoraId,
    String userId,
    ConstrutoraMember member,
  ) => cachedRead(
    'construtoras/$construtoraId/obras/$userId',
    () => _loadgetConstrutoraObras(construtoraId, userId, member),
    (items) => items.map((e) => e.toJson()).toList(),
    (data) => (data as List)
        .map((e) => Obra.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  Future<List<Obra>> _loadgetConstrutoraObras(
    String construtoraId,
    String userId,
    ConstrutoraMember member,
  ) async {
    if (member.isAdmin || member.isOwner) {
      final querySnapshot = await _obrasRef(construtoraId)
          .get(const GetOptions(source: Source.server));
      return querySnapshot.docs.map((d) => d.data()).toList();
    } else {
      final querySnapshot = await _firestore
          .collectionGroup('members')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.server));

      final obrasFutures = querySnapshot.docs
          .where(
            (doc) {
              final obraRef = doc.reference.parent.parent;
              final construtoraRef = obraRef?.parent.parent;
              return construtoraRef != null && construtoraRef.id == construtoraId;
            },
          )
          .map((doc) async {
            final obraDocRef = doc.reference.parent.parent;
            if (obraDocRef == null) return null;
            final obraDoc = await obraDocRef
                .withConverter<Obra>(
                  fromFirestore: (snapshot, _) =>
                      Obra.fromJson(snapshot.data()!),
                  toFirestore: (obra, _) => obra.toJson(),
                )
                .get(const GetOptions(source: Source.server));
            return obraDoc.data();
          })
          .toList();

      final allUserObras = await Future.wait(obrasFutures);
      // Filtra apenas as obras pertencentes a esta construtora específica
      return allUserObras
          .whereType<Obra>()
          .where((obra) => obra.construtoraId == construtoraId)
          .toList();
    }
  }
}

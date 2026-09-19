import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/membro.dart';

class MembrosRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  MembrosRepository(this._firestore, this._functions);

  Stream<List<Membro>> watchMembros(String construtoraId) {
    return _firestore
        .collection('construtoras')
        .doc(construtoraId)
        .collection('construtora_members')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Membro.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> concederAcesso(
    String email,
    String role,
    String construtoraId, {
    bool? isOwner,
  }) async {
    try {
      final callable = _functions.httpsCallable('setConstrutoraRole');
      final payload = <String, dynamic>{
        'email': email,
        'construtoraId': construtoraId,
        'role': role,
      };
      if (isOwner != null || role == 'owner') {
        payload['isOwner'] = isOwner ?? true;
      }
      await callable.call(payload);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Erro ao chamar função Cloud Function');
    } catch (e) {
      throw Exception('Erro desconhecido: $e');
    }
  }
}

final membrosRepositoryProvider = Provider<MembrosRepository>((ref) {
  return MembrosRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
  );
});

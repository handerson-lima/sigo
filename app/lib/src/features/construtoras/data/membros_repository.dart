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

  Stream<List<Map<String, dynamic>>> watchPendingRequests(String construtoraId) {
    return _firestore
        .collection('access_requests')
        .where('construtoraId', isEqualTo: construtoraId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> watchAllPendingRequests() {
    return _firestore
        .collection('access_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  /// Retorna `true` se o e-mail não existe e uma solicitação foi criada.
  Future<bool> concederAcesso(
    String email,
    String role,
    String construtoraId, {
    bool? isOwner,
    String? displayName,
  }) async {
    try {
      final callable = _functions.httpsCallable('setConstrutoraRole');
      final payload = <String, dynamic>{
        'email': email,
        'construtoraId': construtoraId,
        'role': role,
        if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
      };
      if (isOwner != null || role == 'owner') {
        payload['isOwner'] = isOwner ?? true;
      }
      final result = await callable.call(payload);
      return result.data?['pendingCreation'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Erro ao chamar função Cloud Function');
    } catch (e) {
      throw Exception('Erro desconhecido: $e');
    }
  }

  Future<void> approveAccessRequest(String requestId, String password) async {
    try {
      final callable = _functions.httpsCallable('approveAccessRequest');
      await callable.call({'requestId': requestId, 'password': password});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Erro ao aprovar solicitação');
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

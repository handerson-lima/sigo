import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositório responsável pela gestão de membros de obra via Cloud Functions autorizadas.
class ObraMembersRepository {
  final FirebaseFunctions _functions;

  ObraMembersRepository(this._functions);

  /// Chama a Cloud Function autoritativa `setMembership` para atribuir ou atualizar
  /// papel e módulos de um membro em uma obra específica.
  Future<void> setMembership({
    required String construtoraId,
    required String obraId,
    required String userId,
    required String role,
    required List<String> modules,
    bool isActive = true,
  }) async {
    try {
      final callable = _functions.httpsCallable('setMembership');
      await callable.call({
        'construtoraId': construtoraId,
        'obraId': obraId,
        'userId': userId,
        'role': role,
        'modules': modules,
        'isActive': isActive,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Erro ao chamar setMembership');
    } catch (e) {
      throw Exception('Erro desconhecido: $e');
    }
  }
}

final obraMembersRepositoryProvider = Provider<ObraMembersRepository>((ref) {
  return ObraMembersRepository(
    FirebaseFunctions.instance,
  );
});

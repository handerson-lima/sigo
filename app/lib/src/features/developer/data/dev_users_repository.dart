import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mensagem pt-br exibida quando o dispositivo está sem conectividade.
const mensagemSemConexaoDevUsers =
    'Sem conexão. Verifique sua internet e tente novamente.';

/// Traduz códigos de [FirebaseFunctionsException] das callables de gestão de usuários para pt-br.
String traduzirErroDevUsers(FirebaseFunctionsException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'Você não tem permissão para executar esta operação.';
    case 'failed-precondition':
      return (e.message?.isNotEmpty ?? false)
          ? e.message!
          : 'Pré-condição não atendida para esta operação.';
    case 'not-found':
      return 'Usuário ou registro não encontrado.';
    case 'invalid-argument':
      return (e.message?.isNotEmpty ?? false)
          ? e.message!
          : 'Dados inválidos para esta operação.';
    case 'already-exists':
      return (e.message?.isNotEmpty ?? false)
          ? e.message!
          : 'Este e-mail ou operação já existe.';
    case 'unavailable':
      return 'Serviço temporariamente indisponível. Tente novamente.';
    case 'unauthenticated':
      return 'Sessão expirada. Entre novamente.';
    case 'internal':
      return 'Erro interno no servidor (verifique se as Cloud Functions e regras foram publicadas).';
    default:
      return (e.message?.isNotEmpty ?? false)
          ? e.message!
          : 'Erro ao executar operação de usuário.';
  }
}

/// Remove o prefixo `Exception: ` ao exibir mensagens de erro na UI.
String formatarErroDevUsers(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

/// Repositório para operações administrativas de usuários pelo perfil `dev`.
class DevUsersRepository {
  final FirebaseFunctions? _functions;
  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final Future<dynamic> Function(String name, Map<String, dynamic> data)?
      _callFunction;

  DevUsersRepository(
    this._functions, {
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    this._callFunction,
  }) : _checkConnectivity = checkConnectivity ?? _defaultCheckConnectivity;

  static Future<List<ConnectivityResult>> _defaultCheckConnectivity() =>
      Connectivity().checkConnectivity();

  /// Exclui globalmente um usuário (Auth + perfil, notificações e vínculos).
  Future<void> adminDeleteUser(String userId) async {
    await _invoke('adminDeleteUser', {'userId': userId});
  }

  /// Ativa ou desativa um usuário no Auth e em `users/{uid}.isActive`.
  Future<void> adminSetUserActive(String userId, bool isActive) async {
    await _invoke('adminSetUserActive', {
      'userId': userId,
      'isActive': isActive,
    });
  }

  /// Redefine a senha provisória de um usuário no Auth (mínimo 8 caracteres).
  Future<void> adminResetUserPassword(String userId, String password) async {
    await _invoke('adminResetUserPassword', {
      'userId': userId,
      'password': password,
    });
  }

  /// Cria um novo usuário global via Cloud Function `adminCreateUser`.
  Future<void> adminCreateUser({
    required String email,
    required String password,
    required String displayName,
    required String operationId,
    String globalRole = 'user',
  }) async {
    await _invoke('adminCreateUser', {
      'email': email,
      'password': password,
      'displayName': displayName,
      'operationId': operationId,
      'globalRole': globalRole,
    });
  }

  /// Concede ou revoga o papel global de desenvolvedor (`dev_roles/{uid}`).
  Future<void> setDevRole(String userId, bool isActive) async {
    await _invoke('setDevRole', {'userId': userId, 'isActive': isActive});
  }

  /// Cria, atualiza ou desativa vínculo de usuário com uma construtora.
  Future<void> setMembership({
    required String construtoraId,
    required String userId,
    required String role,
    bool? isOwner,
    List<String> modules = const [],
    bool isActive = true,
  }) async {
    await _invoke('setMembership', {
      'construtoraId': construtoraId,
      'userId': userId,
      'role': role,
      'isOwner': ?isOwner,
      'modules': modules,
      'isActive': isActive,
    });
  }

  Future<void> _invoke(String name, Map<String, dynamic> payload) async {
    if (!await _temConectividade()) {
      throw Exception(mensagemSemConexaoDevUsers);
    }

    try {
      final call = _callFunction;
      if (call != null) {
        await call(name, payload);
      } else {
        await _functions!.httpsCallable(name).call(payload);
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(traduzirErroDevUsers(e));
    } catch (e) {
      if ('$e'.contains('SocketException')) {
        throw Exception(mensagemSemConexaoDevUsers);
      }
      throw Exception('Erro desconhecido: $e');
    }
  }

  Future<bool> _temConectividade() async {
    try {
      final results = await _checkConnectivity();
      return results.isEmpty ||
          results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }
}

final devUsersRepositoryProvider = Provider<DevUsersRepository>((ref) {
  return DevUsersRepository(FirebaseFunctions.instance);
});

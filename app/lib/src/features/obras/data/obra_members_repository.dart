import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mensagem exibida quando o dispositivo está sem conectividade antes da chamada.
const mensagemSemConexao =
    'Sem conexão. Verifique sua internet e tente novamente.';

/// Mensagem para erro `permission-denied` da Cloud Function `setMembership`.
const mensagemSemPermissao =
    'Você não tem permissão para realizar esta atribuição.';

/// Mensagem para erro `failed-precondition` da Cloud Function `setMembership`.
const mensagemPreCondicao =
    'Pré-condição não atendida: verifique se o membro está ativo na construtora.';

/// Traduz o código de [FirebaseFunctionsException] de `setMembership` para pt-br.
String traduzirErroSetMembership(FirebaseFunctionsException e) {
  switch (e.code) {
    case 'permission-denied':
      return mensagemSemPermissao;
    case 'failed-precondition':
      return mensagemPreCondicao;
    default:
      return (e.message?.isNotEmpty ?? false)
          ? e.message!
          : 'Erro ao chamar setMembership';
  }
}

/// Repositório responsável pela gestão de membros de obra via Cloud Functions autorizadas.
class ObraMembersRepository {
  final FirebaseFunctions? _functions;
  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final Future<dynamic> Function(Map<String, dynamic> data)? _callSetMembership;

  ObraMembersRepository(
    this._functions, {
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    Future<dynamic> Function(Map<String, dynamic> data)? callSetMembership,
  })  : _checkConnectivity = checkConnectivity ?? _defaultCheckConnectivity,
        // ignore: prefer_initializing_formals
        _callSetMembership = callSetMembership;

  static Future<List<ConnectivityResult>> _defaultCheckConnectivity() =>
      Connectivity().checkConnectivity();

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
    if (!await _temConectividade()) {
      throw Exception(mensagemSemConexao);
    }

    final payload = <String, dynamic>{
      'construtoraId': construtoraId,
      'obraId': obraId,
      'userId': userId,
      'role': role,
      'modules': modules,
      'isActive': isActive,
    };

    try {
      final call = _callSetMembership;
      if (call != null) {
        await call(payload);
      } else {
        await _functions!.httpsCallable('setMembership').call(payload);
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(traduzirErroSetMembership(e));
    } catch (e) {
      if ('$e'.contains('SocketException')) {
        throw Exception(mensagemSemConexao);
      }
      throw Exception('Erro desconhecido: $e');
    }
  }

  /// Verifica conectividade antes de disparar a CF (operação online-only, AD-6).
  Future<bool> _temConectividade() async {
    try {
      final results = await _checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Em dúvida (plugin indisponível), deixa a chamada tentar e o catch tratar.
      return true;
    }
  }
}

final obraMembersRepositoryProvider = Provider<ObraMembersRepository>((ref) {
  return ObraMembersRepository(
    FirebaseFunctions.instance,
  );
});

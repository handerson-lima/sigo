import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/read_cache.dart';
import '../domain/fornecedor.dart';
import '../domain/fornecedor_validator.dart';

final fornecedoresRepositoryProvider = Provider<FornecedoresRepository>((ref) {
  return FornecedoresRepository(FirebaseFirestore.instance);
});

final fornecedoresStreamProvider =
    StreamProvider.family<
      List<Fornecedor>,
      ({String construtoraId, bool apenasAtivos})
    >((ref, arg) {
      return ref
          .watch(fornecedoresRepositoryProvider)
          .watchFornecedores(arg.construtoraId, apenasAtivos: arg.apenasAtivos);
    });

final fornecedorDetailsFutureProvider =
    FutureProvider.family<
      Fornecedor?,
      ({String construtoraId, String fornecedorId})
    >((ref, arg) {
      return ref
          .watch(fornecedoresRepositoryProvider)
          .getFornecedorById(arg.construtoraId, arg.fornecedorId);
    });

class DocumentoDuplicadoException implements Exception {
  final String message;
  DocumentoDuplicadoException(this.message);

  @override
  String toString() => message;
}

class DocumentoInvalidoException implements Exception {
  final String message;
  DocumentoInvalidoException(this.message);

  @override
  String toString() => message;
}

class FornecedoresRepository {
  final FirebaseFirestore _firestore;

  FornecedoresRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _fornecedoresRef(
    String construtoraId,
  ) {
    return _firestore
        .collection('construtoras')
        .doc(construtoraId)
        .collection('fornecedores');
  }

  /// Observa os fornecedores da construtora com cache offline
  Stream<List<Fornecedor>> watchFornecedores(
    String construtoraId, {
    bool apenasAtivos = false,
  }) {
    Query<Map<String, dynamic>> query = _fornecedoresRef(construtoraId)
        .orderBy('razaoSocial', descending: false);

    if (apenasAtivos) {
      query = query.where('status', isEqualTo: StatusFornecedor.ativo.name);
    }

    final cacheKey =
        'fornecedores/$construtoraId${apenasAtivos ? "_ativos" : ""}';

    return cachedList<Fornecedor>(
      cacheKey,
      query
          .snapshots(includeMetadataChanges: true)
          .where((s) => !s.metadata.isFromCache)
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Fornecedor.fromJson(doc.data()))
                .toList(),
          ),
      (f) => f.toJson(),
      (item) => Fornecedor.fromJson(Map<String, dynamic>.from(item)),
    );
  }

  /// Busca a lista de fornecedores pontualmente
  Future<List<Fornecedor>> getFornecedores(
    String construtoraId, {
    bool apenasAtivos = false,
  }) async {
    Query<Map<String, dynamic>> query = _fornecedoresRef(construtoraId)
        .orderBy('razaoSocial', descending: false);

    if (apenasAtivos) {
      query = query.where('status', isEqualTo: StatusFornecedor.ativo.name);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Fornecedor.fromJson(doc.data())).toList();
  }

  /// Busca um fornecedor por ID
  Future<Fornecedor?> getFornecedorById(
    String construtoraId,
    String fornecedorId,
  ) async {
    final doc = await _fornecedoresRef(construtoraId).doc(fornecedorId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Fornecedor.fromJson(doc.data()!);
  }

  /// Salva ou atualiza um fornecedor com validação fiscal e checagem de duplicidade
  Future<void> salvarFornecedor(Fornecedor fornecedor) async {
    final docSanitizado = FornecedorValidator.apenasDigitos(
      fornecedor.documento,
    );

    // Validação de documento oficial
    final isValido = FornecedorValidator.validarDocumento(
      docSanitizado,
      isPessoaJuridica: fornecedor.isPessoaJuridica,
    );

    if (!isValido) {
      final tipo = fornecedor.isPessoaJuridica ? 'CNPJ' : 'CPF';
      throw DocumentoInvalidoException(
        '$tipo informado é inválido de acordo com o cálculo oficial.',
      );
    }

    // Validação de unicidade na mesma construtora
    final queryDuplicados = await _fornecedoresRef(fornecedor.construtoraId)
        .where('documento', isEqualTo: docSanitizado)
        .get();

    for (final doc in queryDuplicados.docs) {
      if (doc.id != fornecedor.id) {
        final outroNome = doc.data()['razaoSocial'] ?? 'Outro fornecedor';
        throw DocumentoDuplicadoException(
          'Já existe um fornecedor cadastrado com este documento: $outroNome',
        );
      }
    }

    final now = DateTime.now();
    final itemToSave = fornecedor.copyWith(
      documento: docSanitizado,
      updatedAt: now,
      createdAt: fornecedor.createdAt ?? now,
    );

    await _fornecedoresRef(fornecedor.construtoraId)
        .doc(itemToSave.id)
        .set(itemToSave.toJson(), SetOptions(merge: true));
  }

  /// Alterna status de ativação (soft-disable em conformidade com AD-7)
  Future<void> toggleStatus(
    String construtoraId,
    String fornecedorId,
    bool ativo, {
    String? atualizadoPorUid,
  }) async {
    await _fornecedoresRef(construtoraId).doc(fornecedorId).update({
      'status': ativo
          ? StatusFornecedor.ativo.name
          : StatusFornecedor.inativo.name,
      'updatedAt': DateTime.now().toIso8601String(),
      'atualizadoPorUid': ?atualizadoPorUid,
    });
  }
}

import 'fornecedor_validator.dart';

enum TipoPessoa {
  juridica,
  fisica;

  static TipoPessoa fromString(String? val) {
    if (val == 'fisica' || val == 'PF') return TipoPessoa.fisica;
    return TipoPessoa.juridica;
  }

  String get label => this == TipoPessoa.juridica
      ? 'Pessoa Jurídica (PJ)'
      : 'Pessoa Física (PF)';
}

enum StatusFornecedor {
  ativo,
  inativo;

  static StatusFornecedor fromString(String? val) {
    if (val == 'inativo') return StatusFornecedor.inativo;
    return StatusFornecedor.ativo;
  }
}

class EnderecoFornecedor {
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? uf;

  const EnderecoFornecedor({
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.uf,
  });

  Map<String, dynamic> toJson() => {
    if (cep != null) 'cep': cep,
    if (logradouro != null) 'logradouro': logradouro,
    if (numero != null) 'numero': numero,
    if (complemento != null) 'complemento': complemento,
    if (bairro != null) 'bairro': bairro,
    if (cidade != null) 'cidade': cidade,
    if (uf != null) 'uf': uf,
  };

  factory EnderecoFornecedor.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EnderecoFornecedor();
    return EnderecoFornecedor(
      cep: json['cep'] as String?,
      logradouro: json['logradouro'] as String?,
      numero: json['numero'] as String?,
      complemento: json['complemento'] as String?,
      bairro: json['bairro'] as String?,
      cidade: json['cidade'] as String?,
      uf: json['uf'] as String?,
    );
  }

  String get formatado {
    final partes = <String>[];
    if (logradouro != null && logradouro!.isNotEmpty) {
      partes.add(
        logradouro! + (numero != null && numero!.isNotEmpty ? ', $numero' : ''),
      );
    }
    if (bairro != null && bairro!.isNotEmpty) partes.add(bairro!);
    if (cidade != null && cidade!.isNotEmpty) {
      partes.add(cidade! + (uf != null && uf!.isNotEmpty ? '/$uf' : ''));
    }
    if (cep != null && cep!.isNotEmpty) {
      partes.add('CEP: ${FornecedorValidator.formatarCep(cep)}');
    }
    return partes.join(' - ');
  }
}

class DadosBancariosFornecedor {
  final String? chavePix;
  final String? tipoChavePix; // cpf, cnpj, email, telefone, aleatoria
  final String? banco;
  final String? codigoBanco;
  final String? agencia;
  final String? contaCorrente;
  final String? favorecido;

  const DadosBancariosFornecedor({
    this.chavePix,
    this.tipoChavePix,
    this.banco,
    this.codigoBanco,
    this.agencia,
    this.contaCorrente,
    this.favorecido,
  });

  Map<String, dynamic> toJson() => {
    if (chavePix != null) 'chavePix': chavePix,
    if (tipoChavePix != null) 'tipoChavePix': tipoChavePix,
    if (banco != null) 'banco': banco,
    if (codigoBanco != null) 'codigoBanco': codigoBanco,
    if (agencia != null) 'agencia': agencia,
    if (contaCorrente != null) 'contaCorrente': contaCorrente,
    if (favorecido != null) 'favorecido': favorecido,
  };

  factory DadosBancariosFornecedor.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DadosBancariosFornecedor();
    return DadosBancariosFornecedor(
      chavePix: json['chavePix'] as String?,
      tipoChavePix: json['tipoChavePix'] as String?,
      banco: json['banco'] as String?,
      codigoBanco: json['codigoBanco'] as String?,
      agencia: json['agencia'] as String?,
      contaCorrente: json['contaCorrente'] as String?,
      favorecido: json['favorecido'] as String?,
    );
  }
}

class Fornecedor {
  final String id;
  final String construtoraId;
  final TipoPessoa tipoPessoa;
  final String documento; // Apenas números
  final String razaoSocial;
  final String? nomeFantasia;
  final String? inscricaoEstadual;
  final String? inscricaoMunicipal;
  final String? email;
  final String? telefone;
  final String? whatsapp;
  final String? nomeContato;
  final EnderecoFornecedor? endereco;
  final List<String> categorias;
  final DadosBancariosFornecedor? dadosBancarios;
  final String? observacoes;
  final StatusFornecedor status;
  final String? criadoPorUid;
  final String? atualizadoPorUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Fornecedor({
    required this.id,
    required this.construtoraId,
    required this.tipoPessoa,
    required this.documento,
    required this.razaoSocial,
    this.nomeFantasia,
    this.inscricaoEstadual,
    this.inscricaoMunicipal,
    this.email,
    this.telefone,
    this.whatsapp,
    this.nomeContato,
    this.endereco,
    this.categorias = const [],
    this.dadosBancarios,
    this.observacoes,
    this.status = StatusFornecedor.ativo,
    this.criadoPorUid,
    this.atualizadoPorUid,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAtivo => status == StatusFornecedor.ativo;
  bool get isPessoaJuridica => tipoPessoa == TipoPessoa.juridica;

  /// Retorna o nome amigável para exibição (Nome Fantasia se houver, ou Razão Social).
  String get nomeExibicao {
    if (nomeFantasia != null && nomeFantasia!.trim().isNotEmpty) {
      return nomeFantasia!.trim();
    }
    return razaoSocial;
  }

  /// Retorna o documento formatado com pontuação (CNPJ ou CPF).
  String get documentoFormatado =>
      FornecedorValidator.formatarDocumento(documento);

  Fornecedor copyWith({
    String? id,
    String? construtoraId,
    TipoPessoa? tipoPessoa,
    String? documento,
    String? razaoSocial,
    String? nomeFantasia,
    String? inscricaoEstadual,
    String? inscricaoMunicipal,
    String? email,
    String? telefone,
    String? whatsapp,
    String? nomeContato,
    EnderecoFornecedor? endereco,
    List<String>? categorias,
    DadosBancariosFornecedor? dadosBancarios,
    String? observacoes,
    StatusFornecedor? status,
    String? criadoPorUid,
    String? atualizadoPorUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Fornecedor(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      tipoPessoa: tipoPessoa ?? this.tipoPessoa,
      documento: documento ?? this.documento,
      razaoSocial: razaoSocial ?? this.razaoSocial,
      nomeFantasia: nomeFantasia ?? this.nomeFantasia,
      inscricaoEstadual: inscricaoEstadual ?? this.inscricaoEstadual,
      inscricaoMunicipal: inscricaoMunicipal ?? this.inscricaoMunicipal,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      whatsapp: whatsapp ?? this.whatsapp,
      nomeContato: nomeContato ?? this.nomeContato,
      endereco: endereco ?? this.endereco,
      categorias: categorias ?? this.categorias,
      dadosBancarios: dadosBancarios ?? this.dadosBancarios,
      observacoes: observacoes ?? this.observacoes,
      status: status ?? this.status,
      criadoPorUid: criadoPorUid ?? this.criadoPorUid,
      atualizadoPorUid: atualizadoPorUid ?? this.atualizadoPorUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'tipoPessoa': tipoPessoa.name,
      'documento': FornecedorValidator.apenasDigitos(documento),
      'razaoSocial': razaoSocial,
      if (nomeFantasia != null) 'nomeFantasia': nomeFantasia,
      if (inscricaoEstadual != null) 'inscricaoEstadual': inscricaoEstadual,
      if (inscricaoMunicipal != null) 'inscricaoMunicipal': inscricaoMunicipal,
      if (email != null) 'email': email,
      if (telefone != null) 'telefone': telefone,
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (nomeContato != null) 'nomeContato': nomeContato,
      if (endereco != null) 'endereco': endereco!.toJson(),
      'categorias': categorias,
      if (dadosBancarios != null) 'dadosBancarios': dadosBancarios!.toJson(),
      if (observacoes != null) 'observacoes': observacoes,
      'status': status.name,
      if (criadoPorUid != null) 'criadoPorUid': criadoPorUid,
      if (atualizadoPorUid != null) 'atualizadoPorUid': atualizadoPorUid,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory Fornecedor.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      try {
        // Support Firestore Timestamp if present
        final dynamic ts = value;
        return ts.toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return Fornecedor(
      id: json['id'] as String? ?? '',
      construtoraId: json['construtoraId'] as String? ?? '',
      tipoPessoa: TipoPessoa.fromString(json['tipoPessoa'] as String?),
      documento: FornecedorValidator.apenasDigitos(
        json['documento'] as String?,
      ),
      razaoSocial: json['razaoSocial'] as String? ?? '',
      nomeFantasia: json['nomeFantasia'] as String?,
      inscricaoEstadual: json['inscricaoEstadual'] as String?,
      inscricaoMunicipal: json['inscricaoMunicipal'] as String?,
      email: json['email'] as String?,
      telefone: json['telefone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      nomeContato: json['nomeContato'] as String?,
      endereco: json['endereco'] is Map<String, dynamic>
          ? EnderecoFornecedor.fromJson(
              json['endereco'] as Map<String, dynamic>,
            )
          : null,
      categorias:
          (json['categorias'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dadosBancarios: json['dadosBancarios'] is Map<String, dynamic>
          ? DadosBancariosFornecedor.fromJson(
              json['dadosBancarios'] as Map<String, dynamic>,
            )
          : null,
      observacoes: json['observacoes'] as String?,
      status: StatusFornecedor.fromString(json['status'] as String?),
      criadoPorUid: json['criadoPorUid'] as String?,
      atualizadoPorUid: json['atualizadoPorUid'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}

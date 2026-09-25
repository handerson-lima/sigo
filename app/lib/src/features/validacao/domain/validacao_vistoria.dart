import 'package:cloud_firestore/cloud_firestore.dart';

enum ValidacaoStatus {
  pendente,
  aprovado,
  reprovado,
  reaberto;

  String get label {
    switch (this) {
      case ValidacaoStatus.pendente:
        return 'Pendente';
      case ValidacaoStatus.aprovado:
        return 'Aprovado';
      case ValidacaoStatus.reprovado:
        return 'Reprovado';
      case ValidacaoStatus.reaberto:
        return 'Reaberto';
    }
  }

  static ValidacaoStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'aprovado':
        return ValidacaoStatus.aprovado;
      case 'reprovado':
        return ValidacaoStatus.reprovado;
      case 'reaberto':
        return ValidacaoStatus.reaberto;
      case 'pendente':
      default:
        return ValidacaoStatus.pendente;
    }
  }
}

enum ItemConformidadeStatus {
  conforme,
  // ignore: constant_identifier_names
  nao_conforme,
  // ignore: constant_identifier_names
  nao_se_aplica;

  String get label {
    switch (this) {
      case ItemConformidadeStatus.conforme:
        return 'Conforme';
      case ItemConformidadeStatus.nao_conforme:
        return 'Não Conforme';
      case ItemConformidadeStatus.nao_se_aplica:
        return 'Não se Aplica';
    }
  }

  static ItemConformidadeStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'nao_conforme':
      case 'naoconforme':
      case 'reprovado':
        return ItemConformidadeStatus.nao_conforme;
      case 'nao_se_aplica':
      case 'naoseaplica':
      case 'na':
        return ItemConformidadeStatus.nao_se_aplica;
      case 'conforme':
      case 'aprovado':
      default:
        return ItemConformidadeStatus.conforme;
    }
  }
}

class ItemRespondido {
  final String itemId;
  final String titulo;
  final ItemConformidadeStatus status;
  final String? observacao;
  final List<String> fotos;
  final bool obrigatorio;
  final bool requerFotoSeReprovado;

  const ItemRespondido({
    required this.itemId,
    required this.titulo,
    required this.status,
    this.observacao,
    this.fotos = const [],
    this.obrigatorio = true,
    this.requerFotoSeReprovado = true,
  });

  bool get isConforme => status == ItemConformidadeStatus.conforme;
  bool get isNaoConforme => status == ItemConformidadeStatus.nao_conforme;
  bool get isNaoSeAplica => status == ItemConformidadeStatus.nao_se_aplica;

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'titulo': titulo,
      'status': status.name,
      'observacao': observacao,
      'fotos': fotos,
      'obrigatorio': obrigatorio,
      'requerFotoSeReprovado': requerFotoSeReprovado,
    };
  }

  factory ItemRespondido.fromMap(Map<String, dynamic> map) {
    final rawFotos = map['fotos'] as List<dynamic>? ?? [];
    return ItemRespondido(
      itemId: map['itemId'] as String? ?? map['id'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      status: ItemConformidadeStatus.fromString(map['status'] as String?),
      observacao: map['observacao'] as String?,
      fotos: rawFotos.map((f) => f.toString()).toList(),
      obrigatorio: map['obrigatorio'] as bool? ?? true,
      requerFotoSeReprovado: map['requerFotoSeReprovado'] as bool? ?? true,
    );
  }

  ItemRespondido copyWith({
    String? itemId,
    String? titulo,
    ItemConformidadeStatus? status,
    String? observacao,
    List<String>? fotos,
    bool? obrigatorio,
    bool? requerFotoSeReprovado,
  }) {
    return ItemRespondido(
      itemId: itemId ?? this.itemId,
      titulo: titulo ?? this.titulo,
      status: status ?? this.status,
      observacao: observacao ?? this.observacao,
      fotos: fotos ?? this.fotos,
      obrigatorio: obrigatorio ?? this.obrigatorio,
      requerFotoSeReprovado:
          requerFotoSeReprovado ?? this.requerFotoSeReprovado,
    );
  }
}

class ValidacaoVistoria {
  final String id;
  final String construtoraId;
  final String obraId;
  final String loteId;
  final String templateId;
  final String templateTitulo;
  final String disciplina;
  final int templateVersion;
  final ValidacaoStatus status;
  final String inspetorUid;
  final String inspetorNome;
  final DateTime dataVistoria;
  final DateTime? dataFinalizacao;
  final String? observacoesGerais;
  final List<ItemRespondido> itensRespondidos;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ValidacaoVistoria({
    required this.id,
    required this.construtoraId,
    required this.obraId,
    required this.loteId,
    required this.templateId,
    required this.templateTitulo,
    required this.disciplina,
    required this.templateVersion,
    this.status = ValidacaoStatus.pendente,
    required this.inspetorUid,
    required this.inspetorNome,
    required this.dataVistoria,
    this.dataFinalizacao,
    this.observacoesGerais,
    this.itensRespondidos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPendente => status == ValidacaoStatus.pendente;
  bool get isAprovado => status == ValidacaoStatus.aprovado;
  bool get isReprovado => status == ValidacaoStatus.reprovado;
  bool get isReaberto => status == ValidacaoStatus.reaberto;

  bool get hasNaoConforme => itensRespondidos.any((i) => i.isNaoConforme);

  int get totalItens => itensRespondidos.length;
  int get totalConformes => itensRespondidos.where((i) => i.isConforme).length;
  int get totalNaoConformes =>
      itensRespondidos.where((i) => i.isNaoConforme).length;
  int get totalNaoSeAplica =>
      itensRespondidos.where((i) => i.isNaoSeAplica).length;

  /// Retorna lista de mensagens de erro caso a vistoria não atenda os critérios de finalização.
  List<String> validarParaConclusao() {
    final erros = <String>[];

    if (itensRespondidos.isEmpty) {
      erros.add('Nenhum item avaliado no checklist.');
      return erros;
    }

    for (final item in itensRespondidos) {
      if (item.isNaoConforme) {
        if (item.observacao == null || item.observacao!.trim().isEmpty) {
          erros.add(
            'O item "${item.titulo}" é Não Conforme e exige descrição de observação.',
          );
        }
        if (item.requerFotoSeReprovado && item.fotos.isEmpty) {
          erros.add(
            'O item "${item.titulo}" é Não Conforme e exige pelo menos 1 foto de evidência.',
          );
        }
      }
    }

    return erros;
  }

  /// Calcula o status final determinístico
  ValidacaoStatus calcularStatusFinal() {
    if (hasNaoConforme) {
      return ValidacaoStatus.reprovado;
    }
    return ValidacaoStatus.aprovado;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'obraId': obraId,
      'loteId': loteId,
      'templateId': templateId,
      'templateTitulo': templateTitulo,
      'disciplina': disciplina,
      'templateVersion': templateVersion,
      'status': status.name,
      'inspetorUid': inspetorUid,
      'inspetorNome': inspetorNome,
      'dataVistoria': Timestamp.fromDate(dataVistoria),
      'dataFinalizacao': dataFinalizacao != null
          ? Timestamp.fromDate(dataFinalizacao!)
          : null,
      'observacoesGerais': observacoesGerais,
      'itensRespondidos': itensRespondidos.map((i) => i.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ValidacaoVistoria.fromMap(
    Map<String, dynamic> map, [
    String? documentId,
  ]) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final created = parseDate(map['createdAt'], DateTime.now());
    final updated = parseDate(map['updatedAt'], created);
    final vistoriaDate = parseDate(map['dataVistoria'], created);
    DateTime? finalizacaoDate;
    if (map['dataFinalizacao'] != null) {
      finalizacaoDate = parseDate(map['dataFinalizacao'], created);
    }

    final rawItens = map['itensRespondidos'] as List<dynamic>? ?? [];
    final parsedItens = rawItens
        .map(
          (item) =>
              ItemRespondido.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    return ValidacaoVistoria(
      id: documentId ?? (map['id'] as String? ?? ''),
      construtoraId: map['construtoraId'] as String? ?? '',
      obraId: map['obraId'] as String? ?? '',
      loteId: map['loteId'] as String? ?? '',
      templateId: map['templateId'] as String? ?? '',
      templateTitulo: map['templateTitulo'] as String? ?? '',
      disciplina: map['disciplina'] as String? ?? '',
      templateVersion: (map['templateVersion'] as num?)?.toInt() ?? 1,
      status: ValidacaoStatus.fromString(map['status'] as String?),
      inspetorUid: map['inspetorUid'] as String? ?? '',
      inspetorNome: map['inspetorNome'] as String? ?? '',
      dataVistoria: vistoriaDate,
      dataFinalizacao: finalizacaoDate,
      observacoesGerais: map['observacoesGerais'] as String?,
      itensRespondidos: parsedItens,
      createdAt: created,
      updatedAt: updated,
    );
  }

  ValidacaoVistoria copyWith({
    String? id,
    String? construtoraId,
    String? obraId,
    String? loteId,
    String? templateId,
    String? templateTitulo,
    String? disciplina,
    int? templateVersion,
    ValidacaoStatus? status,
    String? inspetorUid,
    String? inspetorNome,
    DateTime? dataVistoria,
    DateTime? dataFinalizacao,
    String? observacoesGerais,
    List<ItemRespondido>? itensRespondidos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ValidacaoVistoria(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      obraId: obraId ?? this.obraId,
      loteId: loteId ?? this.loteId,
      templateId: templateId ?? this.templateId,
      templateTitulo: templateTitulo ?? this.templateTitulo,
      disciplina: disciplina ?? this.disciplina,
      templateVersion: templateVersion ?? this.templateVersion,
      status: status ?? this.status,
      inspetorUid: inspetorUid ?? this.inspetorUid,
      inspetorNome: inspetorNome ?? this.inspetorNome,
      dataVistoria: dataVistoria ?? this.dataVistoria,
      dataFinalizacao: dataFinalizacao ?? this.dataFinalizacao,
      observacoesGerais: observacoesGerais ?? this.observacoesGerais,
      itensRespondidos: itensRespondidos ?? this.itensRespondidos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ChecklistTemplateItem {
  final String id;
  final String titulo;
  final String descricao;
  final bool obrigatorio;
  final bool requerFotoSeReprovado;

  const ChecklistTemplateItem({
    required this.id,
    required this.titulo,
    this.descricao = '',
    this.obrigatorio = true,
    this.requerFotoSeReprovado = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'obrigatorio': obrigatorio,
      'requerFotoSeReprovado': requerFotoSeReprovado,
    };
  }

  factory ChecklistTemplateItem.fromMap(Map<String, dynamic> map) {
    return ChecklistTemplateItem(
      id: map['id'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      descricao: map['descricao'] as String? ?? '',
      obrigatorio: map['obrigatorio'] as bool? ?? true,
      requerFotoSeReprovado: map['requerFotoSeReprovado'] as bool? ?? true,
    );
  }

  ChecklistTemplateItem copyWith({
    String? id,
    String? titulo,
    String? descricao,
    bool? obrigatorio,
    bool? requerFotoSeReprovado,
  }) {
    return ChecklistTemplateItem(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      obrigatorio: obrigatorio ?? this.obrigatorio,
      requerFotoSeReprovado:
          requerFotoSeReprovado ?? this.requerFotoSeReprovado,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistTemplateItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          titulo == other.titulo &&
          descricao == other.descricao &&
          obrigatorio == other.obrigatorio &&
          requerFotoSeReprovado == other.requerFotoSeReprovado;

  @override
  int get hashCode =>
      id.hashCode ^
      titulo.hashCode ^
      descricao.hashCode ^
      obrigatorio.hashCode ^
      requerFotoSeReprovado.hashCode;
}

class ValidacaoTemplate {
  final String id;
  final String construtoraId;
  final String titulo;
  final String disciplina;
  final int version;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChecklistTemplateItem> itens;

  const ValidacaoTemplate({
    required this.id,
    required this.construtoraId,
    required this.titulo,
    required this.disciplina,
    this.version = 1,
    this.ativo = true,
    required this.createdAt,
    required this.updatedAt,
    this.itens = const [],
  });

  String get disciplinaFormatada {
    switch (disciplina.toLowerCase()) {
      case 'alvenaria':
        return 'Alvenaria e Vedações';
      case 'estrutura':
        return 'Estrutura e Concreto';
      case 'fundacao':
        return 'Fundação e Solo';
      case 'eletrica':
      case 'instalacoes_eletricas':
        return 'Instalações Elétricas';
      case 'hidraulica':
      case 'instalacoes_hidraulicas':
        return 'Instalações Hidrossanitárias';
      case 'pintura':
        return 'Pintura e Tratamento';
      case 'acabamento':
        return 'Acabamentos e Revestimentos';
      case 'cobertura':
        return 'Cobertura e Impermeabilização';
      default:
        if (disciplina.isEmpty) return 'Geral';
        return disciplina[0].toUpperCase() + disciplina.substring(1);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'titulo': titulo,
      'disciplina': disciplina,
      'version': version,
      'ativo': ativo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'itens': itens.map((item) => item.toMap()).toList(),
    };
  }

  factory ValidacaoTemplate.fromMap(
    Map<String, dynamic> map, [
    String? documentId,
  ]) {
    final rawCreatedAt = map['createdAt'];
    DateTime created;
    if (rawCreatedAt is Timestamp) {
      created = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      created = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    final rawUpdatedAt = map['updatedAt'];
    DateTime updated;
    if (rawUpdatedAt is Timestamp) {
      updated = rawUpdatedAt.toDate();
    } else if (rawUpdatedAt is String) {
      updated = DateTime.tryParse(rawUpdatedAt) ?? created;
    } else {
      updated = created;
    }

    final rawItens = map['itens'] as List<dynamic>? ?? [];
    final parsedItens = rawItens
        .map((item) => ChecklistTemplateItem.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();

    return ValidacaoTemplate(
      id: documentId ?? (map['id'] as String? ?? ''),
      construtoraId: map['construtoraId'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      disciplina: map['disciplina'] as String? ?? '',
      version: (map['version'] as num?)?.toInt() ?? 1,
      ativo: map['ativo'] as bool? ?? true,
      createdAt: created,
      updatedAt: updated,
      itens: parsedItens,
    );
  }

  ValidacaoTemplate copyWith({
    String? id,
    String? construtoraId,
    String? titulo,
    String? disciplina,
    int? version,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChecklistTemplateItem>? itens,
  }) {
    return ValidacaoTemplate(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      titulo: titulo ?? this.titulo,
      disciplina: disciplina ?? this.disciplina,
      version: version ?? this.version,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      itens: itens ?? this.itens,
    );
  }
}

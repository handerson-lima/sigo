import 'package:json_annotation/json_annotation.dart';

import '../../../core/contracts.dart';

part 'loteamento.g.dart';

@JsonSerializable()
class Loteamento {
  final String id;
  final String construtoraId;
  final String? obraId;
  final String name;
  final String? bairro;
  final String? cidade;
  final String? uf;
  final String? proprietarioNome;
  final String? proprietarioDocumento;
  final String? responsavelTecnicoNome;
  final String? responsavelTecnicoRegistro;
  final DateTime createdAt;
  final DateTime updatedAt;

  Loteamento({
    required this.id,
    required this.construtoraId,
    this.obraId,
    required this.name,
    this.bairro,
    this.cidade,
    this.uf,
    this.proprietarioNome,
    this.proprietarioDocumento,
    this.responsavelTecnicoNome,
    this.responsavelTecnicoRegistro,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Retorna o ID efetivo da obra vinculada a este loteamento (fallback para `id`).
  String get effectiveObraId {
    final trimmed = obraId?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : id;
  }

  Loteamento copyWith({
    String? id,
    String? construtoraId,
    String? obraId,
    bool clearObraId = false,
    String? name,
    String? bairro,
    bool clearBairro = false,
    String? cidade,
    bool clearCidade = false,
    String? uf,
    bool clearUf = false,
    String? proprietarioNome,
    bool clearProprietarioNome = false,
    String? proprietarioDocumento,
    bool clearProprietarioDocumento = false,
    String? responsavelTecnicoNome,
    bool clearResponsavelTecnicoNome = false,
    String? responsavelTecnicoRegistro,
    bool clearResponsavelTecnicoRegistro = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Loteamento(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      obraId: clearObraId ? null : (obraId ?? this.obraId),
      name: name ?? this.name,
      bairro: clearBairro ? null : (bairro ?? this.bairro),
      cidade: clearCidade ? null : (cidade ?? this.cidade),
      uf: clearUf ? null : (uf ?? this.uf),
      proprietarioNome: clearProprietarioNome
          ? null
          : (proprietarioNome ?? this.proprietarioNome),
      proprietarioDocumento: clearProprietarioDocumento
          ? null
          : (proprietarioDocumento ?? this.proprietarioDocumento),
      responsavelTecnicoNome: clearResponsavelTecnicoNome
          ? null
          : (responsavelTecnicoNome ?? this.responsavelTecnicoNome),
      responsavelTecnicoRegistro: clearResponsavelTecnicoRegistro
          ? null
          : (responsavelTecnicoRegistro ?? this.responsavelTecnicoRegistro),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Loteamento.fromJson(Map<String, dynamic> json) =>
      _$LoteamentoFromJson(compatibleDates(json, ['createdAt', 'updatedAt']));

  Map<String, dynamic> toJson() => _$LoteamentoToJson(this);
}

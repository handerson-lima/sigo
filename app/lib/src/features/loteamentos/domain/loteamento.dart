import 'package:json_annotation/json_annotation.dart';

import '../../../core/contracts.dart';

part 'loteamento.g.dart';

@JsonSerializable()
class Loteamento {
  final String id;
  final String construtoraId;
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

  Loteamento copyWith({
    String? id,
    String? construtoraId,
    String? name,
    String? bairro,
    String? cidade,
    String? uf,
    String? proprietarioNome,
    String? proprietarioDocumento,
    String? responsavelTecnicoNome,
    String? responsavelTecnicoRegistro,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Loteamento(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      name: name ?? this.name,
      bairro: bairro ?? this.bairro,
      cidade: cidade ?? this.cidade,
      uf: uf ?? this.uf,
      proprietarioNome: proprietarioNome ?? this.proprietarioNome,
      proprietarioDocumento:
          proprietarioDocumento ?? this.proprietarioDocumento,
      responsavelTecnicoNome:
          responsavelTecnicoNome ?? this.responsavelTecnicoNome,
      responsavelTecnicoRegistro:
          responsavelTecnicoRegistro ?? this.responsavelTecnicoRegistro,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Loteamento.fromJson(Map<String, dynamic> json) =>
      _$LoteamentoFromJson(compatibleDates(json, ['createdAt', 'updatedAt']));

  Map<String, dynamic> toJson() => _$LoteamentoToJson(this);
}

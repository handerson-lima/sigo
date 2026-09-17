// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movimentacao.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Movimentacao _$MovimentacaoFromJson(Map<String, dynamic> json) => Movimentacao(
  id: json['id'] as String,
  materialId: json['materialId'] as String,
  type: $enumDecode(_$MovimentacaoTypeEnumMap, json['type']),
  quantity: (json['quantity'] as num).toDouble(),
  date: DateTime.parse(json['date'] as String),
  responsavelId: json['responsavelId'] as String,
  obraId: json['obraId'] as String?,
  loteId: json['loteId'] as String?,
  observacao: json['observacao'] as String?,
  evidence: json['evidence'] as String?,
  nfNumber: json['nfNumber'] as String?,
  fornecedor: json['fornecedor'] as String?,
  apropriacaoLote: json['apropriacaoLote'] as bool?,
  solicitante: json['solicitante'] as String?,
);

Map<String, dynamic> _$MovimentacaoToJson(Movimentacao instance) =>
    <String, dynamic>{
      'id': instance.id,
      'materialId': instance.materialId,
      'type': _$MovimentacaoTypeEnumMap[instance.type]!,
      'quantity': instance.quantity,
      'date': instance.date.toIso8601String(),
      'responsavelId': instance.responsavelId,
      'obraId': instance.obraId,
      'loteId': instance.loteId,
      'observacao': instance.observacao,
      'evidence': instance.evidence,
      'nfNumber': instance.nfNumber,
      'fornecedor': instance.fornecedor,
      'apropriacaoLote': instance.apropriacaoLote,
      'solicitante': instance.solicitante,
    };

const _$MovimentacaoTypeEnumMap = {
  MovimentacaoType.entrada: 'entrada',
  MovimentacaoType.saida: 'saida',
};

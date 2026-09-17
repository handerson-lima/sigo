// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movimentacao.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Movimentacao _$MovimentacaoFromJson(Map<String, dynamic> json) => Movimentacao(
  id: json['id'] as String,
  materialId: json['materialId'] as String,
  type: $enumDecode(_$MovimentacaoTypeEnumMap, json['type']),
  quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
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
  valorItensCentavos: (json['valorItensCentavos'] as num?)?.toInt(),
  freteCentavos: (json['freteCentavos'] as num?)?.toInt(),
  despesasCentavos: (json['despesasCentavos'] as num?)?.toInt(),
  descontoCentavos: (json['descontoCentavos'] as num?)?.toInt(),
  custoTotalCentavos: (json['custoTotalCentavos'] as num?)?.toInt(),
  custoUnitarioCentavos: (json['custoUnitarioCentavos'] as num?)?.toInt(),
  quantityUnits: (json['quantityUnits'] as num?)?.toInt(),
  quantityScale: (json['quantityScale'] as num?)?.toInt(),
  deltaUnits: (json['deltaUnits'] as num?)?.toInt(),
  commandType: json['commandType'] as String?,
  reversalId: json['reversalId'] as String?,
  reversedBy: json['reversedBy'] as String?,
  openingBalanceUnits: (json['openingBalanceUnits'] as num?)?.toInt(),
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
      'valorItensCentavos': instance.valorItensCentavos,
      'freteCentavos': instance.freteCentavos,
      'despesasCentavos': instance.despesasCentavos,
      'descontoCentavos': instance.descontoCentavos,
      'custoTotalCentavos': instance.custoTotalCentavos,
      'custoUnitarioCentavos': instance.custoUnitarioCentavos,
      'quantityUnits': instance.quantityUnits,
      'quantityScale': instance.quantityScale,
      'deltaUnits': instance.deltaUnits,
      'commandType': instance.commandType,
      'reversalId': instance.reversalId,
      'reversedBy': instance.reversedBy,
      'openingBalanceUnits': instance.openingBalanceUnits,
    };

const _$MovimentacaoTypeEnumMap = {
  MovimentacaoType.entrada: 'entrada',
  MovimentacaoType.saida: 'saida',
};

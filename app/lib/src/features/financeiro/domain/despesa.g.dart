// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'despesa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Despesa _$DespesaFromJson(Map<String, dynamic> json) => Despesa(
  id: json['id'] as String,
  construtoraId: json['construtoraId'] as String,
  obraId: json['obraId'] as String?,
  descricao: json['descricao'] as String,
  valor: (json['valor'] as num).toDouble(),
  valorEmCentavos: json['valorEmCentavos'] as int?,
  dataVencimento: DateTime.parse(json['dataVencimento'] as String),
  dataPagamento: json['dataPagamento'] == null
      ? null
      : DateTime.parse(json['dataPagamento'] as String),
  status: $enumDecode(_$StatusDespesaEnumMap, json['status']),
  categoria: json['categoria'] as String,
  responsavelId: json['responsavelId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$DespesaToJson(Despesa instance) => <String, dynamic>{
  'id': instance.id,
  'construtoraId': instance.construtoraId,
  'obraId': instance.obraId,
  'descricao': instance.descricao,
  'valor': instance.valor,
  'dataVencimento': instance.dataVencimento.toIso8601String(),
  'dataPagamento': instance.dataPagamento?.toIso8601String(),
  'status': _$StatusDespesaEnumMap[instance.status]!,
  'categoria': instance.categoria,
  'responsavelId': instance.responsavelId,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$StatusDespesaEnumMap = {
  StatusDespesa.pendente: 'pendente',
  StatusDespesa.pago: 'pago',
  StatusDespesa.atrasado: 'atrasado',
};

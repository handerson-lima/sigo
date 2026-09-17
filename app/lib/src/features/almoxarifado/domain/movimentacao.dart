import '../../../core/contracts.dart';

import 'package:json_annotation/json_annotation.dart';

part 'movimentacao.g.dart';

enum MovimentacaoType { entrada, saida }

@JsonSerializable()
class Movimentacao {
  final String id;
  final String materialId;
  final MovimentacaoType type;
  final double quantity;
  final DateTime date;
  final String responsavelId;
  final String? obraId; // Para qual obra foi encaminhado (nas saídas)
  final String? loteId; // Para qual lote foi encaminhado (opcional)
  final String? observacao;
  final String? evidence; // Caminho/URL da foto ou anexo da NF
  final String? nfNumber; // Número da Nota Fiscal
  final String? fornecedor; // Razão social ou nome do fornecedor
  final bool? apropriacaoLote; // Se a saída foi apropriada diretamente a um lote
  final String? solicitante; // Nome ou identificação de quem solicitou/retirou o material
  final int? valorItensCentavos; // Valor bruto dos itens em centavos
  final int? freteCentavos; // Valor do frete acessório em centavos
  final int? despesasCentavos; // Outras despesas acessórias em centavos
  final int? descontoCentavos; // Desconto concedido em centavos
  final int? custoTotalCentavos; // Custo total efetivo (itens + frete + despesas - desconto) em centavos
  final int? custoUnitarioCentavos; // Custo unitário efetivo apurado em centavos por unidade

  Movimentacao({
    required this.id,
    required this.materialId,
    required this.type,
    required this.quantity,
    required this.date,
    required this.responsavelId,
    this.obraId,
    this.loteId,
    this.observacao,
    this.evidence,
    this.nfNumber,
    this.fornecedor,
    this.apropriacaoLote,
    this.solicitante,
    this.valorItensCentavos,
    this.freteCentavos,
    this.despesasCentavos,
    this.descontoCentavos,
    this.custoTotalCentavos,
    this.custoUnitarioCentavos,
  });

  factory Movimentacao.fromJson(Map<String, dynamic> json) =>
      _$MovimentacaoFromJson(compatibleDates(json, ['date']));

  Map<String, dynamic> toJson() => _$MovimentacaoToJson(this);
}

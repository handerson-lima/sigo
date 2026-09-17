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
  final int? quantityUnits; // Quantidade inteira escalada
  final int? quantityScale; // Fator de escala (padrão 1000)
  final int? deltaUnits; // Variação com sinal (+ entrada, - saída)
  final String? commandType; // 'entrada', 'saida', 'ajuste', 'estorno', 'abertura'
  final String? reversalId; // ID da movimentação original estornada
  final String? reversedBy; // ID do estorno que reverteu este movimento
  final int? openingBalanceUnits; // Saldo de abertura para reconciliação legada

  Movimentacao({
    required this.id,
    required this.materialId,
    required this.type,
    this.quantity = 0.0,
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
    this.quantityUnits,
    this.quantityScale,
    this.deltaUnits,
    this.commandType,
    this.reversalId,
    this.reversedBy,
    this.openingBalanceUnits,
  });

  int get effectiveQuantityScale => quantityScale ?? 1000;

  double get effectiveQuantity {
    if (quantityUnits != null) {
      return quantityUnits! / effectiveQuantityScale;
    }
    return quantity;
  }

  String get displayQuantity => formatQuantityWithScale(
        effectiveQuantity,
        scale: effectiveQuantityScale,
        useComma: false,
      );

  String get displayQuantityBr => formatQuantityWithScale(
        effectiveQuantity,
        scale: effectiveQuantityScale,
        useComma: true,
      );

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (copy['quantity'] == null && copy['quantityUnits'] != null) {
      final scale = (copy['quantityScale'] as num?)?.toDouble() ?? 1000.0;
      copy['quantity'] = (copy['quantityUnits'] as num).toDouble() / scale;
    }
    return _$MovimentacaoFromJson(compatibleDates(copy, ['date']));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ..._$MovimentacaoToJson(this),
        'quantity': effectiveQuantity,
        if (quantityUnits != null) 'quantityUnits': quantityUnits,
        if (quantityScale != null) 'quantityScale': quantityScale,
        if (deltaUnits != null) 'deltaUnits': deltaUnits,
        if (commandType != null) 'commandType': commandType,
        if (reversalId != null) 'reversalId': reversalId,
        if (reversedBy != null) 'reversedBy': reversedBy,
        if (openingBalanceUnits != null)
          'openingBalanceUnits': openingBalanceUnits,
      };
}

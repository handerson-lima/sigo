import 'package:json_annotation/json_annotation.dart';

part 'lote.g.dart';

enum LoteStatus {
  noPrazo,
  atrasado,
  paralisado,
  concluido,
}

@JsonSerializable()
class Lote {
  final String id;
  final String construtoraId;
  final String obraId;
  final String name;
  final String phase; // String para facilitar futura customização por construtora
  final LoteStatus status;
  final String? responsavelId;
  final DateTime createdAt;

  Lote({
    required this.id,
    required this.construtoraId,
    required this.obraId,
    required this.name,
    required this.phase,
    this.status = LoteStatus.noPrazo,
    this.responsavelId,
    required this.createdAt,
  });

  factory Lote.fromJson(Map<String, dynamic> json) => _$LoteFromJson(json);

  Map<String, dynamic> toJson() => _$LoteToJson(this);
}

// Constante temporária para ser usada no Dropdown, facilitando a migração
// para o Firestore (configurações da construtora) no futuro.
const List<String> defaultLotePhases = [
  'Plantas',
  'Fundação',
  'Estrutura',
  'Alvenaria',
  'Acabamento',
  'Entregue'
];

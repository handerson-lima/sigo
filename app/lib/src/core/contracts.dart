import 'package:cloud_firestore/cloud_firestore.dart';

String normalizeModule(String value) => switch (value) {
  'rdo' => 'diario',
  'almoxarifado' => 'estoque',
  _ => value,
};

List<String> normalizeRawModules(dynamic modules, [dynamic fallback]) {
  final raw = (modules is List && modules.isNotEmpty) ? modules : fallback;
  final list = raw is List ? raw : <dynamic>[];
  return list.whereType<String>().map(normalizeModule).toList();
}
DateTime readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw const FormatException('Data inválida');
}

String civilDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
Map<String, dynamic> compatibleDates(
  Map<String, dynamic> json,
  List<String> fields,
) {
  final result = Map<String, dynamic>.from(json);
  for (final field in fields) {
    if (result[field] != null) {
      result[field] = readDate(result[field]).toIso8601String();
    }
  }
  return result;
}

int decimalUnits(dynamic value, int digits, {bool round = false}) {
  final text = value.toString();
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(text)) {
    throw const FormatException('Valor inválido');
  }
  final negative = text.startsWith('-');
  final parts = text.replaceFirst('-', '').split('.');
  final fraction = parts.length == 2 ? parts[1] : '';
  final padded = fraction.padRight(digits + 1, '0');
  if (!round &&
      RegExp(
        '[1-9]',
      ).hasMatch(fraction.length > digits ? fraction.substring(digits) : '')) {
    throw const FormatException('Precisão excedida');
  }
  var result = int.parse(parts[0] + padded.substring(0, digits));
  if (round && int.parse(padded[digits]) >= 5) result++;
  if (result > 9007199254740991) {
    throw const FormatException('Valor fora do limite');
  }
  return negative ? -result : result;
}

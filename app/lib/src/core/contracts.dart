import 'package:cloud_firestore/cloud_firestore.dart';

String normalizeModule(String value) => switch (value) {
  'rdo' => 'diario',
  'almoxarifado' => 'estoque',
  'recursos_humanos' => 'rh',
  'qualidade' => 'validacao',
  'financeiro' => 'adm',
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

int _digitsForScale(int scale) {
  int d = 0;
  int temp = scale;
  while (temp >= 10 && temp % 10 == 0) {
    d++;
    temp ~/= 10;
  }
  return d > 0 ? d : 3;
}

int parseCurrencyToCents(dynamic value) {
  if (value == null) throw const FormatException('Valor monetário inválido');
  String text;
  if (value is num) {
    if (!value.isFinite) throw const FormatException('Valor monetário inválido');
    text = value.toString();
  } else {
    text = value.toString().trim();
  }
  if (text.isEmpty) throw const FormatException('Valor monetário inválido');
  var clean = text.replaceAll('R\$', '').replaceAll(' ', '').trim();
  final negative = clean.startsWith('-');
  if (negative) clean = clean.substring(1).trim();
  if (clean.contains(',') && clean.contains('.')) {
    clean = clean.replaceAll('.', '').replaceAll(',', '.');
  } else if (clean.contains(',')) {
    clean = clean.replaceAll(',', '.');
  }
  final cents = decimalUnits(clean, 2, round: true);
  return negative ? -cents.abs() : cents.abs();
}

String formatCents(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final reais = abs ~/ 100;
  final centavos = (abs % 100).toString().padLeft(2, '0');
  final formattedReais = reais.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
  return '${negative ? '-' : ''}R\$ $formattedReais,$centavos';
}

int parseQuantityUnits(
  dynamic value, {
  int scale = 1000,
  bool allowNegative = false,
}) {
  if (value == null) throw const FormatException('Valor inválido');
  String text;
  if (value is num) {
    if (!value.isFinite) throw const FormatException('Valor inválido');
    text = value.toString();
  } else {
    text = value.toString().trim();
  }
  if (text.isEmpty) throw const FormatException('Valor inválido');

  final hasPlus = text.startsWith('+');
  if (hasPlus) text = text.substring(1).trim();
  final negative = text.startsWith('-');
  if (negative) {
    if (!allowNegative) throw const FormatException('Valor inválido');
    text = text.substring(1).trim();
  }

  if (text.contains(',') && text.contains('.')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (text.contains(',')) {
    text = text.replaceAll(',', '.');
  }

  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) {
    throw const FormatException('Valor inválido');
  }

  final digits = _digitsForScale(scale);
  final parts = text.split('.');
  if (parts.length == 2 && parts[1].length > digits) {
    throw FormatException('Use até $digits casas decimais');
  }

  final units = decimalUnits(text, digits, round: false);
  return negative ? -units : units;
}

String formatQuantityWithScale(
  num quantity, {
  int scale = 1000,
  bool useComma = true,
}) {
  final double val = quantity.toDouble();
  if (val % 1 == 0) {
    return val.toInt().toString();
  }
  final digits = _digitsForScale(scale);
  var str = val.toStringAsFixed(digits);
  while (str.contains('.') && (str.endsWith('0') || str.endsWith('.'))) {
    str = str.substring(0, str.length - 1);
  }
  if (useComma) {
    str = str.replaceAll('.', ',');
  }
  return str;
}

String formatQuantityUnits(
  int quantityUnits, {
  int scale = 1000,
  bool useComma = true,
}) => formatQuantityWithScale(
  quantityUnits / scale,
  scale: scale,
  useComma: useComma,
);

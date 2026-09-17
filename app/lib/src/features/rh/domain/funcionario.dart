import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/contracts.dart';

class Funcionario {
  final String id;
  final String construtoraId;
  final String name;
  final String cpf;
  final String role;
  final String? teamId;
  final String employmentType; // 'clt', 'pj', 'avulso'
  final String salaryBasis; // 'mensal', 'diaria'
  final int baseSalaryCents;
  final int additionalCostsCents;
  final int totalDailyRateCents;
  final bool isActive;
  final int schemaVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Funcionario({
    required this.id,
    required this.construtoraId,
    required this.name,
    required this.cpf,
    required this.role,
    this.teamId,
    required this.employmentType,
    required this.salaryBasis,
    required this.baseSalaryCents,
    this.additionalCostsCents = 0,
    int? totalDailyRateCents,
    this.isActive = true,
    this.schemaVersion = 1,
    this.createdAt,
    this.updatedAt,
  }) : totalDailyRateCents = totalDailyRateCents ??
            calculateDailyRate(
              salaryBasis: salaryBasis,
              baseSalaryCents: baseSalaryCents,
              additionalCostsCents: additionalCostsCents,
            );

  static int calculateDailyRate({
    required String salaryBasis,
    required int baseSalaryCents,
    required int additionalCostsCents,
    int monthlyDivisor = 30,
  }) {
    final totalCents = baseSalaryCents + additionalCostsCents;
    if (salaryBasis.toLowerCase() == 'diaria') {
      return totalCents;
    }
    final divisor = monthlyDivisor > 0 ? monthlyDivisor : 30;
    return totalCents ~/ divisor;
  }

  static bool isValidCpf(String? cpf) {
    if (cpf == null) return false;
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(clean)) return false;

    int calcDigit(int length) {
      int sum = 0;
      for (int i = 0; i < length; i++) {
        sum += int.parse(clean[i]) * (length + 1 - i);
      }
      final remainder = (sum * 10) % 11;
      return remainder == 10 ? 0 : remainder;
    }

    if (calcDigit(9) != int.parse(clean[9])) return false;
    if (calcDigit(10) != int.parse(clean[10])) return false;
    return true;
  }

  static String formatCpf(String cpf) {
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 11) return cpf;
    return '${clean.substring(0, 3)}.${clean.substring(3, 6)}.${clean.substring(6, 9)}-${clean.substring(9, 11)}';
  }

  String get cleanCpf => cpf.replaceAll(RegExp(r'\D'), '');
  String get formattedCpf => formatCpf(cpf);
  String get formattedBaseSalary => formatCents(baseSalaryCents);
  String get formattedAdditionalCosts => formatCents(additionalCostsCents);
  String get formattedDailyRate => formatCents(totalDailyRateCents);

  String get employmentTypeLabel {
    switch (employmentType.toLowerCase()) {
      case 'clt':
        return 'CLT';
      case 'pj':
        return 'PJ';
      case 'avulso':
        return 'Diarista / Avulso';
      default:
        return employmentType.toUpperCase();
    }
  }

  String get salaryBasisLabel =>
      salaryBasis.toLowerCase() == 'diaria' ? 'Diária' : 'Mensal';

  Funcionario copyWith({
    String? id,
    String? construtoraId,
    String? name,
    String? cpf,
    String? role,
    String? teamId,
    bool clearTeamId = false,
    String? employmentType,
    String? salaryBasis,
    int? baseSalaryCents,
    int? additionalCostsCents,
    int? totalDailyRateCents,
    bool? isActive,
    int? schemaVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final nextBase = baseSalaryCents ?? this.baseSalaryCents;
    final nextAdd = additionalCostsCents ?? this.additionalCostsCents;
    final nextBasis = salaryBasis ?? this.salaryBasis;

    return Funcionario(
      id: id ?? this.id,
      construtoraId: construtoraId ?? this.construtoraId,
      name: name ?? this.name,
      cpf: cpf ?? this.cpf,
      role: role ?? this.role,
      teamId: clearTeamId ? null : (teamId ?? this.teamId),
      employmentType: employmentType ?? this.employmentType,
      salaryBasis: nextBasis,
      baseSalaryCents: nextBase,
      additionalCostsCents: nextAdd,
      totalDailyRateCents: totalDailyRateCents ??
          calculateDailyRate(
            salaryBasis: nextBasis,
            baseSalaryCents: nextBase,
            additionalCostsCents: nextAdd,
          ),
      isActive: isActive ?? this.isActive,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Funcionario.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    final base = (json['baseSalaryCents'] as num?)?.toInt() ??
        ((json['baseSalary'] as num?) != null
            ? ((json['baseSalary'] as num) * 100).round()
            : 0);

    final additional = (json['additionalCostsCents'] as num?)?.toInt() ??
        ((json['additionalCosts'] as num?) != null
            ? ((json['additionalCosts'] as num) * 100).round()
            : 0);

    final basis = (json['salaryBasis'] as String?) ?? 'mensal';

    final daily = (json['totalDailyRateCents'] as num?)?.toInt() ??
        ((json['totalDailyRate'] as num?) != null
            ? ((json['totalDailyRate'] as num) * 100).round()
            : calculateDailyRate(
                salaryBasis: basis,
                baseSalaryCents: base,
                additionalCostsCents: additional,
              ));

    return Funcionario(
      id: json['id'] as String? ?? '',
      construtoraId: json['construtoraId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cpf: json['cpf'] as String? ?? '',
      role: json['role'] as String? ?? '',
      teamId: json['teamId'] as String?,
      employmentType: json['employmentType'] as String? ?? 'clt',
      salaryBasis: basis,
      baseSalaryCents: base,
      additionalCostsCents: additional,
      totalDailyRateCents: daily,
      isActive: json['isActive'] as bool? ?? true,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'construtoraId': construtoraId,
      'name': name,
      'cpf': cpf,
      'role': role,
      'teamId': teamId,
      'employmentType': employmentType,
      'salaryBasis': salaryBasis,
      'baseSalaryCents': baseSalaryCents,
      'additionalCostsCents': additionalCostsCents,
      'totalDailyRateCents': totalDailyRateCents,
      'isActive': isActive,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

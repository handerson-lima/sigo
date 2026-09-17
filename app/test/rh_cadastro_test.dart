import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/src/features/rh/domain/funcionario.dart';
import 'package:app/src/features/rh/domain/equipe.dart';
import 'package:app/src/features/rh/data/rh_repository.dart';
import 'package:app/src/features/rh/presentation/funcionarios_list_screen.dart';
import 'package:app/src/features/rh/presentation/funcionario_form_screen.dart';
import 'package:app/src/features/rh/presentation/equipes_dialog.dart';
import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';

class FakeRhRepository implements RhRepository {
  final List<Funcionario> funcionarios = [];
  final List<Equipe> equipes = [];

  final _funcStreamCtrl = StreamController<List<Funcionario>>.broadcast();
  final _eqStreamCtrl = StreamController<List<Equipe>>.broadcast();

  void _notifyFuncionarios() {
    _funcStreamCtrl.add(List.unmodifiable(funcionarios));
  }

  void _notifyEquipes() {
    _eqStreamCtrl.add(List.unmodifiable(equipes));
  }

  @override
  Stream<List<Funcionario>> watchFuncionarios(String construtoraId) async* {
    yield funcionarios.where((f) => f.construtoraId == construtoraId).toList();
    yield* _funcStreamCtrl.stream.map(
      (list) => list.where((f) => f.construtoraId == construtoraId).toList(),
    );
  }

  @override
  Future<List<Funcionario>> getFuncionarios(String construtoraId) async {
    return funcionarios.where((f) => f.construtoraId == construtoraId).toList();
  }

  @override
  Future<void> createFuncionario(Funcionario funcionario) async {
    funcionarios.add(funcionario);
    _notifyFuncionarios();
  }

  @override
  Future<void> updateFuncionario(Funcionario funcionario) async {
    final idx = funcionarios.indexWhere((f) => f.id == funcionario.id);
    if (idx != -1) {
      funcionarios[idx] = funcionario;
      _notifyFuncionarios();
    }
  }

  @override
  Future<void> setFuncionarioActive(
    String construtoraId,
    String funcionarioId,
    bool isActive,
  ) async {
    final idx = funcionarios.indexWhere((f) => f.id == funcionarioId);
    if (idx != -1) {
      funcionarios[idx] = funcionarios[idx].copyWith(isActive: isActive);
      _notifyFuncionarios();
    }
  }

  @override
  Stream<List<Equipe>> watchEquipes(String construtoraId) async* {
    yield equipes.where((e) => e.construtoraId == construtoraId).toList();
    yield* _eqStreamCtrl.stream.map(
      (list) => list.where((e) => e.construtoraId == construtoraId).toList(),
    );
  }

  @override
  Future<List<Equipe>> getEquipes(String construtoraId) async {
    return equipes.where((e) => e.construtoraId == construtoraId).toList();
  }

  @override
  Future<void> createEquipe(Equipe equipe) async {
    equipes.add(equipe);
    _notifyEquipes();
  }

  @override
  Future<void> updateEquipe(Equipe equipe) async {
    final idx = equipes.indexWhere((e) => e.id == equipe.id);
    if (idx != -1) {
      equipes[idx] = equipe;
      _notifyEquipes();
    }
  }

  @override
  Future<void> setEquipeActive(
    String construtoraId,
    String equipeId,
    bool isActive,
  ) async {
    final idx = equipes.indexWhere((e) => e.id == equipeId);
    if (idx != -1) {
      equipes[idx] = equipes[idx].copyWith(isActive: isActive);
      _notifyEquipes();
    }
  }
}

void main() {
  group('Story 4.1 — RH: Cadastro de Funcionários e Equipes', () {
    late FakeRhRepository fakeRepo;

    // CPFs válidos conhecidos para testes
    const validCpf1 = '52998224725';
    const validCpfFormatted = '529.982.247-25';

    setUp(() {
      fakeRepo = FakeRhRepository();
    });

    test('Validação de CPF com dígitos verificadores e casos de borda', () {
      // CPF válido (algoritmo padrão da Receita Federal)
      expect(Funcionario.isValidCpf(validCpf1), isTrue);
      expect(Funcionario.isValidCpf(validCpfFormatted), isTrue);

      // Dígitos todos repetidos (devem ser rejeitados)
      expect(Funcionario.isValidCpf('111.111.111-11'), isFalse);
      expect(Funcionario.isValidCpf('00000000000'), isFalse);
      expect(Funcionario.isValidCpf('99999999999'), isFalse);

      // Tamanho incorreto
      expect(Funcionario.isValidCpf('123.456.789'), isFalse);
      expect(Funcionario.isValidCpf('123456789012'), isFalse);
      expect(Funcionario.isValidCpf(''), isFalse);
      expect(Funcionario.isValidCpf(null), isFalse);

      // Dígitos verificadores incorretos
      expect(Funcionario.isValidCpf('52998224724'), isFalse);
      expect(Funcionario.isValidCpf('52998224735'), isFalse);
    });

    test('Matrix Row 1: Cálculo de taxa diária para CLT Mensal (divisor 30 com DSR)', () {
      // Salário R$ 3.000,00 (300.000 centavos) + Encargos R$ 600,00 (60.000 centavos)
      // Total = 360.000 centavos / 30 = 12.000 centavos = R$ 120,00/dia
      final dailyCents = Funcionario.calculateDailyRate(
        salaryBasis: 'mensal',
        baseSalaryCents: 300000,
        additionalCostsCents: 60000,
      );
      expect(dailyCents, equals(12000));

      final f = Funcionario(
        id: 'func-01',
        construtoraId: 'c1',
        name: 'João da Silva',
        cpf: validCpf1,
        role: 'Pedreiro',
        employmentType: 'clt',
        salaryBasis: 'mensal',
        baseSalaryCents: 300000,
        additionalCostsCents: 60000,
      );
      expect(f.totalDailyRateCents, equals(12000));
      expect(f.formattedBaseSalary, equals('R\$ 3.000,00'));
      expect(f.formattedAdditionalCosts, equals('R\$ 600,00'));
      expect(f.formattedDailyRate, equals('R\$ 120,00'));
      expect(f.employmentTypeLabel, equals('CLT'));
      expect(f.salaryBasisLabel, equals('Mensal'));
    });

    test('Matrix Row 2: Cálculo de taxa diária para Diarista Avulso', () {
      // Diária de R$ 150,00 (15.000 centavos) + 0 encargos => 15.000 centavos
      final dailyCents = Funcionario.calculateDailyRate(
        salaryBasis: 'diaria',
        baseSalaryCents: 15000,
        additionalCostsCents: 0,
      );
      expect(dailyCents, equals(15000));

      final f = Funcionario(
        id: 'func-02',
        construtoraId: 'c1',
        name: 'Carlos Pereira',
        cpf: validCpf1,
        role: 'Servente',
        employmentType: 'avulso',
        salaryBasis: 'diaria',
        baseSalaryCents: 15000,
        additionalCostsCents: 0,
      );
      expect(f.totalDailyRateCents, equals(15000));
      expect(f.formattedDailyRate, equals('R\$ 150,00'));
      expect(f.employmentTypeLabel, equals('Diarista / Avulso'));
      expect(f.salaryBasisLabel, equals('Diária'));
    });

    test('Serialização e compatibilidade de Funcionario e Equipe', () {
      final f = Funcionario(
        id: 'f-ser-1',
        construtoraId: 'c1',
        name: 'Manoel Pintor',
        cpf: validCpf1,
        role: 'Pintor',
        teamId: 'eq-1',
        employmentType: 'pj',
        salaryBasis: 'mensal',
        baseSalaryCents: 450000,
        additionalCostsCents: 50000,
        isActive: true,
        schemaVersion: 1,
        createdAt: DateTime(2026, 9, 17),
      );

      final json = f.toJson();
      expect(json['id'], equals('f-ser-1'));
      expect(json['baseSalaryCents'], equals(450000));
      expect(json['totalDailyRateCents'], equals(16666)); // (450000 + 50000) ~/ 30
      expect(json['teamId'], equals('eq-1'));

      final fromJson = Funcionario.fromJson(json);
      expect(fromJson.name, equals('Manoel Pintor'));
      expect(fromJson.baseSalaryCents, equals(450000));
      expect(fromJson.totalDailyRateCents, equals(16666));
      expect(fromJson.teamId, equals('eq-1'));

      // Teste de Equipe
      final eq = Equipe(
        id: 'eq-1',
        construtoraId: 'c1',
        name: 'Equipe Acabamento',
        leaderId: 'f-ser-1',
        leaderName: 'Manoel Pintor',
      );
      final eqJson = eq.toJson();
      expect(eqJson['name'], equals('Equipe Acabamento'));
      final eqFrom = Equipe.fromJson(eqJson);
      expect(eqFrom.name, equals('Equipe Acabamento'));
      expect(eqFrom.leaderName, equals('Manoel Pintor'));
    });

    testWidgets('Listagem de colaboradores renderiza cards, badges e filtros',
        (tester) async {
      fakeRepo.funcionarios.addAll([
        Funcionario(
          id: 'f1',
          construtoraId: 'c1',
          name: 'Alberto Santos',
          cpf: validCpf1,
          role: 'Encarregado',
          employmentType: 'clt',
          salaryBasis: 'mensal',
          baseSalaryCents: 500000,
          additionalCostsCents: 100000,
          isActive: true,
        ),
        Funcionario(
          id: 'f2',
          construtoraId: 'c1',
          name: 'Bruno Lima',
          cpf: validCpf1,
          role: 'Ajudante',
          employmentType: 'avulso',
          salaryBasis: 'diaria',
          baseSalaryCents: 16000,
          additionalCostsCents: 0,
          isActive: false, // Inativo
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rhRepositoryProvider.overrideWithValue(fakeRepo),
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: FuncionariosListScreen(construtoraId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Por padrão, o filtro é 'Ativos'
      expect(find.text('Alberto Santos'), findsOneWidget);
      expect(find.text('Bruno Lima'), findsNothing); // Inativo filtrado
      expect(find.widgetWithText(ChoiceChip, 'CLT'), findsOneWidget);
      expect(find.text('Ativo'), findsOneWidget);

      // Alternar filtro para 'Todos'
      await tester.tap(find.text('Todos').first);
      await tester.pumpAndSettle();
      expect(find.text('Alberto Santos'), findsOneWidget);
      expect(find.text('Bruno Lima'), findsOneWidget);

      // Alternar filtro para 'Inativos'
      await tester.tap(find.text('Inativos'));
      await tester.pumpAndSettle();
      expect(find.text('Alberto Santos'), findsNothing);
      expect(find.text('Bruno Lima'), findsOneWidget);

      // Busca textual
      await tester.tap(find.text('Todos').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('search_funcionarios_input')),
        'Alberto',
      );
      await tester.pumpAndSettle();
      expect(find.text('Alberto Santos'), findsOneWidget);
      expect(find.text('Bruno Lima'), findsNothing);
    });

    testWidgets('Formulário de Funcionário valida campos e calcula preview em tempo real',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rhRepositoryProvider.overrideWithValue(fakeRepo),
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: FuncionarioFormScreen(construtoraId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final saveBtn = find.byKey(const Key('btn_save_funcionario'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Nome é obrigatório'), findsOneWidget);
      expect(find.text('CPF é obrigatório'), findsOneWidget);
      expect(find.text('Cargo é obrigatório'), findsOneWidget);

      // Preencher nome com espaços vazios
      await tester.enterText(
        find.byKey(const Key('funcionario_name_input')),
        '   ',
      );
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(find.text('Nome é obrigatório'), findsOneWidget);

      // Preencher nome válido e cargo válido
      await tester.enterText(
        find.byKey(const Key('funcionario_name_input')),
        'Marcos Vinicius',
      );
      await tester.enterText(
        find.byKey(const Key('funcionario_role_input')),
        'Eletricista',
      );

      // Preencher CPF inválido
      await tester.enterText(
        find.byKey(const Key('funcionario_cpf_input')),
        '111.111.111-11',
      );
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(find.text('CPF inválido'), findsOneWidget);

      // Corrigir para CPF válido
      await tester.enterText(
        find.byKey(const Key('funcionario_cpf_input')),
        validCpfFormatted,
      );
      await tester.pumpAndSettle();

      // Preencher Salário Base de R$ 3.000,00 e adicionais R$ 600,00
      await tester.enterText(
        find.byKey(const Key('funcionario_salary_input')),
        '3000.00',
      );
      await tester.enterText(
        find.byKey(const Key('funcionario_additional_input')),
        '600.00',
      );
      await tester.pumpAndSettle();

      // Preview dinâmico deve calcular (3000 + 600) / 30 = R$ 120,00 / dia
      expect(find.text('R\$ 120,00 / dia'), findsOneWidget);

      // Salvar funcionário
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verificar persistência no fakeRepo
      expect(fakeRepo.funcionarios.length, equals(1));
      final saved = fakeRepo.funcionarios.first;
      expect(saved.name, equals('Marcos Vinicius'));
      expect(saved.cleanCpf, equals(validCpf1));
      expect(saved.role, equals('Eletricista'));
      expect(saved.baseSalaryCents, equals(300000));
      expect(saved.additionalCostsCents, equals(60000));
      expect(saved.totalDailyRateCents, equals(12000));
      expect(saved.isActive, isTrue);
    });

    testWidgets('Inativação lógica (soft delete) altera isActive para false',
        (tester) async {
      fakeRepo.funcionarios.add(
        Funcionario(
          id: 'f-ativo-1',
          construtoraId: 'c1',
          name: 'Renato Soldador',
          cpf: validCpf1,
          role: 'Soldador',
          employmentType: 'pj',
          salaryBasis: 'mensal',
          baseSalaryCents: 400000,
          isActive: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rhRepositoryProvider.overrideWithValue(fakeRepo),
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: FuncionariosListScreen(construtoraId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Abrir menu do card
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Clicar em Inativar
      await tester.tap(find.text('Inativar'));
      await tester.pumpAndSettle();

      // Confirmar no diálogo de confirmação
      expect(find.text('Inativar Colaborador'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      // Verificar que virou inativo no repositório
      expect(fakeRepo.funcionarios.first.isActive, isFalse);
    });

    testWidgets('EquipesDialog permite criar e inativar equipes',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rhRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EquipesDialog(construtoraId: 'c1'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nenhuma equipe cadastrada ainda.'), findsOneWidget);

      // Adicionar nova equipe
      await tester.enterText(
        find.byKey(const Key('equipe_name_input')),
        'Equipe Estruturas 01',
      );
      await tester.tap(find.byKey(const Key('btn_add_equipe')));
      await tester.pumpAndSettle();

      expect(fakeRepo.equipes.length, equals(1));
      expect(fakeRepo.equipes.first.name, equals('Equipe Estruturas 01'));
      expect(fakeRepo.equipes.first.isActive, isTrue);
      expect(find.text('Equipe Estruturas 01'), findsOneWidget);
    });
  });
}

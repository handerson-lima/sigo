import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:app/src/common_widgets/sigo_sidebar.dart';
import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/rh/data/rh_repository.dart';
import 'package:app/src/features/rh/domain/equipe.dart';
import 'package:app/src/features/rh/domain/funcionario.dart';
import 'package:app/src/features/rh/presentation/equipe_form_dialog.dart';
import 'package:app/src/features/rh/presentation/funcionario_form_screen.dart';
import 'package:app/src/features/rh/presentation/funcionarios_list_screen.dart';
import 'package:app/src/features/rh/routing/rh_routes.dart';

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
  const validCpf = '52998224725';
  late FakeRhRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeRhRepository();
  });

  group('EquipeFormDialog & showEquipeFormDialog', () {
    testWidgets(
      'cria equipe com líder, valida nome vazio e bloqueia duplicidade case-insensitive',
      (tester) async {
        fakeRepo.equipes.add(
          Equipe(
            id: 'eq-existente',
            construtoraId: 'c1',
            name: 'Equipe Alvenaria',
          ),
        );
        fakeRepo.funcionarios.addAll([
          Funcionario(
            id: 'f-lider',
            construtoraId: 'c1',
            name: 'Carlos Encarregado',
            cpf: validCpf,
            role: 'Encarregado',
            employmentType: 'clt',
            salaryBasis: 'mensal',
            baseSalaryCents: 400000,
            isActive: true,
          ),
          Funcionario(
            id: 'f-inativo',
            construtoraId: 'c1',
            name: 'Pedro Inativo',
            cpf: validCpf,
            role: 'Pedreiro',
            employmentType: 'clt',
            salaryBasis: 'mensal',
            baseSalaryCents: 300000,
            isActive: false,
          ),
        ]);

        Equipe? dialogResult;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [rhRepositoryProvider.overrideWithValue(fakeRepo)],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      dialogResult = await showEquipeFormDialog(
                        context,
                        construtoraId: 'c1',
                      );
                    },
                    child: const Text('Abrir Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Dialog'));
        await tester.pumpAndSettle();

        // Tentar salvar com nome vazio
        await tester.tap(find.byKey(const Key('btn_save_equipe_form')));
        await tester.pumpAndSettle();
        expect(find.text('Nome da equipe é obrigatório'), findsOneWidget);

        // Tentar salvar com nome duplicado (case-insensitive + espaços)
        await tester.enterText(
          find.byKey(const Key('equipe_form_name_input')),
          '  equipe ALVENARIA  ',
        );
        await tester.tap(find.byKey(const Key('btn_save_equipe_form')));
        await tester.pumpAndSettle();
        expect(
          find.text('Já existe uma equipe com este nome'),
          findsOneWidget,
        );

        // Preencher nome válido
        await tester.enterText(
          find.byKey(const Key('equipe_form_name_input')),
          '  Equipe Elétrica 01  ',
        );

        // Selecionar líder ativo (inativo não deve aparecer)
        await tester.tap(find.byKey(const Key('equipe_form_leader_select')));
        await tester.pumpAndSettle();
        expect(find.text('Pedro Inativo — Pedreiro'), findsNothing);
        await tester.tap(find.text('Carlos Encarregado — Encarregado').last);
        await tester.pumpAndSettle();

        // Salvar
        await tester.tap(find.byKey(const Key('btn_save_equipe_form')));
        await tester.pumpAndSettle();

        expect(dialogResult, isNotNull);
        expect(dialogResult!.name, equals('Equipe Elétrica 01'));
        expect(dialogResult!.leaderId, equals('f-lider'));
        expect(dialogResult!.leaderName, equals('Carlos Encarregado'));
        expect(fakeRepo.equipes.length, equals(2));
      },
    );

    testWidgets(
      'modo edição ignora próprio nome na duplicidade e limpa líder com clearLeader',
      (tester) async {
        final existing = Equipe(
          id: 'eq-1',
          construtoraId: 'c1',
          name: 'Equipe Hidráulica',
          leaderId: 'f-1',
          leaderName: 'João Líder',
        );
        fakeRepo.equipes.addAll([
          existing,
          Equipe(
            id: 'eq-2',
            construtoraId: 'c1',
            name: 'Equipe Pintura',
          ),
        ]);
        fakeRepo.funcionarios.add(
          Funcionario(
            id: 'f-1',
            construtoraId: 'c1',
            name: 'João Líder',
            cpf: validCpf,
            role: 'Encarregado',
            employmentType: 'clt',
            salaryBasis: 'mensal',
            baseSalaryCents: 400000,
            isActive: true,
          ),
        );

        Equipe? updatedResult;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [rhRepositoryProvider.overrideWithValue(fakeRepo)],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      updatedResult = await showEquipeFormDialog(
                        context,
                        construtoraId: 'c1',
                        equipe: existing,
                      );
                    },
                    child: const Text('Editar'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();

        // Bloquear colisão com outra equipe
        await tester.enterText(
          find.byKey(const Key('equipe_form_name_input')),
          'equipe pintura',
        );
        await tester.tap(find.byKey(const Key('btn_save_equipe_form')));
        await tester.pumpAndSettle();
        expect(
          find.text('Já existe uma equipe com este nome'),
          findsOneWidget,
        );

        // Voltar para o próprio nome (deve ser permitido) e limpar líder
        await tester.enterText(
          find.byKey(const Key('equipe_form_name_input')),
          'Equipe Hidráulica',
        );
        await tester.tap(find.byKey(const Key('equipe_form_leader_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sem líder definido').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_save_equipe_form')));
        await tester.pumpAndSettle();

        expect(updatedResult, isNotNull);
        expect(updatedResult!.id, equals('eq-1'));
        expect(updatedResult!.name, equals('Equipe Hidráulica'));
        expect(updatedResult!.leaderId, isNull);
        expect(updatedResult!.leaderName, isNull);
        expect(fakeRepo.equipes.first.leaderId, isNull);
        expect(fakeRepo.equipes.first.leaderName, isNull);
      },
    );
  });

  group('FuncionariosListScreen — Abas Funcionários | Equipes', () {
    testWidgets(
      'alterna abas, exibe FAB contextual e empty state acionável na aba Equipes',
      (tester) async {
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

        // Aba inicial: Funcionários
        expect(find.byKey(const Key('tab_rh_funcionarios')), findsOneWidget);
        expect(find.byKey(const Key('tab_rh_equipes')), findsOneWidget);
        expect(find.byKey(const Key('btn_add_funcionario_fab')), findsOneWidget);
        expect(find.byKey(const Key('btn_add_equipe_fab')), findsNothing);

        // Trocar para aba Equipes
        await tester.tap(find.byKey(const Key('tab_rh_equipes')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_add_equipe_fab')), findsOneWidget);
        expect(find.byKey(const Key('btn_add_funcionario_fab')), findsNothing);
        expect(find.byKey(const Key('btn_empty_create_equipe')), findsOneWidget);

        // Criar primeira equipe pelo botão do empty state
        await tester.tap(find.byKey(const Key('btn_empty_create_equipe')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('equipe_form_name_input')),
          'Equipe Fundação',
        );
        await tester.tap(find.byKey(const Key('btn_save_equipe_form')));
        await tester.pumpAndSettle();

        expect(fakeRepo.equipes.length, equals(1));
        expect(find.text('Equipe Fundação'), findsOneWidget);
      },
    );

    testWidgets(
      'aba Equipes exibe contagem de membros ativos, busca, filtros e alerta ao inativar com membros',
      (tester) async {
        fakeRepo.equipes.addAll([
          Equipe(
            id: 'eq-1',
            construtoraId: 'c1',
            name: 'Equipe Alvenaria',
            leaderId: 'f1',
            leaderName: 'Alberto Líder',
            isActive: true,
          ),
          Equipe(
            id: 'eq-2',
            construtoraId: 'c1',
            name: 'Equipe Vazia',
            isActive: true,
          ),
          Equipe(
            id: 'eq-3',
            construtoraId: 'c1',
            name: 'Equipe Antiga',
            isActive: false,
          ),
        ]);
        fakeRepo.funcionarios.addAll([
          Funcionario(
            id: 'f1',
            construtoraId: 'c1',
            name: 'Alberto Líder',
            cpf: validCpf,
            role: 'Encarregado',
            teamId: 'eq-1',
            employmentType: 'clt',
            salaryBasis: 'mensal',
            baseSalaryCents: 400000,
            isActive: true,
          ),
          Funcionario(
            id: 'f2',
            construtoraId: 'c1',
            name: 'Bruno Pedreiro',
            cpf: validCpf,
            role: 'Pedreiro',
            teamId: 'eq-1',
            employmentType: 'clt',
            salaryBasis: 'mensal',
            baseSalaryCents: 300000,
            isActive: true,
          ),
          Funcionario(
            id: 'f3',
            construtoraId: 'c1',
            name: 'Carlos Inativo',
            cpf: validCpf,
            role: 'Servente',
            teamId: 'eq-1',
            employmentType: 'clt',
            salaryBasis: 'mensal',
            baseSalaryCents: 200000,
            isActive: false, // não entra na contagem de ativos
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
              home: FuncionariosListScreen(
                construtoraId: 'c1',
                initialTabIndex: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Contagem de membros ativos: 2 para eq-1, 0 para eq-2
        expect(find.text('Equipe Alvenaria'), findsOneWidget);
        expect(find.text('Líder: Alberto Líder'), findsOneWidget);
        expect(find.text('2 colaboradores ativos'), findsOneWidget);
        expect(find.text('Equipe Vazia'), findsOneWidget);
        expect(find.text('0 colaboradores ativos'), findsOneWidget);
        // Equipe Antiga filtrada por padrão (status = Ativas)
        expect(find.text('Equipe Antiga'), findsNothing);

        // Filtro Inativas
        await tester.tap(find.widgetWithText(ChoiceChip, 'Inativas'));
        await tester.pumpAndSettle();
        expect(find.text('Equipe Antiga'), findsOneWidget);
        expect(find.text('Equipe Alvenaria'), findsNothing);

        // Voltar para Ativas e buscar por nome do líder
        await tester.tap(find.widgetWithText(ChoiceChip, 'Ativas'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('search_equipes_input')),
          'Alberto',
        );
        await tester.pumpAndSettle();
        expect(find.text('Equipe Alvenaria'), findsOneWidget);
        expect(find.text('Equipe Vazia'), findsNothing);

        // Limpar busca
        await tester.enterText(
          find.byKey(const Key('search_equipes_input')),
          '',
        );
        await tester.pumpAndSettle();

        // Tentar inativar equipe COM membros ativos -> exibe AlertDialog de confirmação
        await tester.tap(find.byKey(const Key('btn_toggle_equipe_eq-1')));
        await tester.pumpAndSettle();
        expect(find.text('Inativar Equipe'), findsWidgets);
        expect(find.textContaining('histórico de chamadas'), findsOneWidget);

        // Cancelar mantém ativa
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(
          fakeRepo.equipes.firstWhere((e) => e.id == 'eq-1').isActive,
          isTrue,
        );

        // Confirmar inativação
        await tester.tap(find.byKey(const Key('btn_toggle_equipe_eq-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_confirm_inativar_equipe')));
        await tester.pumpAndSettle();
        expect(
          fakeRepo.equipes.firstWhere((e) => e.id == 'eq-1').isActive,
          isFalse,
        );

        // Inativar equipe SEM membros ativos -> sem AlertDialog
        await tester.tap(find.byKey(const Key('btn_toggle_equipe_eq-2')));
        await tester.pumpAndSettle();
        expect(
          fakeRepo.equipes.firstWhere((e) => e.id == 'eq-2').isActive,
          isFalse,
        );
      },
    );
  });

  group('Rotas RH e Sidebar', () {
    test('RhPaths.equipes e equipesFor retornam paths esperados', () {
      expect(RhPaths.equipes, equals('rh/equipes'));
      expect(RhPaths.equipesFor('c1'), equals('/construtoras/c1/rh/equipes'));
    });

    testWidgets(
      'rota /construtoras/:cId/rh/equipes abre FuncionariosListScreen na aba Equipes',
      (tester) async {
        final router = GoRouter(
          initialLocation: RhPaths.equipesFor('c1'),
          routes: [
            GoRoute(
              path: '/construtoras/:cId',
              builder: (_, _) => const SizedBox.shrink(),
              routes: rhRoutes,
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              rhRepositoryProvider.overrideWithValue(fakeRepo),
              trustedDevProvider.overrideWith((ref) => Stream.value(true)),
              authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_add_equipe_fab')), findsOneWidget);
        expect(find.byKey(const Key('search_equipes_input')), findsOneWidget);
      },
    );

    testWidgets('SigoSidebar exibe Funcionários (RH) e Equipes de Trabalho', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(true)),
            authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SigoSidebar(
                activeRoute: '/construtoras/c1/rh/equipes',
                isCollapsed: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Funcionários (RH)'), findsOneWidget);
      expect(find.text('Equipes de Trabalho'), findsOneWidget);
    });
  });

  group('Fase 2a — FuncionarioFormScreen criação inline de equipe', () {
    testWidgets(
      'cria equipe inline pelo botão + Nova equipe, auto-seleciona e salva vínculo',
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

        // Clicar no botão inline + Nova equipe
        final inlineBtn = find.byKey(const Key('btn_inline_create_equipe'));
        expect(inlineBtn, findsOneWidget);
        await tester.tap(inlineBtn);
        await tester.pumpAndSettle();

        // Criar nova equipe no dialog
        await tester.enterText(
          find.byKey(const Key('equipe_form_name_input')),
          'Equipe Acabamento Inline',
        );
        await tester.tap(find.byKey(const Key('btn_save_equipe_form')));
        await tester.pumpAndSettle();

        expect(fakeRepo.equipes.length, equals(1));
        final createdEquipe = fakeRepo.equipes.first;

        // Verificar que a equipe recém-criada foi selecionada automaticamente
        expect(find.text('Equipe Acabamento Inline'), findsOneWidget);

        // Preencher restante do formulário e salvar funcionário
        await tester.enterText(
          find.byKey(const Key('funcionario_name_input')),
          'Lucas Azulejista',
        );
        await tester.enterText(
          find.byKey(const Key('funcionario_cpf_input')),
          validCpf,
        );
        await tester.enterText(
          find.byKey(const Key('funcionario_role_input')),
          'Azulejista',
        );
        await tester.enterText(
          find.byKey(const Key('funcionario_salary_input')),
          '3000.00',
        );
        await tester.pumpAndSettle();

        final saveBtn = find.byKey(const Key('btn_save_funcionario'));
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.funcionarios.length, equals(1));
        expect(fakeRepo.funcionarios.first.teamId, equals(createdEquipe.id));
      },
    );
  });
}

import 'package:app/src/design_system/sigo_theme.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/atribuir_lotacao_lote_sheet.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/rh/data/rh_repository.dart';
import 'package:app/src/features/rh/domain/equipe.dart';
import 'package:app/src/features/rh/domain/funcionario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyRhRepository implements RhRepository {
  final List<Equipe> createdEquipes = [];

  @override
  Future<void> createEquipe(Equipe equipe) async {
    createdEquipes.add(equipe);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyLoteRepository implements LoteRepository {
  Map<String, dynamic>? lastEquipeCall;
  Map<String, dynamic>? lastFuncionarioCall;

  @override
  Future<void> atribuirEquipe({
    required String loteId,
    required String equipeId,
    required String equipeNome,
    String? leaderName,
    String? etapaId,
  }) async {
    lastEquipeCall = {
      'loteId': loteId,
      'equipeId': equipeId,
      'equipeNome': equipeNome,
      'leaderName': leaderName,
      'etapaId': etapaId,
    };
  }

  @override
  Future<void> atribuirFuncionario({
    required String loteId,
    required String funcionarioId,
    required String funcionarioNome,
    required String role,
    String? etapaId,
  }) async {
    lastFuncionarioCall = {
      'loteId': loteId,
      'funcionarioId': funcionarioId,
      'funcionarioNome': funcionarioNome,
      'role': role,
      'etapaId': etapaId,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Lote _makeLote() {
  final now = DateTime(2026, 10, 1);
  return Lote(
    id: 'lo1',
    construtoraId: 'c1',
    loteamentoId: 'lt1',
    quadraId: 'q1',
    name: 'Lote 31',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('AtribuirLotacaoLoteSheet', () {
    testWidgets(
      'filtra apenas equipes ativas e chama atribuirEquipe com vinculo geral',
      (tester) async {
        final spy = _SpyLoteRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loteRepositoryProvider.overrideWithValue(spy),
              trustedDevProvider.overrideWith((ref) => Stream.value(false)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({
                  'isActive': true,
                  'isAdmin': false,
                  'modules': ['lotes'],
                }),
              ),
              equipesStreamProvider('c1').overrideWith(
                (ref) => Stream.value([
                  Equipe(
                    id: 'eq-ativa',
                    construtoraId: 'c1',
                    name: 'Equipe Alvenaria A',
                    leaderName: 'Carlos',
                    isActive: true,
                  ),
                  Equipe(
                    id: 'eq-inativa',
                    construtoraId: 'c1',
                    name: 'Equipe Inativa',
                    isActive: false,
                  ),
                ]),
              ),
              funcionariosStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Funcionario>[])),
            ],
            child: MaterialApp(
              theme: SigoTheme.lightTheme,
              home: Scaffold(
                body: AtribuirLotacaoLoteSheet(
                  construtoraId: 'c1',
                  lote: _makeLote(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Equipe Alvenaria A'), findsOneWidget);
        expect(find.text('Líder: Carlos'), findsOneWidget);
        expect(find.text('Equipe Inativa'), findsNothing);

        await tester.tap(find.text('Atribuir'));
        await tester.pumpAndSettle();

        expect(spy.lastEquipeCall, isNotNull);
        expect(spy.lastEquipeCall!['loteId'], 'lo1');
        expect(spy.lastEquipeCall!['equipeId'], 'eq-ativa');
        expect(spy.lastEquipeCall!['equipeNome'], 'Equipe Alvenaria A');
        expect(spy.lastEquipeCall!['leaderName'], 'Carlos');
        expect(spy.lastEquipeCall!['etapaId'], isNull);
      },
    );

    testWidgets(
      'filtra apenas funcionarios ativos e atribui vinculado a etapa especifica',
      (tester) async {
        final spy = _SpyLoteRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loteRepositoryProvider.overrideWithValue(spy),
              trustedDevProvider.overrideWith((ref) => Stream.value(false)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({
                  'isActive': true,
                  'isAdmin': false,
                  'modules': ['lotes'],
                }),
              ),
              equipesStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Equipe>[])),
              funcionariosStreamProvider('c1').overrideWith(
                (ref) => Stream.value([
                  Funcionario(
                    id: 'fn-ativo',
                    construtoraId: 'c1',
                    name: 'João Silva',
                    cpf: '12345678901',
                    role: 'Pedreiro',
                    employmentType: 'clt',
                    salaryBasis: 'mensal',
                    baseSalaryCents: 250000,
                    isActive: true,
                  ),
                  Funcionario(
                    id: 'fn-inativo',
                    construtoraId: 'c1',
                    name: 'Pedro Inativo',
                    cpf: '10987654321',
                    role: 'Servente',
                    employmentType: 'clt',
                    salaryBasis: 'mensal',
                    baseSalaryCents: 180000,
                    isActive: false,
                  ),
                ]),
              ),
            ],
            child: MaterialApp(
              theme: SigoTheme.lightTheme,
              home: Scaffold(
                body: AtribuirLotacaoLoteSheet(
                  construtoraId: 'c1',
                  lote: _makeLote(),
                  initialEtapaId: 'lo1_muro',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Troca para a aba Funcionários RH
        await tester.tap(find.text('Funcionários RH'));
        await tester.pumpAndSettle();

        expect(find.text('João Silva'), findsOneWidget);
        expect(find.text('Pedreiro'), findsOneWidget);
        expect(find.text('Pedro Inativo'), findsNothing);

        await tester.tap(find.text('Atribuir'));
        await tester.pumpAndSettle();

        expect(spy.lastFuncionarioCall, isNotNull);
        expect(spy.lastFuncionarioCall!['loteId'], 'lo1');
        expect(spy.lastFuncionarioCall!['funcionarioId'], 'fn-ativo');
        expect(spy.lastFuncionarioCall!['funcionarioNome'], 'João Silva');
        expect(spy.lastFuncionarioCall!['role'], 'Pedreiro');
        expect(spy.lastFuncionarioCall!['etapaId'], 'lo1_muro');
      },
    );

    testWidgets(
      'com canRh == true exibe botao + Nova equipe no estado vazio, cria equipe via dialogo e disponibiliza para atribuicao',
      (tester) async {
        final spyLote = _SpyLoteRepository();
        final spyRh = _SpyRhRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loteRepositoryProvider.overrideWithValue(spyLote),
              rhRepositoryProvider.overrideWithValue(spyRh),
              trustedDevProvider.overrideWith((ref) => Stream.value(false)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({
                  'isActive': true,
                  'isAdmin': false,
                  'modules': ['rh'],
                }),
              ),
              equipesStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Equipe>[])),
              funcionariosStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Funcionario>[])),
            ],
            child: MaterialApp(
              theme: SigoTheme.lightTheme,
              home: Scaffold(
                body: AtribuirLotacaoLoteSheet(
                  construtoraId: 'c1',
                  lote: _makeLote(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('btn_nova_equipe_contextual_lote')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('msg_sem_permissao_criar_equipe')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('btn_nova_equipe_contextual_lote')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('equipe_form_name_input')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('equipe_form_name_input')),
          'Equipe Elétrica Nova',
        );
        await tester.tap(find.byKey(const Key('btn_save_equipe_form')));
        await tester.pumpAndSettle();

        expect(spyRh.createdEquipes, hasLength(1));
        expect(spyRh.createdEquipes.first.name, 'Equipe Elétrica Nova');
        expect(spyRh.createdEquipes.first.construtoraId, 'c1');

        // A equipe recém-criada já aparece disponível na lista e o botão no cabeçalho segue visível
        expect(find.text('Equipe Elétrica Nova'), findsOneWidget);
        expect(
          find.byKey(const Key('btn_nova_equipe_contextual_lote')),
          findsOneWidget,
        );

        await tester.tap(find.text('Atribuir'));
        await tester.pumpAndSettle();

        expect(spyLote.lastEquipeCall, isNotNull);
        expect(spyLote.lastEquipeCall!['equipeNome'], 'Equipe Elétrica Nova');
      },
    );

    testWidgets(
      'com canRh == false oculta botao + Nova equipe e exibe mensagem orientativa no estado vazio',
      (tester) async {
        final spyLote = _SpyLoteRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loteRepositoryProvider.overrideWithValue(spyLote),
              trustedDevProvider.overrideWith((ref) => Stream.value(false)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({
                  'isActive': true,
                  'isAdmin': false,
                  'modules': ['lotes'],
                }),
              ),
              equipesStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Equipe>[])),
              funcionariosStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Funcionario>[])),
            ],
            child: MaterialApp(
              theme: SigoTheme.lightTheme,
              home: Scaffold(
                body: AtribuirLotacaoLoteSheet(
                  construtoraId: 'c1',
                  lote: _makeLote(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('btn_nova_equipe_contextual_lote')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('msg_sem_permissao_criar_equipe')),
          findsOneWidget,
        );
      },
    );
  });
}

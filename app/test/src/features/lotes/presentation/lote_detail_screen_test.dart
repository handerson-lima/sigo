import 'package:app/src/design_system/sigo_theme.dart';
import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/construtoras/routing/construtora_routes.dart';
import 'package:app/src/features/etapas/data/etapa_repository.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:app/src/features/etapas/presentation/etapas_list_screen.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/lote_detail_screen.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/rh/data/rh_repository.dart';
import 'package:app/src/features/rh/domain/equipe.dart';
import 'package:app/src/features/rh/domain/funcionario.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _seedLoteComEtapas(
  FakeFirebaseFirestore firestore,
  Lote lote,
) async {
  final etapaRepo = EtapaRepository(firestore);
  final loteRepo = LoteRepository(firestore, etapaRepo);
  await loteRepo.createLoteComEtapas(lote);
}

Lote _fullLote() {
  final now = DateTime(2026, 10, 1);
  return Lote(
    id: 'lo1',
    construtoraId: 'c1',
    loteamentoId: 'l1',
    quadraId: 'q1',
    name: 'Lote 31',
    logradouro: 'Rua Sandoval Wanderley, s/n',
    frenteM: 10.0,
    profundidadeM: 20.0,
    areaTerrenoM2: 200.0,
    areaConstruidaM2: 49.96,
    taxaOcupacaoPercent: 24.98,
    coeficienteAproveitamento: 0.24,
    areaPermeavelM2: 112.46,
    taxaPermeabilidadePercent: 56.23,
    areaImpermeavelM2: 37.58,
    recuoFrontalM: 5.05,
    recuoFundoM: 5.94,
    recuoLateralEsquerdoM: 1.43,
    recuoLateralDireitoM: 1.43,
    proprietarioNome: 'CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA',
    proprietarioDocumento: '69.307.863/0001-02',
    responsavelTecnicoNome: 'JOCSA RAMOS VARELA',
    responsavelTecnicoRegistro: '2116022975',
    dataProjeto: 'outubro/26',
    equipesVinculadas: const [
      {'id': 'eq1', 'name': 'Equipe Alvenaria A', 'leaderName': 'Carlos'},
    ],
    funcionariosVinculados: const [
      {
        'id': 'fn1',
        'name': 'João Silva',
        'role': 'Pedreiro',
        'etapaId': 'lo1_muro',
      },
    ],
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('LoteDetailScreen', () {
    testWidgets(
      'exibe ficha tecnica completa, remove vinculos e recalcula progresso ao atualizar etapa',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        final etapaRepo = EtapaRepository(firestore);
        final loteRepo = LoteRepository(firestore, etapaRepo);
        await _seedLoteComEtapas(firestore, _fullLote());

        final router = GoRouter(
          initialLocation:
              '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/detalhes',
          routes: construtoraRoutes,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trustedDevProvider.overrideWith((ref) => Stream.value(true)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
              ),
              etapaRepositoryProvider.overrideWithValue(etapaRepo),
              loteRepositoryProvider.overrideWithValue(loteRepo),
              equipesStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Equipe>[])),
              funcionariosStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Funcionario>[])),
            ],
            child: MaterialApp.router(
              theme: SigoTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(LoteDetailScreen), findsOneWidget);
        expect(find.text('Lote 31'), findsWidgets);
        expect(find.text('Rua Sandoval Wanderley, s/n'), findsOneWidget);

        // Medidas principais
        expect(find.text('10 m'), findsOneWidget);
        expect(find.text('20 m'), findsOneWidget);
        expect(find.text('200 m²'), findsOneWidget);
        expect(find.text('49,96 m²'), findsOneWidget);

        // Índices urbanísticos, recuos e carimbo
        expect(find.text('Índices Urbanísticos'), findsOneWidget);
        expect(find.text('24,98%'), findsOneWidget);
        expect(find.text('0,24'), findsOneWidget);
        expect(find.text('Recuos'), findsOneWidget);
        expect(find.text('5,05 m'), findsOneWidget);
        expect(find.text('Carimbo e Responsáveis'), findsOneWidget);
        expect(
          find.text('CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA'),
          findsOneWidget,
        );
        expect(find.text('JOCSA RAMOS VARELA'), findsOneWidget);

        // Alocações e remoção em 1 toque
        expect(find.text('Equipe Alvenaria A'), findsOneWidget);
        expect(find.text('João Silva'), findsOneWidget);

        final removerEqBtn = find.byKey(
          const Key('remover_equipe_eq1_geral'),
        );
        await tester.ensureVisible(removerEqBtn);
        await tester.tap(removerEqBtn);
        await tester.pumpAndSettle();

        expect(find.text('Equipe Alvenaria A'), findsNothing);

        // Checklist das 5 etapas: marca Muro como Concluída (20% geral)
        final muroConcluida = find.byKey(
          const Key('etapa_status_muro_concluida'),
        );
        await tester.ensureVisible(muroConcluida);
        await tester.tap(muroConcluida);
        await tester.pumpAndSettle();

        // Verifica recálculo atômico no documento do lote
        final loteSnap = await firestore.collection('lotes').doc('lo1').get();
        expect(loteSnap.data()?['progressoPercentual'], 20);
        expect(loteSnap.data()?['etapasConcluidasCount'], 1);
        expect(
          (loteSnap.data()?['statusEtapasMap'] as Map)['muro'],
          EtapaStatus.concluida,
        );
        expect(
          find.text('Progresso Geral (1/5 etapas concluídas)'),
          findsOneWidget,
        );

        // Marca Cinza/1ª como Em andamento (default 50% -> média 30%)
        final cinza1EmAndamento = find.byKey(
          const Key('etapa_status_cinza1_em_andamento'),
        );
        await tester.ensureVisible(cinza1EmAndamento);
        await tester.tap(cinza1EmAndamento);
        await tester.pumpAndSettle();

        final loteSnap2 = await firestore.collection('lotes').doc('lo1').get();
        expect(loteSnap2.data()?['progressoPercentual'], 30);

        // Ajusta Cinza/1ª para 75% via chip rápido (média (100+75)/5 = 35%)
        final cinza1Pct75 = find.byKey(const Key('etapa_pct_cinza1_75'));
        await tester.ensureVisible(cinza1Pct75);
        await tester.tap(cinza1Pct75);
        await tester.pumpAndSettle();

        final loteSnap3 = await firestore.collection('lotes').doc('lo1').get();
        expect(loteSnap3.data()?['progressoPercentual'], 35);
      },
    );

    testWidgets(
      'edita dados do lote e permite navegar para Ver Etapas',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        final etapaRepo = EtapaRepository(firestore);
        final loteRepo = LoteRepository(firestore, etapaRepo);
        final now = DateTime(2026, 10, 1);
        await _seedLoteComEtapas(
          firestore,
          Lote(
            id: 'lo2',
            construtoraId: 'c1',
            loteamentoId: 'l1',
            quadraId: 'q1',
            name: 'Lote 02',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final router = GoRouter(
          initialLocation:
              '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo2/detalhes',
          routes: construtoraRoutes,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trustedDevProvider.overrideWith((ref) => Stream.value(true)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({'isActive': true, 'isAdmin': true}),
              ),
              etapaRepositoryProvider.overrideWithValue(etapaRepo),
              loteRepositoryProvider.overrideWithValue(loteRepo),
            ],
            child: MaterialApp.router(
              theme: SigoTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Seções opcionais vazias não aparecem
        expect(find.text('Índices Urbanísticos'), findsNothing);
        expect(find.text('Recuos'), findsNothing);
        expect(find.text('Carimbo e Responsáveis'), findsNothing);

        // Abre dialog Editar Lote e altera o nome
        await tester.tap(find.byKey(const Key('lote_detail_editar_btn')));
        await tester.pumpAndSettle();

        final nameField = find.widgetWithText(TextFormField, 'Nome do Lote *');
        await tester.enterText(nameField, 'Lote 02 Atualizado');
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        final snap = await firestore.collection('lotes').doc('lo2').get();
        expect(snap.data()?['name'], 'Lote 02 Atualizado');

        // Navega para EtapasListScreen via botão Ver Etapas
        await tester.tap(find.byKey(const Key('lote_detail_ver_etapas_btn')));
        await tester.pumpAndSettle();

        expect(find.byType(EtapasListScreen), findsOneWidget);
        expect(
          router.state.uri.path,
          '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo2/etapas',
        );
      },
    );

    testWidgets(
      'Admin do loteamento ve Editar Lote e Atribuir Equipe ou Funcionario',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        final etapaRepo = EtapaRepository(firestore);
        final loteRepo = LoteRepository(firestore, etapaRepo);
        await _seedLoteComEtapas(firestore, _fullLote());

        final router = GoRouter(
          initialLocation:
              '/construtoras/c1/loteamentos/l1/quadras/q1/lotes/lo1/detalhes',
          routes: construtoraRoutes,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trustedDevProvider.overrideWith((ref) => Stream.value(false)),
              construtoraPermissionProvider('c1').overrideWith(
                (ref) => Stream.value({
                  'isActive': true,
                  'isAdmin': false,
                  'modules': <String>[],
                }),
              ),
              effectiveLoteamentoObraIdProvider((
                construtoraId: 'c1',
                loteamentoId: 'l1',
              )).overrideWithValue(const AsyncValue.data('l1')),
              currentPermissionsProvider((construtoraId: 'c1', obraId: 'l1'))
                  .overrideWith(
                    (ref) => Stream.value(
                      ObraMember(
                        userId: 'u1',
                        isActive: true,
                        isAdmin: true,
                        modules: const [],
                        joinedAt: DateTime(2026),
                      ),
                    ),
                  ),
              etapaRepositoryProvider.overrideWithValue(etapaRepo),
              loteRepositoryProvider.overrideWithValue(loteRepo),
              equipesStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Equipe>[])),
              funcionariosStreamProvider(
                'c1',
              ).overrideWith((ref) => Stream.value(const <Funcionario>[])),
            ],
            child: MaterialApp.router(
              theme: SigoTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lote_detail_editar_btn')), findsOneWidget);
        expect(find.byKey(const Key('lote_detail_atribuir_btn')), findsOneWidget);
      },
    );
  });
}

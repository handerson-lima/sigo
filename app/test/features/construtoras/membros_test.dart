import 'dart:async';

import 'package:app/src/features/construtoras/domain/construtora_member.dart';
import 'package:app/src/features/construtoras/domain/membro.dart';
import 'package:app/src/features/construtoras/presentation/member_detalhe_sheet.dart';
import 'package:app/src/features/construtoras/presentation/membros_providers.dart';
import 'package:app/src/features/construtoras/presentation/membros_screen.dart';
import 'package:app/src/features/construtoras/presentation/widgets/obra_vinculo_row.dart';
import 'package:app/src/features/obras/domain/obra.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ObraMember _om(String uid, {bool isActive = true, bool isAdmin = false}) =>
    ObraMember(
      userId: uid,
      isActive: isActive,
      isAdmin: isAdmin,
      joinedAt: DateTime(2026, 1, 1),
    );

Obra _obra(String id, {bool isActive = true}) => Obra(
      id: id,
      construtoraId: 'c-1',
      name: 'Obra $id',
      createdAt: DateTime(2026, 1, 1),
      isActive: isActive,
    );

void main() {
  group('8.1 agregação uid→N', () {
    test('soma obras por uid ignorando inativos', () {
      final result = agregarContagem([
        [_om('u1'), _om('u2')],
        [_om('u1'), _om('u3', isActive: false)],
      ]);
      expect(result, {'u1': 2, 'u2': 1});
      expect(result.containsKey('u3'), isFalse);
    });

    test('lista vazia retorna mapa vazio', () {
      expect(agregarContagem([]), isEmpty);
      expect(agregarContagem([[]]), isEmpty);
    });

    test('contagem independe de papel (nunca owner em obra)', () {
      final result = agregarContagem([
        [_om('u1', isAdmin: true), _om('u1', isAdmin: false)],
      ]);
      expect(result['u1'], 2);
    });

    test('fan-out real: contagem via obrasAtivas+obraMembers mockados', () async {
      final container = ProviderContainer(
        overrides: [
          obrasDaConstrutoraProvider('c-1').overrideWith(
            (ref) => Stream.value([
              _obra('o1'),
              _obra('o2', isActive: false),
              _obra('o3'),
            ]),
          ),
          obraMembersProvider((construtoraId: 'c-1', obraId: 'o1'))
              .overrideWith((ref) => Stream.value([_om('u1'), _om('u2')])),
          obraMembersProvider((construtoraId: 'c-1', obraId: 'o3'))
              .overrideWith(
            (ref) => Stream.value([_om('u1'), _om('u3', isActive: false)]),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Mantém os autoDispose vivos enquanto os streams emitem.
      final subAtivas =
          container.listen(obrasAtivasProvider('c-1'), (a, b) {});
      final subO1 = container.listen(
        obraMembersProvider((construtoraId: 'c-1', obraId: 'o1')),
        (a, b) {},
      );
      final subO3 = container.listen(
        obraMembersProvider((construtoraId: 'c-1', obraId: 'o3')),
        (a, b) {},
      );
      addTearDown(subAtivas.close);
      addTearDown(subO1.close);
      addTearDown(subO3.close);

      // Aguarda os streams base emitirem (o2 inativa nunca é assinada).
      await container.read(obrasAtivasProvider('c-1').future);
      await container
          .read(
            obraMembersProvider((construtoraId: 'c-1', obraId: 'o1')).future,
          );
      await container
          .read(
            obraMembersProvider((construtoraId: 'c-1', obraId: 'o3')).future,
          );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(contagemObrasPorMembroProvider('c-1')),
        {'u1': 2, 'u2': 1},
      );
    });
  });

  group('8.1 filtro isActive de obras', () {
    test('apenasObrasAtivas remove inativas', () {
      final todas = [_obra('o1'), _obra('o2', isActive: false), _obra('o3')];
      final ativas = apenasObrasAtivas(todas);
      expect(ativas.map((o) => o.id), ['o1', 'o3']);
    });
  });

  group('8.1 singular/plural', () {
    test('textoContagemObras 0/1/N', () {
      expect(textoContagemObras(0), 'Nenhuma obra vinculada');
      expect(textoContagemObras(1), '1 obra');
      expect(textoContagemObras(2), '2 obras');
    });

    test('subtitleMembroAtivo combina cargo + contador', () {
      final op = Membro(uid: 'u', isAdmin: false, role: 'operario');
      expect(subtitleMembroAtivo(op, 2), 'Operário · 2 obras');
      final adm = Membro(uid: 'a', isAdmin: true, role: 'admin');
      expect(subtitleMembroAtivo(adm, 1), 'Administrador · 1 obra');
      expect(subtitleMembroAtivo(adm, 0), 'Administrador · Nenhuma obra vinculada');
    });

    test('normaliza member legado → Operário', () {
      expect(rotuloCargoPendente('member'), 'Operário');
      expect(rotuloCargoPendente(null), 'Operário');
      expect(rotuloCargoPendente('operario'), 'Operário');
      expect(rotuloCargoPendente('admin'), 'Administrador');
      expect(rotuloCargoPendente(' Admin '), 'Administrador');
      expect(rotuloCargoPendente('OWNER'), 'Proprietário');
      expect(rotuloCargoPendente('  member  '), 'Operário');
      expect(subtitlePendente('operario'), 'Pendente · Operário');
    });
  });

  group('8.1 encode/decode (round-trip do cache de leitura)', () {
    test('Membro sobrevive ao mapa do provider', () {
      final original = Membro(
        uid: 'u1',
        isAdmin: true,
        isOwner: false,
        role: 'admin',
        email: 'a@x.com',
      );
      final encoded = {
        'uid': original.uid,
        'isAdmin': original.isAdmin,
        'isOwner': original.isOwner,
        'role': original.role,
        'email': original.email,
      };
      final decoded = Membro.fromFirestore(
        Map<String, dynamic>.from(encoded)..remove('uid'),
        encoded['uid'] as String,
      );
      expect(decoded.uid, original.uid);
      expect(decoded.isAdmin, original.isAdmin);
      expect(decoded.isOwner, original.isOwner);
      expect(decoded.role, original.role);
      expect(decoded.email, original.email);
    });

    test('Obra toJson/fromJson preserva id e isActive', () {
      final original = _obra('o9');
      final decoded = Obra.fromJson(
        Map<String, dynamic>.from(original.toJson()),
      );
      expect(decoded.id, 'o9');
      expect(decoded.isActive, isTrue);
      final inativa = Obra.fromJson(
        Map<String, dynamic>.from(_obra('o8', isActive: false).toJson()),
      );
      expect(inativa.isActive, isFalse);
    });

    test('ObraMember toJson/fromJson preserva vínculo', () {
      final original = _om('u7', isAdmin: true);
      final decoded = ObraMember.fromJson(
        Map<String, dynamic>.from(original.toJson()),
      );
      expect(decoded.userId, 'u7');
      expect(decoded.isActive, isTrue);
      expect(decoded.isAdmin, isTrue);
    });
  });

  testWidgets('8.1 pendente no topo + ativos com Cargo · N obras', (tester) async {
    final mockMembros = [
      Membro(uid: 'u1', email: 'op1@x.com', isAdmin: false, role: 'operario'),
      Membro(uid: 'u2', email: 'adm@x.com', isAdmin: true, role: 'admin'),
    ];
    final mockPending = [
      {
        'id': 'p1',
        'email': 'novo@x.com',
        'displayName': 'Novo Membro',
        'role': 'operario',
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWith((ref) => Stream.value(mockMembros)),
          pendingRequestsProvider('c-1')
              .overrideWith((ref) => Stream.value(mockPending)),
          contagemObrasPorMembroProvider('c-1')
              .overrideWith((ref) => {'u1': 2}),
          contagemObrasMetaProvider('c-1')
              .overrideWith((ref) => (carregando: false, erro: false)),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();

    // Pendente no topo (chip + subtitle com email em 2 linhas; sem emoji).
    expect(find.text('Novo Membro'), findsOneWidget);
    expect(find.text('Pendente · Operário'), findsOneWidget);
    expect(
      find.text('Pendente · Operário\nnovo@x.com'),
      findsOneWidget,
    );
    expect(find.textContaining('novo@x.com'), findsOneWidget);
    expect(find.textContaining('⏳'), findsNothing);

    // Ativos abaixo com Cargo · N obras.
    expect(find.text('Operário · 2 obras'), findsOneWidget);
    expect(
      find.text('Administrador · Nenhuma obra vinculada'),
      findsOneWidget,
    );

    // Ordem: pendente antes dos ativos.
    final pendenteY = tester.getTopLeft(find.text('Novo Membro')).dy;
    final ativoY = tester.getTopLeft(find.text('op1@x.com')).dy;
    expect(pendenteY, lessThan(ativoY));
  });

  testWidgets('8.1 contagem carregando mostra placeholder …', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWith(
            (ref) => Stream.value([
              Membro(
                uid: 'u1',
                email: 'op1@x.com',
                isAdmin: false,
                role: 'operario',
              ),
            ]),
          ),
          pendingRequestsProvider('c-1').overrideWith(
            (ref) => Stream.value(const <Map<String, dynamic>>[]),
          ),
          obrasDaConstrutoraProvider('c-1')
              .overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pump();
    expect(find.text('Operário · …'), findsOneWidget);
  });

  testWidgets('8.1 erro no pendente não esconde a lista', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWith(
            (ref) => Stream.value([
              Membro(
                uid: 'u1',
                email: 'op1@x.com',
                isAdmin: false,
                role: 'operario',
              ),
            ]),
          ),
          pendingRequestsProvider('c-1').overrideWithValue(
            AsyncValue.error(Exception('pendente falhou'), StackTrace.empty),
          ),
          contagemObrasPorMembroProvider('c-1').overrideWith((ref) => {}),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar as solicitações pendentes.'),
      findsOneWidget,
    );
    expect(find.text('op1@x.com'), findsOneWidget);
  });

  testWidgets('8.1 vazio mostra mensagem pt-br', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWith((ref) => Stream.value([])),
          pendingRequestsProvider('c-1')
              .overrideWith((ref) => Stream.value([])),
          contagemObrasPorMembroProvider('c-1').overrideWith((ref) => {}),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum membro encontrado.'), findsOneWidget);
  });

  testWidgets('8.1 erro leitura mostra retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWithValue(
            AsyncValue.error(Exception('falha leitura'), StackTrace.empty),
          ),
          pendingRequestsProvider('c-1')
              .overrideWith((ref) => Stream.value([])),
          contagemObrasPorMembroProvider('c-1').overrideWith((ref) => {}),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os membros. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
  });

  testWidgets('8.1 retry refaz o watch (refetch)', (tester) async {
    var pendingBuilds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWithValue(
            AsyncValue.error(Exception('falha leitura'), StackTrace.empty),
          ),
          pendingRequestsProvider('c-1').overrideWith((ref) {
            pendingBuilds++;
            return Stream.value(const <Map<String, dynamic>>[]);
          }),
          contagemObrasPorMembroProvider('c-1').overrideWith((ref) => {}),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(pendingBuilds, 1);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(pendingBuilds, 2);
  });

  testWidgets('8.1 obraMembers loading mostra placeholder sem zero falso',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWith(
            (ref) => Stream.value([
              Membro(
                uid: 'u1',
                email: 'op1@x.com',
                isAdmin: false,
                role: 'operario',
              ),
            ]),
          ),
          pendingRequestsProvider('c-1').overrideWith(
            (ref) => Stream.value(const <Map<String, dynamic>>[]),
          ),
          obrasDaConstrutoraProvider('c-1')
              .overrideWith((ref) => Stream.value([_obra('o1')])),
          obraMembersProvider((construtoraId: 'c-1', obraId: 'o1'))
              .overrideWith((ref) => Stream<List<ObraMember>>.empty()),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Operário · …'), findsOneWidget);
    expect(find.text('Nenhuma obra vinculada'), findsNothing);
  });

  testWidgets('8.1 obraMembers com erro mostra placeholder sem zero falso',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWith(
            (ref) => Stream.value([
              Membro(
                uid: 'u1',
                email: 'op1@x.com',
                isAdmin: false,
                role: 'operario',
              ),
            ]),
          ),
          pendingRequestsProvider('c-1').overrideWith(
            (ref) => Stream.value(const <Map<String, dynamic>>[]),
          ),
          obrasDaConstrutoraProvider('c-1')
              .overrideWith((ref) => Stream.value([_obra('o1')])),
          obraMembersProvider((construtoraId: 'c-1', obraId: 'o1'))
              .overrideWithValue(
            AsyncValue.error(Exception('obraMembers falhou'), StackTrace.empty),
          ),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Operário · …'), findsOneWidget);
    expect(find.text('Nenhuma obra vinculada'), findsNothing);
  });

  testWidgets('8.1 obrasAtivas com erro mostra placeholder sem zero falso',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWith(
            (ref) => Stream.value([
              Membro(
                uid: 'u1',
                email: 'op1@x.com',
                isAdmin: false,
                role: 'operario',
              ),
            ]),
          ),
          pendingRequestsProvider('c-1').overrideWith(
            (ref) => Stream.value(const <Map<String, dynamic>>[]),
          ),
          obrasAtivasProvider('c-1').overrideWithValue(
            AsyncValue.error(Exception('obras falhou'), StackTrace.empty),
          ),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Operário · …'), findsOneWidget);
    expect(find.text('Nenhuma obra vinculada'), findsNothing);
  });

  testWidgets('8.1 retry invalida obraMembers (contador incrementa)',
      (tester) async {
    var obraMembersBuilds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWithValue(
            AsyncValue.error(Exception('falha leitura'), StackTrace.empty),
          ),
          pendingRequestsProvider('c-1').overrideWith(
            (ref) => Stream.value(const <Map<String, dynamic>>[]),
          ),
          obrasDaConstrutoraProvider('c-1')
              .overrideWith((ref) => Stream.value([_obra('o1')])),
          obraMembersProvider((construtoraId: 'c-1', obraId: 'o1'))
              .overrideWith((ref) {
            obraMembersBuilds++;
            return Stream<List<ObraMember>>.empty();
          }),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(obraMembersBuilds, 1);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(obraMembersBuilds, 2);
  });

  testWidgets('8.1 pendente sujo usa fallbacks (Solicitação pendente)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1')
              .overrideWith((ref) => Stream.value(const [])),
          pendingRequestsProvider('c-1').overrideWith(
            (ref) => Stream.value([
              {'role': 123, 'displayName': '   ', 'email': '  '},
            ]),
          ),
          contagemObrasPorMembroProvider('c-1').overrideWith((ref) => {}),
          contagemObrasMetaProvider('c-1')
              .overrideWith((ref) => (carregando: false, erro: false)),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Solicitação pendente'), findsOneWidget);
    expect(find.text('Pendente · Operário'), findsNWidgets(2));
  });

  testWidgets('8.1 ativo com email em branco mostra UID', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWith(
            (ref) => Stream.value([
              Membro(uid: 'u-xyz', email: '   ', isAdmin: false),
            ]),
          ),
          pendingRequestsProvider('c-1')
              .overrideWith((ref) => Stream.value([])),
          contagemObrasPorMembroProvider('c-1').overrideWith((ref) => {}),
          contagemObrasMetaProvider('c-1')
              .overrideWith((ref) => (carregando: false, erro: false)),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('UID: u-xyz'), findsOneWidget);
  });

  testWidgets('8.1 pending loading + vazio não mostra mensagem de vazio',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1')
              .overrideWith((ref) => Stream.value(const [])),
          pendingRequestsProvider('c-1')
              .overrideWith((ref) => Stream.empty()),
          contagemObrasPorMembroProvider('c-1').overrideWith((ref) => {}),
          contagemObrasMetaProvider('c-1')
              .overrideWith((ref) => (carregando: false, erro: false)),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pump();
    expect(find.text('Nenhum membro encontrado.'), findsNothing);
  });

  testWidgets('8.1 email do pendente visível com displayName', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1')
              .overrideWith((ref) => Stream.value(const [])),
          pendingRequestsProvider('c-1').overrideWith(
            (ref) => Stream.value([
              {
                'displayName': 'Novo Membro',
                'email': 'novo@x.com',
                'role': 'operario',
              },
            ]),
          ),
          contagemObrasPorMembroProvider('c-1').overrideWith((ref) => {}),
          contagemObrasMetaProvider('c-1')
              .overrideWith((ref) => (carregando: false, erro: false)),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Novo Membro'), findsOneWidget);
    expect(find.textContaining('novo@x.com'), findsOneWidget);
  });

  testWidgets('8.1 offline sem cache mostra Sem conexão', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membrosProvider('c-1').overrideWithValue(
            AsyncValue.error(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
              ),
              StackTrace.empty,
            ),
          ),
          pendingRequestsProvider('c-1')
              .overrideWith((ref) => Stream.value([])),
          contagemObrasPorMembroProvider('c-1').overrideWith((ref) => {}),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão — tente novamente'), findsOneWidget);
  });

  group('8.2 filtros e busca (puros)', () {
    test('construirMapaUidObras ignora inativos', () {
      final mapa = construirMapaUidObras({
        'o1': [_om('u1'), _om('u2')],
        'o2': [_om('u1'), _om('u3', isActive: false)],
      });
      expect(mapa['u1'], {'o1', 'o2'});
      expect(mapa['u2'], {'o1'});
      expect(mapa.containsKey('u3'), isFalse);
    });

    test('filtrarMembros por obra; nulo/vazio retorna todos', () {
      final membros = [
        Membro(uid: 'u1', isAdmin: false, email: 'a@x.com'),
        Membro(uid: 'u2', isAdmin: false, email: 'b@x.com'),
      ];
      final mapa = {
        'u1': {'o1'},
        'u2': {'o2'},
      };
      expect(
        filtrarMembros(membros, mapa, 'o1').map((m) => m.uid),
        ['u1'],
      );
      expect(filtrarMembros(membros, mapa, null), hasLength(2));
      expect(filtrarMembros(membros, mapa, ''), hasLength(2));
      expect(filtrarMembros(membros, mapa, 'oX'), isEmpty);
    });

    test('buscarMembros trim/case-insensitive + fallback UID', () {
      final membros = [
        Membro(uid: 'u1', isAdmin: false, email: 'Ana@obra.com'),
        Membro(uid: 'u2', isAdmin: false, email: 'bob@obra.com'),
        Membro(uid: 'u-xyz', isAdmin: false, email: '   '),
      ];
      expect(buscarMembros(membros, '').map((m) => m.uid),
          ['u1', 'u2', 'u-xyz']);
      expect(buscarMembros(membros, 'ana').map((m) => m.uid), ['u1']);
      expect(buscarMembros(membros, '  ANA  ').map((m) => m.uid), ['u1']);
      expect(buscarMembros(membros, 'u-xyz').map((m) => m.uid), ['u-xyz']);
      expect(buscarMembros(membros, 'sem-match'), isEmpty);
    });

    test('filtrarPendentes por email ou displayName com trim/lower', () {
      final pendentes = [
        {'email': 'Ana.Souza@x.com', 'displayName': 'Ana Souza'},
        {'email': 'carlos@x.com', 'displayName': 'Carlos'},
        {'role': 123, 'displayName': '   ', 'email': '  '},
      ];
      expect(filtrarPendentes(pendentes, ''), hasLength(3));
      expect(filtrarPendentes(pendentes, 'ana'), hasLength(1));
      expect(filtrarPendentes(pendentes, '  ANA  '), hasLength(1));
      expect(
        filtrarPendentes(pendentes, 'ana souza').first['email'],
        'Ana.Souza@x.com',
      );
      expect(filtrarPendentes(pendentes, 'carlos@x.com'), hasLength(1));
      expect(filtrarPendentes(pendentes, 'sem-match'), isEmpty);
    });
  });

  group('8.2 filtros e busca (widget)', () {
    final mockMembros82 = [
      Membro(uid: 'u1', email: 'ana@obra.com', isAdmin: false, role: 'operario'),
      Membro(uid: 'u2', email: 'bob@obra.com', isAdmin: false, role: 'operario'),
    ];
    final mockPending82 = [
      {
        'id': 'p1',
        'email': 'ana.souza@x.com',
        'displayName': 'Ana Souza',
        'role': 'operario',
      },
    ];

    base82({
      List<Membro>? membros,
      List<Map<String, dynamic>>? pending,
      List<Obra>? obras,
      Map<String, List<ObraMember>>? porObra,
      Stream<List<Membro>> Function()? membrosStream,
      Stream<List<Map<String, dynamic>>>? pendingStream,
      AsyncValue<List<Map<String, dynamic>>>? pendingValue,
      Stream<List<Obra>>? obrasStream,
      Stream<List<ObraMember>> Function()? vinculosStream,
      AsyncValue<List<ObraMember>>? vinculosValue,
    }) {
      return [
        membrosProvider('c-1')
            .overrideWith((ref) => membrosStream?.call() ?? Stream.value(membros ?? mockMembros82)),
        if (pendingValue != null)
          pendingRequestsProvider('c-1').overrideWithValue(pendingValue)
        else
          pendingRequestsProvider('c-1')
            .overrideWith((ref) => pendingStream ?? Stream.value(pending ?? mockPending82)),
        obrasDaConstrutoraProvider('c-1')
            .overrideWith((ref) => obrasStream ?? Stream.value(obras ?? [_obra('o1')])),
        for (final entry in (porObra ??
                {
                  'o1': [_om('u1')],
                })
            .entries)
          if (entry.key == 'o1' && vinculosValue != null)
            obraMembersProvider((construtoraId: 'c-1', obraId: entry.key))
                .overrideWithValue(vinculosValue)
          else
            obraMembersProvider((construtoraId: 'c-1', obraId: entry.key))
                .overrideWith((ref) => entry.key == 'o1' && vinculosStream != null
                    ? vinculosStream() : Stream.value(entry.value)),
      ];
    }


    Future<void> selecionarObra(WidgetTester tester, String nome) async {
      await tester.tap(find.text('Por obra'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(nome).last);
      await tester.pumpAndSettle();
    }

    testWidgets('8.2 erro dos vínculos preserva controles e permite retry', (tester) async {
      var leituras = 0;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: base82(vinculosStream: () {
          leituras++;
          return leituras == 1
              ? Stream.error(Exception('falhou'))
              : Stream.value([_om('u1')]);
        }),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await selecionarObra(tester, 'Obra o1');
      expect(find.text('Não foi possível carregar os membros desta obra.'), findsOneWidget);
      expect(find.text('Nenhum membro encontrado.'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(leituras, 1);
      await tester.tap(find.text('Recarregar'));
      await tester.pumpAndSettle();
      expect(find.text('ana@obra.com'), findsOneWidget);
      expect(leituras, 2);
    });

    testWidgets('8.2 pendentes loading com ativos aguarda emissão', (tester) async {
      final stream = StreamController<List<Map<String, dynamic>>>();
      addTearDown(stream.close);
      await tester.pumpWidget(ProviderScope(
        overrides: base82(pendingStream: stream.stream),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pendentes'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum membro encontrado.'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      stream.add(mockPending82);
      await tester.pumpAndSettle();
      expect(find.text('Ana Souza'), findsOneWidget);
    });

    testWidgets('8.2 vínculos selecionados loading aguarda emissão', (tester) async {
      final stream = StreamController<List<ObraMember>>();
      addTearDown(stream.close);
      await tester.pumpWidget(ProviderScope(
        overrides: base82(vinculosStream: () => stream.stream),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await selecionarObra(tester, 'Obra o1');
      expect(find.text('Nenhum membro encontrado.'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      stream.add([_om('u1')]);
      await tester.pumpAndSettle();
      expect(find.text('ana@obra.com'), findsOneWidget);
    });

    testWidgets('8.2 outra obra loading não bloqueia resultado vazio nem busca', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...base82(obras: [_obra('o1'), _obra('o2')], porObra: {'o1': []}),
          obraMembersProvider((construtoraId: 'c-1', obraId: 'o2'))
              .overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await selecionarObra(tester, 'Obra o1');
      expect(find.text('Nenhum membro encontrado.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'sem-match');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum membro encontrado.'), findsOneWidget);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('8.2 dropdown longo cabe em 360px com escala 1.3', (tester) async {
      final nome = 'Obra com nome muito extenso ' * 10;
      await tester.pumpWidget(ProviderScope(
        overrides: base82(obras: [Obra(id: 'o1', construtoraId: 'c-1',
          name: nome, createdAt: DateTime(2026))]),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await selecionarObra(tester, nome);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
      // Isola o controle real da tela; a barra global tem layout próprio.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: dropdown)),
      ));
      await tester.pumpAndSettle();
      expect(find.text(nome), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('8.2 pull-to-refresh atualiza dados mantendo filtro obra e busca', (tester) async {
      var leituras = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: base82(membrosStream: () {
          leituras++;
          return Stream.value([Membro(uid: 'u1', isAdmin: false,
            email: leituras == 1 ? 'ana@obra.com' : 'ana.nova@obra.com')]);
        }),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await selecionarObra(tester, 'Obra o1');
      await tester.enterText(find.byType(TextField), 'ana');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(leituras, greaterThan(1));
      expect(find.text('ana.nova@obra.com'), findsOneWidget);
      expect(find.text('Obra o1'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'ana');
      expect(tester.widget<SegmentedButton<FiltroMembros>>(
        find.byType(SegmentedButton<FiltroMembros>)).selected, {FiltroMembros.porObra});
    });

    for (final desativada in [false, true]) {
      testWidgets('8.2 obra selecionada removida/desativada $desativada limpa seleção', (tester) async {
        final stream = StreamController<List<Obra>>();
        addTearDown(stream.close);
        await tester.pumpWidget(ProviderScope(
          overrides: base82(obrasStream: stream.stream,
            porObra: {'o1': [_om('u1')], 'o2': [_om('u2')]}),
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ));
        stream.add([_obra('o1'), _obra('o2')]);
        await tester.pumpAndSettle();
        await selecionarObra(tester, 'Obra o1');
        stream.add([if (desativada) _obra('o1', isActive: false), _obra('o2')]);
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(tester.element(find.byType(MembrosScreen)));
        expect(container.read(obraSelecionadaProvider), isNull);
        expect(find.text('Selecione uma obra'), findsOneWidget);
        expect(find.text('Obra o1'), findsNothing);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Obra o2').last);
        await tester.pumpAndSettle();
        expect(find.text('bob@obra.com'), findsOneWidget);
      });
    }

    testWidgets('8.2 base vazia mantém controles e estado sem obras', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: base82(membros: [], pending: [], obras: [], porObra: {}),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('Por obra'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma obra ativa'), findsOneWidget);
    });

    testWidgets('8.2 erro pendente fica em Todos/Pendentes e some em Por obra', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: base82(pendingValue: AsyncValue.error(Exception('falhou'), StackTrace.empty)),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sem-match');
      await tester.pumpAndSettle();
      const aviso = 'Não foi possível carregar as solicitações pendentes.';
      expect(find.text(aviso), findsOneWidget);
      expect(find.text('Nenhum membro encontrado.'), findsOneWidget);
      await tester.tap(find.text('Pendentes'));
      await tester.pumpAndSettle();
      expect(find.text(aviso), findsOneWidget);
      expect(find.text('Nenhum membro encontrado.'), findsOneWidget);
      await selecionarObra(tester, 'Obra o1');
      expect(find.text(aviso), findsNothing);
      expect(find.text('Nenhum membro encontrado.'), findsOneWidget);
    });

    testWidgets('8.2 Por obra filtra via uid→obras e exclui pendentes',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: base82(
            obras: [_obra('o1'), _obra('o2')],
            porObra: {
              'o1': [_om('u1')],
              'o2': [_om('u2')],
            },
          ),
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ),
      );
      await tester.pumpAndSettle();

      // Base Todos: tudo visível.
      expect(find.text('ana@obra.com'), findsOneWidget);
      expect(find.text('Ana Souza'), findsOneWidget);

      await tester.tap(find.text('Por obra'));
      await tester.pumpAndSettle();
      // Sem obra selecionada: orientação (pendentes excluídos).
      expect(find.text('Ana Souza'), findsNothing);
      expect(find.text('Selecione uma obra'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obra o1').last);
      await tester.pumpAndSettle();

      // Dropdown reflete a obra selecionada após reload.
      expect(find.text('Obra o1'), findsOneWidget);
      expect(find.text('ana@obra.com'), findsOneWidget);
      expect(find.text('bob@obra.com'), findsNothing);
      expect(find.text('Ana Souza'), findsNothing);
    });

    testWidgets('8.2 busca ativo trim/case-insensitive', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: base82(pending: const []),
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  ANA  ');
      await tester.pumpAndSettle();

      expect(find.text('ana@obra.com'), findsOneWidget);
      expect(find.text('bob@obra.com'), findsNothing);
    });

    testWidgets('8.2 Pendentes filtra por displayName', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: base82(),
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pendentes'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('ana@obra.com'), findsNothing);

      await tester.enterText(find.byType(TextField), 'souza');
      await tester.pumpAndSettle();
      expect(find.text('Ana Souza'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'sem-match');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum membro encontrado.'), findsOneWidget);
    });

    testWidgets('8.2 busca sem match mostra vazio', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: base82(),
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzz-sem-match');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum membro encontrado.'), findsOneWidget);
    });

    testWidgets('8.2 dropdown sem obra mostra Nenhuma obra ativa',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: base82(obras: const [], porObra: const {}),
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Por obra'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma obra ativa'), findsOneWidget);
      expect(find.text('Selecione uma obra'), findsOneWidget);
    });

    testWidgets('8.2 Por obra com obras em loading mostra indicador',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membrosProvider('c-1')
                .overrideWith((ref) => Stream.value(mockMembros82)),
            pendingRequestsProvider('c-1').overrideWith(
              (ref) => Stream.value(const <Map<String, dynamic>>[]),
            ),
            obrasDaConstrutoraProvider('c-1')
                .overrideWith((ref) => const Stream.empty()),
          ],
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Por obra'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Selecione uma obra'), findsOneWidget);
      expect(find.text('Nenhum membro encontrado.'), findsNothing);
    });

    testWidgets('8.2 Por obra com erro em obras mostra mensagem',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membrosProvider('c-1')
                .overrideWith((ref) => Stream.value(mockMembros82)),
            pendingRequestsProvider('c-1').overrideWith(
              (ref) => Stream.value(const <Map<String, dynamic>>[]),
            ),
            obrasAtivasProvider('c-1').overrideWithValue(
              AsyncValue.error(Exception('obras falhou'), StackTrace.empty),
            ),
          ],
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Por obra'));
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível carregar as obras.'),
        findsOneWidget,
      );
    });

    testWidgets('8.2 Limpar busca restaura a lista', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: base82(pending: const []),
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('bob@obra.com'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pumpAndSettle();
      expect(find.text('ana@obra.com'), findsOneWidget);
      expect(find.text('bob@obra.com'), findsNothing);

      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(find.text('ana@obra.com'), findsOneWidget);
      expect(find.text('bob@obra.com'), findsOneWidget);
      expect(find.byTooltip('Limpar busca'), findsNothing);
    });
  });

  group('8.3 detalhe do membro', () {
    final membros83 = [
      Membro(uid: 'u1', email: 'ana@obra.com', isAdmin: false, role: 'operario'),
    ];
    final pending83 = [
      {
        'id': 'p1',
        'email': 'novo@x.com',
        'displayName': 'Novo Membro',
        'role': 'operario',
      },
    ];

    ConstrutoraMember cm(
      String uid, {
      bool isActive = true,
      bool isOwner = false,
      bool isAdmin = false,
      DateTime? joinedAt,
    }) =>
        ConstrutoraMember(
          userId: uid,
          isActive: isActive,
          isOwner: isOwner,
          isAdmin: isAdmin,
          joinedAt: joinedAt ?? DateTime(2026, 1, 15),
        );

    base83({
      List<Membro>? membros,
      List<Map<String, dynamic>>? pending,
      List<Obra>? obras,
      Map<String, List<ObraMember>>? porObra,
      Future<ConstrutoraMember?> Function()? vinculoFuture,
      AsyncValue<ConstrutoraMember?>? vinculoValue,
      Stream<List<Obra>>? obrasStream,
      Stream<List<Obra>> Function()? obrasFactory,
      AsyncValue<List<Obra>>? obrasValue,
      Stream<List<ObraMember>> Function()? vinculosStream,
      AsyncValue<List<ObraMember>>? vinculosValue,
      String uid = 'u1',
    }) {
      return [
        membrosProvider('c-1')
            .overrideWith((ref) => Stream.value(membros ?? membros83)),
        pendingRequestsProvider('c-1').overrideWith(
          (ref) => Stream.value(pending ?? pending83),
        ),
        if (obrasValue != null)
          obrasDaConstrutoraProvider('c-1').overrideWithValue(obrasValue)
        else if (obrasFactory != null)
          obrasDaConstrutoraProvider('c-1')
              .overrideWith((ref) => obrasFactory())
        else
          obrasDaConstrutoraProvider('c-1').overrideWith(
            (ref) => obrasStream ?? Stream.value(obras ?? [_obra('o1')]),
          ),
        for (final entry in (porObra ??
                {
                  'o1': [_om('u1')],
                })
            .entries)
          if (entry.key == 'o1' && vinculosValue != null)
            obraMembersProvider((construtoraId: 'c-1', obraId: entry.key))
                .overrideWithValue(vinculosValue)
          else
            obraMembersProvider((construtoraId: 'c-1', obraId: entry.key))
                .overrideWith(
              (ref) => entry.key == 'o1' && vinculosStream != null
                  ? vinculosStream()
                  : Stream.value(entry.value),
            ),
        if (vinculoValue != null)
          memberDetalheProvider((construtoraId: 'c-1', uid: uid))
              .overrideWithValue(vinculoValue)
        else
          memberDetalheProvider((construtoraId: 'c-1', uid: uid)).overrideWith(
            (ref) =>
                vinculoFuture?.call() ??
                Future<ConstrutoraMember?>.value(cm(uid)),
          ),
      ];
    }

    Future<void> abrirDetalhe(WidgetTester tester) async {
      await tester.tap(find.text('ana@obra.com'));
      await tester.pumpAndSettle();
    }

    Future<void> abrirDetalheComSpinner(WidgetTester tester) async {
      await tester.tap(find.text('ana@obra.com'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    void viewportMobile(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('8.3 ativo abre BottomSheet com vínculo, obras e ações',
        (tester) async {
      viewportMobile(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: base83(),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Detalhe de ana@obra.com'), findsOneWidget);
      expect(find.text('Vínculo construtora'), findsOneWidget);
      expect(find.text('Operário'), findsWidgets);
      expect(find.text('Ativo'), findsWidgets);
      expect(find.text('Desde 15/01/2026'), findsOneWidget);
      expect(find.text('Obras vinculadas'), findsOneWidget);
      expect(find.byType(ObraVinculoRow), findsOneWidget);
      expect(find.text('Obra o1'), findsOneWidget);
      expect(find.text('Operário'), findsWidgets);
      expect(find.text('Ações'), findsOneWidget);
      expect(find.text('Disponível em breve'), findsOneWidget);

      final atribuir = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Atribuir à obra'),
      );
      expect(atribuir.onPressed, isNull);
    });

    testWidgets('8.3 sem obras mostra microcopy estática sem CTA',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: base83(porObra: {'o1': []}),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(
        find.text('Nenhuma obra vinculada — Atribuir'),
        findsOneWidget,
      );
      expect(find.byType(ObraVinculoRow), findsNothing);
      expect(find.byType(ObraVinculoVazio), findsOneWidget);
      final ctaAcionavel = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .where((b) => b.onPressed != null);
      expect(ctaAcionavel, isEmpty);
    });

    testWidgets('8.3 membro inativo mostra aviso Ative na construtora primeiro',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: base83(
          vinculoFuture: () async => cm('u1', isActive: false),
        ),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(find.text('Ative na construtora primeiro'), findsOneWidget);
      expect(find.text('Inativo'), findsOneWidget);
      expect(find.text('Desde 15/01/2026'), findsOneWidget);
    });

    testWidgets('8.3 vínculo loading mostra spinner (sem vazio falso)',
        (tester) async {
      viewportMobile(tester);
      final completer = Completer<ConstrutoraMember?>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete(cm('u1'));
      });
      await tester.pumpWidget(ProviderScope(
        overrides: base83(vinculoFuture: () => completer.future),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalheComSpinner(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(
        find.text('Nenhuma obra vinculada — Atribuir'),
        findsNothing,
      );
      expect(find.text('Desde 15/01/2026'), findsNothing);
    });

    testWidgets('8.3 vínculo erro mostra mensagem e retry refaz a leitura',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: base83(
          vinculoValue: AsyncValue.error(
            Exception('falhou'),
            StackTrace.empty,
          ),
        ),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(
        find.text('Não foi possível carregar o vínculo.'),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('8.3 retry do vínculo refaz a leitura via getMember',
        (tester) async {
      var leituras = 0;
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: base83(
          vinculoFuture: () {
            leituras++;
            if (leituras == 1) {
              return Future<ConstrutoraMember?>.error(
                Exception('falhou'),
                StackTrace.empty,
              );
            }
            return Future<ConstrutoraMember?>.value(cm('u1'));
          },
        ),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(
        find.text('Não foi possível carregar o vínculo.'),
        findsOneWidget,
      );
      expect(leituras, 1);
      await tester.tap(find.text('Tentar novamente').first);
      await tester.pumpAndSettle();
      expect(leituras, 2);
      expect(find.text('Desde 15/01/2026'), findsOneWidget);
    });

    testWidgets('8.3 pendente não abre detalhe e não tem chevron',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: base83(membros: const [], pending: pending83),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();

      final row = tester.widget<ListTile>(
        find
            .ancestor(
              of: find.text('Novo Membro'),
              matching: find.byType(ListTile),
            )
            .first,
      );
      expect(row.onTap, isNull);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.tap(find.text('Novo Membro'));
      await tester.pumpAndSettle();
      expect(find.byType(MemberDetalheSheet), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('8.3 obras loading mostra spinner sem vazio falso',
        (tester) async {
      final stream = StreamController<List<Obra>>();
      addTearDown(stream.close);
      await tester.pumpWidget(ProviderScope(
        overrides: base83(obrasStream: stream.stream),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalheComSpinner(tester);

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(
        find.text('Nenhuma obra vinculada — Atribuir'),
        findsNothing,
      );
      stream.add([_obra('o1')]);
      await tester.pumpAndSettle();
      expect(find.byType(ObraVinculoRow), findsOneWidget);
      expect(
        find.text('Nenhuma obra vinculada — Atribuir'),
        findsNothing,
      );
    });

    testWidgets('8.3 obras erro mostra erro + retry sem virar vazio',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: base83(
          obrasValue: AsyncValue.error(
            Exception('obras falhou'),
            StackTrace.empty,
          ),
        ),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(
        find.text('Não foi possível carregar as obras.'),
        findsOneWidget,
      );
      expect(
        find.text('Nenhuma obra vinculada — Atribuir'),
        findsNothing,
      );
      expect(find.text('Tentar novamente'), findsWidgets);
    });

    testWidgets('8.3 retry de obras refaz o watch (factory reexecuta)',
        (tester) async {
      var leituras = 0;
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: base83(
          obrasFactory: () {
            leituras++;
            if (leituras == 1) {
              return Stream<List<Obra>>.error(Exception('obras falhou'));
            }
            return Stream<List<Obra>>.value([_obra('o1')]);
          },
        ),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(
        find.text('Não foi possível carregar as obras.'),
        findsOneWidget,
      );
      expect(leituras, greaterThanOrEqualTo(1));

      await tester.tap(find.text('Tentar novamente').last);
      await tester.pumpAndSettle();
      expect(find.byType(ObraVinculoRow), findsOneWidget);
      expect(
        find.text('Não foi possível carregar as obras.'),
        findsNothing,
      );
      expect(leituras, greaterThan(1));
    });

    testWidgets('8.3 a11y anuncia nome, cargo, N obras e status; Esc fecha',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(ProviderScope(
          overrides: base83(),
          child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
        ));
        await tester.pumpAndSettle();
        await abrirDetalhe(tester);

        expect(find.byType(MemberDetalheSheet), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp(r'ana@obra\.com.*Operário.*1 obra.*Ativo'),
          ),
          findsWidgets,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(MemberDetalheSheet), findsNothing);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('8.3 desktop abre Dialog 480px (breakpoint >=800)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: base83(),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(MemberDetalheSheet), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 480),
        findsOneWidget,
      );
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).shape,
        isA<RoundedRectangleBorder>(),
      );
    });

    testWidgets('8.3 textScale 1.3 sem overflow em CTA, chips e linha',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: base83(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => MemberDetalheSheet.show(
                    context: context,
                    construtoraId: 'c-1',
                    membro: membros83.first,
                  ),
                  child: const Text('ana@obra.com'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(MemberDetalheSheet), findsOneWidget);
      expect(find.text('Detalhe de ana@obra.com'), findsOneWidget);
      expect(find.byType(ObraVinculoRow), findsOneWidget);
      expect(find.text('Atribuir à obra'), findsOneWidget);
      expect(find.byType(ObraVinculoVazio), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('8.3 formatarJoinedAt e rotuloPapelObra / status em pt-br', () {
      expect(formatarJoinedAt(DateTime(2026, 3, 7)), '07/03/2026');
      expect(rotuloStatusVinculo(true), 'Ativo');
      expect(rotuloStatusVinculo(false), 'Inativo');
      expect(rotuloPapelObra(_om('u1', isAdmin: false)), 'Operário');
      expect(rotuloPapelObra(_om('u1', isAdmin: true)), 'Admin da obra');
      expect(rotuloCargoFlags(isOwner: false, isAdmin: false), 'Operário');
      expect(rotuloCargoFlags(isOwner: false, isAdmin: true), 'Administrador');
      expect(rotuloCargoFlags(isOwner: true, isAdmin: true), 'Proprietário');
      expect(obrasVinculadasVazioLabel, 'Nenhuma obra vinculada — Atribuir');
    });

    testWidgets('8.3 ativo tem onTap na linha (chevron visível)',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: base83(),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();

      final row = tester.widget<ListTile>(
        find
            .ancestor(
              of: find.text('ana@obra.com'),
              matching: find.byType(ListTile),
            )
            .first,
      );
      expect(row.onTap, isNotNull);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('8.3 chip Proprietário no sheet via flags do vínculo',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: base83(
          membros: [
            Membro(
              uid: 'u1',
              email: 'ana@obra.com',
              isOwner: true,
              isAdmin: true,
            ),
          ],
          vinculoFuture: () async => cm('u1', isOwner: true, isAdmin: true),
        ),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(find.text('Proprietário'), findsWidgets);
      expect(find.text('Detalhe de ana@obra.com'), findsOneWidget);
    });

    testWidgets('8.3 chip Administrador no sheet via flags do vínculo',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: base83(
          membros: [
            Membro(uid: 'u1', email: 'ana@obra.com', isAdmin: true),
          ],
          vinculoFuture: () async => cm('u1', isAdmin: true),
        ),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(find.text('Administrador'), findsWidgets);
      expect(find.text('Proprietário'), findsNothing);
    });

    testWidgets('8.3 título fallback Detalhe de UID quando email vazio',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: base83(
          membros: [Membro(uid: 'u1', email: '', isAdmin: false)],
        ),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UID: u1'));
      await tester.pumpAndSettle();

      expect(find.text('Detalhe de UID: u1'), findsOneWidget);
      expect(find.byType(MemberDetalheSheet), findsOneWidget);
    });

    testWidgets('8.3 retry quando erro vem de obraMembers (obras ok)',
        (tester) async {
      var leituras = 0;
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: base83(
          vinculosStream: () {
            leituras++;
            if (leituras == 1) {
              return Stream<List<ObraMember>>.error(
                Exception('members falhou'),
              );
            }
            return Stream<List<ObraMember>>.value([_om('u1')]);
          },
        ),
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ));
      await tester.pumpAndSettle();
      await abrirDetalhe(tester);

      expect(
        find.text('Não foi possível carregar as obras.'),
        findsOneWidget,
      );
      expect(find.byType(ObraVinculoRow), findsNothing);
      expect(leituras, greaterThanOrEqualTo(1));

      await tester.tap(find.text('Tentar novamente').last);
      await tester.pumpAndSettle();
      expect(find.byType(ObraVinculoRow), findsOneWidget);
      expect(
        find.text('Não foi possível carregar as obras.'),
        findsNothing,
      );
      expect(leituras, greaterThan(1));
    });
  });
}

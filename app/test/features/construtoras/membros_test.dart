import 'package:app/src/features/construtoras/domain/membro.dart';
import 'package:app/src/features/construtoras/presentation/membros_providers.dart';
import 'package:app/src/features/construtoras/presentation/membros_screen.dart';
import 'package:app/src/features/obras/domain/obra.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
        ],
        child: const MaterialApp(home: MembrosScreen(construtoraId: 'c-1')),
      ),
    );
    await tester.pumpAndSettle();

    // Pendente no topo (subtitle + chip com o mesmo texto; ícone sem emoji).
    expect(find.text('Novo Membro'), findsOneWidget);
    expect(find.text('Pendente · Operário'), findsNWidgets(2));
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
}

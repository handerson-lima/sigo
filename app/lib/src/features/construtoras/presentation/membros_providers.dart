import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../sync/read_cache.dart';
import '../../obras/data/obra_repository.dart';
import '../../obras/domain/obra.dart';
import '../../obras/domain/obra_member.dart';
import '../data/construtora_repository.dart';
import '../data/membros_repository.dart';
import '../domain/construtora_member.dart';
import '../domain/membro.dart';

/// Chave do par (construtora, obra) para [obraMembersProvider].
typedef ObraMembersKey = ({String construtoraId, String obraId});

/// Base reexportada da tela (isolada aqui para reuso em 8.2/8.3).
final membrosProvider =
    StreamProvider.autoDispose.family<List<Membro>, String>((ref, construtoraId) {
  final repo = ref.watch(membrosRepositoryProvider);
  return cachedList<Membro>(
    'construtoras/$construtoraId/construtora_members',
    repo.watchMembros(construtoraId),
    (m) => {'uid': m.uid, 'isAdmin': m.isAdmin, 'isOwner': m.isOwner, 'role': m.role, 'email': m.email},
    (d) {
      final map = Map<String, dynamic>.from(d as Map);
      return Membro.fromFirestore(map, map['uid'] as String? ?? '');
    },
  );
});

final pendingRequestsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, construtoraId) {
  final repo = ref.watch(membrosRepositoryProvider);
  return cachedList<Map<String, dynamic>>(
    'access_requests/$construtoraId/pending',
    repo.watchPendingRequests(construtoraId),
    (m) => m,
    (d) => Map<String, dynamic>.from(d as Map),
  );
});

/// Obras da construtora (stream). A UI filtra ativas via [apenasObrasAtivas].
final obrasDaConstrutoraProvider =
    StreamProvider.autoDispose.family<List<Obra>, String>((ref, construtoraId) {
  final repo = ref.watch(obraRepositoryProvider);
  return cachedList<Obra>(
    'construtoras/$construtoraId/obras',
    repo.watchObras(construtoraId),
    (o) => o.toJson(),
    (d) => Obra.fromJson(Map<String, dynamic>.from(d as Map)),
  );
});

/// Derivado de [obrasDaConstrutoraProvider]: filtra ativas no cliente.
/// Assinatura única de `watchObras` (via base); sem segundo stream.
final obrasAtivasProvider =
    StreamProvider.autoDispose.family<List<Obra>, String>((ref, construtoraId) {
  final obras = ref.watch(obrasDaConstrutoraProvider(construtoraId));
  return obras.when(
    data: (lista) => Stream.value(apenasObrasAtivas(lista)),
    loading: () => const Stream.empty(),
    error: (e, s) => Stream.error(e, s),
  );
});

/// Membros de uma obra (já filtrado `isActive` no cliente, sem collectionGroup).
final obraMembersProvider = StreamProvider.autoDispose
    .family<List<ObraMember>, ObraMembersKey>((ref, key) {
  final repo = ref.watch(obraRepositoryProvider);
  return cachedList<ObraMember>(
    'construtoras/${key.construtoraId}/obras/${key.obraId}/members-ativos',
    repo.watchObraMembers(key.construtoraId, key.obraId),
    (m) => m.toJson(),
    (d) => ObraMember.fromJson(Map<String, dynamic>.from(d as Map)),
  );
});

/// Meta de loading/erro da contagem (evita zero falso).
/// carregando=true se obras loading sem valor ou algum obraMembers loading;
/// erro=true se obras ou algum obraMembers tem erro.
final contagemObrasMetaProvider = Provider.autoDispose
    .family<({bool carregando, bool erro}), String>((ref, construtoraId) {
  final obrasAsync = ref.watch(obrasAtivasProvider(construtoraId));
  final obrasErro = obrasAsync.hasError;
  final obrasCarregandoSemValor =
      obrasAsync.isLoading && !obrasAsync.hasValue;
  final obras = obrasAsync.value ?? const <Obra>[];
  var algumCarregando = false;
  var algumErro = false;
  for (final obra in obras) {
    final mAsync = ref.watch(
      obraMembersProvider(
        (construtoraId: construtoraId, obraId: obra.id),
      ),
    );
    if (mAsync.isLoading) algumCarregando = true;
    if (mAsync.hasError) algumErro = true;
  }
  return (
    carregando: obrasCarregandoSemValor || algumCarregando,
    erro: obrasErro || algumErro,
  );
});

/// Junção em memória `uid → count` de obras ativas por membro.
final contagemObrasPorMembroProvider =
    Provider.autoDispose.family<Map<String, int>, String>((ref, construtoraId) {
  final obras = ref.watch(obrasAtivasProvider(construtoraId)).value ?? const <Obra>[];
  final listas = <List<ObraMember>>[];
  for (final obra in obras) {
    final members = ref
            .watch(
              obraMembersProvider(
                (construtoraId: construtoraId, obraId: obra.id),
              ),
            )
            .value ??
        const <ObraMember>[];
    listas.add(members);
  }
  return agregarContagem(listas);
});

// ---------------------------------------------------------------------------
// Funções puras (testáveis sem Firebase).
// ---------------------------------------------------------------------------

/// Filtra apenas obras com `isActive == true`.
List<Obra> apenasObrasAtivas(List<Obra> todas) =>
    todas.where((o) => o.isActive).toList();

/// Agrega `uid → N obras`. Ignora vínculos inativos (defensivo: o
/// repositório já filtra, mas a junção nunca conta inativo).
/// Nunca trata `owner` como papel de obra: contagem independe de papel.
Map<String, int> agregarContagem(List<List<ObraMember>> porObra) {
  final contagem = <String, int>{};
  for (final lista in porObra) {
    for (final m in lista) {
      if (!m.isActive) continue;
      contagem[m.userId] = (contagem[m.userId] ?? 0) + 1;
    }
  }
  return contagem;
}

/// Cargo na construtora a partir das flags: owner → Proprietário,
/// admin → Administrador, resto (operario/member/legado) → Operário.
String rotuloCargoFlags({required bool isOwner, required bool isAdmin}) {
  if (isOwner) return 'Proprietário';
  if (isAdmin) return 'Administrador';
  return 'Operário';
}

/// Cargo na construtora: owner → Proprietário, admin → Administrador,
/// resto (operario/member/legado) → Operário.
String rotuloCargo(Membro membro) =>
    rotuloCargoFlags(isOwner: membro.isOwner, isAdmin: membro.isAdmin);

/// Normaliza leitura de cargo pendente: `member` legado → Operário.
/// Tolerante a caixa e espaços (`' Admin '` → Administrador).
String rotuloCargoPendente(String? role) {
  switch (role?.trim().toLowerCase()) {
    case 'admin':
      return 'Administrador';
    case 'owner':
      return 'Proprietário';
    default:
      return 'Operário';
  }
}

/// Texto do contador: 0 → `Nenhuma obra vinculada`, 1 → `1 obra`, N → `N obras`.
String textoContagemObras(int n) {
  if (n <= 0) return 'Nenhuma obra vinculada';
  if (n == 1) return '1 obra';
  return '$n obras';
}

/// Subtitle do ativo: `Cargo · N obras` (singular/plural).
String subtitleMembroAtivo(Membro membro, int count) =>
    '${rotuloCargo(membro)} · ${textoContagemObras(count)}';

/// Subtitle do pendente: `Pendente · Cargo`.
String subtitlePendente(String? role) => 'Pendente · ${rotuloCargoPendente(role)}';

// ---------------------------------------------------------------------------
// 8.2 Filtros e busca (estado local + junção uid→obras em memória).
// Sem escrita, sem collectionGroup, sem mudar contratos de cache.
// ---------------------------------------------------------------------------

/// Filtro segmentado da `MembrosScreen`.
enum FiltroMembros { todos, porObra, pendentes }

class FiltroMembrosNotifier extends Notifier<FiltroMembros> {
  @override
  FiltroMembros build() => FiltroMembros.todos;

  void setFiltro(FiltroMembros value) => state = value;
}

final filtroMembrosProvider =
    NotifierProvider.autoDispose<FiltroMembrosNotifier, FiltroMembros>(
  FiltroMembrosNotifier.new,
);

class ObraSelecionadaNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void selecionar(String? obraId) => state = obraId;
  void limpar() => state = null;
}

final obraSelecionadaProvider =
    NotifierProvider.autoDispose<ObraSelecionadaNotifier, String?>(
  ObraSelecionadaNotifier.new,
);

class BuscaMembrosNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
  void limpar() => state = '';
}

final buscaMembrosProvider =
    NotifierProvider.autoDispose<BuscaMembrosNotifier, String>(
  BuscaMembrosNotifier.new,
);

/// Constrói o detalhe `uid → {obraIds}` a partir de `obraId → membros`.
/// Ignora vínculos inativos (defensivo). Nunca atribui papel de obra.
Map<String, Set<String>> construirMapaUidObras(
  Map<String, List<ObraMember>> porObra,
) {
  final mapa = <String, Set<String>>{};
  porObra.forEach((obraId, lista) {
    for (final m in lista) {
      if (!m.isActive) continue;
      mapa.putIfAbsent(m.userId, () => <String>{}).add(obraId);
    }
  });
  return mapa;
}

/// Detalhe `uid → {obraIds}` sobre as obras ativas (mesma fonte da
/// contagem 8.1: `obrasAtivasProvider` + um `obraMembersProvider` por obra).
/// Em loading/erro sem valor, contribui apenas com os vínculos conhecidos.
/// A tela preserva o AsyncValue da obra selecionada para distinguir
/// carregamento e erro de um resultado realmente vazio.
final uidObrasPorMembroProvider =
    Provider.autoDispose.family<Map<String, Set<String>>, String>(
        (ref, construtoraId) {
  final obras =
      ref.watch(obrasAtivasProvider(construtoraId)).value ?? const <Obra>[];
  final porObra = <String, List<ObraMember>>{};
  for (final obra in obras) {
    final members = ref
            .watch(
              obraMembersProvider(
                (construtoraId: construtoraId, obraId: obra.id),
              ),
            )
            .value ??
        const <ObraMember>[];
    porObra[obra.id] = members;
  }
  return construirMapaUidObras(porObra);
});

// ---------------------------------------------------------------------------
// 8.3 Detalhe do membro (somente leitura; sem escrita, sem collectionGroup).
// ---------------------------------------------------------------------------

/// Chave do par (construtora, uid) para o detalhe.
typedef MemberDetalheKey = ({String construtoraId, String uid});

/// Vínculo em `construtora_members/{uid}` via
/// `ConstrutoraRepository.getMember` (server + `cachedRead`).
final memberDetalheProvider = FutureProvider.autoDispose
    .family<ConstrutoraMember?, MemberDetalheKey>((ref, key) {
  final repo = ref.watch(construtoraRepositoryProvider);
  return repo.getMember(key.construtoraId, key.uid);
});

/// Obras ativas vinculadas ao membro: interseção
/// `uidObrasPorMembro[uid]` ∩ `obrasAtivas`, com o vínculo (papel) de
/// cada obra via `obraMembers`. Loading/erro fica em
/// [contagemObrasMetaProvider] — nunca `.value ?? []` como vazio falso.
final obrasVinculadasProvider = Provider.autoDispose
    .family<List<({Obra obra, ObraMember vinculo})>, MemberDetalheKey>(
        (ref, key) {
  final uidObras = ref.watch(uidObrasPorMembroProvider(key.construtoraId));
  final obraIds = uidObras[key.uid] ?? const <String>{};
  if (obraIds.isEmpty) return const [];
  final obras = ref
          .watch(obrasAtivasProvider(key.construtoraId))
          .value ??
      const <Obra>[];
  final resultado = <({Obra obra, ObraMember vinculo})>[];
  for (final obra in obras) {
    if (!obraIds.contains(obra.id)) continue;
    final membros = ref
            .watch(
              obraMembersProvider(
                (construtoraId: key.construtoraId, obraId: obra.id),
              ),
            )
            .value ??
        const <ObraMember>[];
    for (final m in membros) {
      if (m.userId == key.uid && m.isActive) {
        resultado.add((obra: obra, vinculo: m));
        break;
      }
    }
  }
  return resultado;
});

/// Status do vínculo na construtora (pt-br).
String rotuloStatusVinculo(bool isActive) => isActive ? 'Ativo' : 'Inativo';

/// `joinedAt` formatado pt-br (`dd/MM/yyyy`).
String formatarJoinedAt(DateTime joinedAt) =>
    DateFormat('dd/MM/yyyy').format(joinedAt);

/// Papel na obra: `member`/legado → Operário; nunca `owner` como papel de obra.
String rotuloPapelObra(ObraMember vinculo) =>
    vinculo.isAdmin ? 'Admin da obra' : 'Operário';

/// Filtra ativos por obra via junção `uid → obras` em memória.
/// `obraId` nulo/vazio = sem restrição (retorna cópia da entrada).
List<Membro> filtrarMembros(
  List<Membro> membros,
  Map<String, Set<String>> uidParaObras,
  String? obraId,
) {
  if (obraId == null || obraId.isEmpty) return List<Membro>.from(membros);
  return membros
      .where((m) => uidParaObras[m.uid]?.contains(obraId) ?? false)
      .toList();
}

/// Busca local em ativos por email (case-insensitive com trim).
/// Query vazia = sem restrição. Email vazio faz fallback para o UID.
List<Membro> buscarMembros(List<Membro> membros, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List<Membro>.from(membros);
  return membros.where((m) {
    final email = m.email.trim().toLowerCase();
    if (email.isNotEmpty) return email.contains(q);
    return m.uid.toLowerCase().contains(q);
  }).toList();
}

/// Busca local em pendentes por email OU displayName (case-insensitive).
/// Tolerante a valores não-string. Query vazia = sem restrição.
List<Map<String, dynamic>> filtrarPendentes(
  List<Map<String, dynamic>> pendentes,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List<Map<String, dynamic>>.from(pendentes);
  return pendentes.where((r) {
    final emailRaw = r['email'];
    final nomeRaw = r['displayName'];
    final email = emailRaw is String ? emailRaw.trim().toLowerCase() : '';
    final nome = nomeRaw is String ? nomeRaw.trim().toLowerCase() : '';
    return email.contains(q) || nome.contains(q);
  }).toList();
}

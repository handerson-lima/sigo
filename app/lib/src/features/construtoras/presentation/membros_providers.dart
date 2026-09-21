import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/read_cache.dart';
import '../../obras/data/obra_repository.dart';
import '../../obras/domain/obra.dart';
import '../../obras/domain/obra_member.dart';
import '../data/membros_repository.dart';
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

/// Cargo na construtora: owner → Proprietário, admin → Administrador,
/// resto (operario/member/legado) → Operário.
String rotuloCargo(Membro membro) {
  if (membro.isOwner) return 'Proprietário';
  if (membro.isAdmin) return 'Administrador';
  return 'Operário';
}

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

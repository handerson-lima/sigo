import '../../../sync/read_cache.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';
import '../../authentication/data/user_repository.dart';
import '../../loteamentos/data/loteamento_repository.dart';
import '../../loteamentos/domain/loteamento.dart';
import '../../../core/contracts.dart';
import '../domain/obra_member.dart';

typedef ObraScope = ({String construtoraId, String obraId});
typedef LoteamentoScope = ({String construtoraId, String loteamentoId});

/// Verifica se o vínculo em `construtora_members` concede papel administrativo global.
bool isConstrutoraAdminMember(Map<String, dynamic>? cm) {
  return cm?['isActive'] == true &&
      (cm?['isAdmin'] == true ||
          cm?['isOwner'] == true ||
          cm?['role'] == 'admin' ||
          cm?['role'] == 'owner');
}

/// Verifica se o vínculo na construtora concede leitura global do módulo `lotes`.
bool hasGlobalLotesAccess(Map<String, dynamic>? cm) {
  if (cm?['isActive'] != true) return false;
  if (isConstrutoraAdminMember(cm)) return true;
  return normalizeRawModules(
    cm?['modules'],
    cm?['allowedModules'],
  ).contains('lotes');
}

final construtoraPermissionProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, c) {
      final user = ref.watch(authStateChangesProvider).value;
      if (user == null) return Stream.value(null);
      return cachedDocument('construtoras/$c/construtora_members/${user.uid}');
    });

final obraDocProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, ObraScope>((ref, scope) {
      return cachedDocument(
        'construtoras/${scope.construtoraId}/obras/${scope.obraId}',
      );
    });

final currentPermissionsProvider = StreamProvider.autoDispose
    .family<ObraMember?, ObraScope>((ref, scope) {
      final user = ref.watch(authStateChangesProvider).value;
      if (user == null) return Stream.value(null);
      final dev = ref.watch(trustedDevProvider).value == true;
      if (dev) {
        return Stream.value(
          ObraMember(
            userId: user.uid,
            isAdmin: true,
            isActive: true,
            modules: ['diario', 'lotes', 'estoque'],
            joinedAt: DateTime(2000),
          ),
        );
      }

      final cm = ref
          .watch(construtoraPermissionProvider(scope.construtoraId))
          .value;
      if (cm?['isActive'] != true) return Stream.value(null);

      final obraDoc = ref.watch(obraDocProvider(scope)).value;
      if (obraDoc != null && obraDoc['isActive'] == false) {
        return Stream.value(null);
      }

      if (isConstrutoraAdminMember(cm)) {
        return Stream.value(
          ObraMember(
            userId: user.uid,
            isAdmin: true,
            isActive: true,
            modules: ['diario', 'lotes', 'estoque'],
            joinedAt: DateTime(2000),
          ),
        );
      }

      return cachedDocument(
        'construtoras/${scope.construtoraId}/obras/${scope.obraId}/members/${user.uid}',
      ).map((doc) {
        if (doc?['isActive'] != true) return null;
        final data = Map<String, dynamic>.from(doc!);
        data['modules'] = normalizeRawModules(
          data['modules'],
          data['allowedModules'],
        );
        try {
          return ObraMember.fromJson(data);
        } catch (_) {
          return null;
        }
      });
    });

/// Conjunto imutável com igualdade estrutural de IDs de obras ativas do usuário.
@immutable
class ObraIdSet {
  final List<String> ids;

  const ObraIdSet._(this.ids);

  factory ObraIdSet.fromIterable(Iterable<String> raw) {
    final sorted = raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
      ..sort();
    return ObraIdSet._(List<String>.unmodifiable(sorted));
  }

  static final ObraIdSet empty = ObraIdSet._(const []);

  bool get isEmpty => ids.isEmpty;
  bool get isNotEmpty => ids.isNotEmpty;
  bool contains(String id) => ids.contains(id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObraIdSet &&
          runtimeType == other.runtimeType &&
          listEquals(ids, other.ids);

  @override
  int get hashCode => Object.hashAll(ids);
}

/// Lista em tempo real os IDs de obras em que o usuário possui vínculo ativo na construtora.
final userActiveObraIdsProvider = StreamProvider.autoDispose
    .family<ObraIdSet, String>((ref, construtoraId) {
      final user = ref.watch(authStateChangesProvider).value;
      if (user == null) return Stream.value(ObraIdSet.empty);
      final cm = ref.watch(construtoraPermissionProvider(construtoraId)).value;
      if (cm?['isActive'] != true) return Stream.value(ObraIdSet.empty);
      if (Firebase.apps.isEmpty) return Stream.value(ObraIdSet.empty);

      return FirebaseFirestore.instance
          .collectionGroup('members')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            final ids = <String>{};
            for (final doc in snapshot.docs) {
              final obraRef = doc.reference.parent.parent;
              final construtoraRef = obraRef?.parent.parent;
              if (obraRef == null || construtoraRef == null) continue;
              if (construtoraRef.id != construtoraId) continue;
              if (doc.data()['isActive'] != true) continue;
              ids.add(obraRef.id);
            }
            return ObraIdSet.fromIterable(ids);
          });
    });

/// Resolve o `obraId` efetivo de um [Loteamento] (suporta legado onde `obraId != id`),
/// com fallback seguro para `scope.loteamentoId`.
final effectiveLoteamentoObraIdProvider = Provider.autoDispose
    .family<AsyncValue<String>, LoteamentoScope>((ref, scope) {
      final loteamentosAsync = ref.watch(
        watchLoteamentosProvider((construtoraId: scope.construtoraId)),
      );
      if (loteamentosAsync.isLoading && !loteamentosAsync.hasValue) {
        return const AsyncValue.loading();
      }
      final items = loteamentosAsync.value ?? const <Loteamento>[];
      for (final item in items) {
        if (item.id == scope.loteamentoId) {
          return AsyncValue.data(item.effectiveObraId);
        }
      }
      return AsyncValue.data(scope.loteamentoId);
    });

/// Indica se o usuário atual tem poder administrativo sobre o loteamento informado
/// (dev confiável, admin/owner da construtora ou admin da obra vinculada).
final isLoteamentoAdminProvider = Provider.autoDispose
    .family<bool, LoteamentoScope>((ref, scope) {
      if (ref.watch(trustedDevProvider).value == true) return true;
      final cm = ref
          .watch(construtoraPermissionProvider(scope.construtoraId))
          .value;
      if (isConstrutoraAdminMember(cm)) return true;
      if (cm?['isActive'] != true) return false;
      final effectiveObraId =
          ref.watch(effectiveLoteamentoObraIdProvider(scope)).value ??
          scope.loteamentoId;
      final om = ref
          .watch(
            currentPermissionsProvider((
              construtoraId: scope.construtoraId,
              obraId: effectiveObraId,
            )),
          )
          .value;
      return om != null && om.isActive && om.isAdmin;
    });

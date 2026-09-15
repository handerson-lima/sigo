import '../../../sync/read_cache.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';
import '../../authentication/data/user_repository.dart';
import '../../../core/contracts.dart';
import '../domain/obra_member.dart';

typedef ObraScope = ({String construtoraId, String obraId});
final construtoraPermissionProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, c) {
      final user = ref.watch(authStateChangesProvider).value;
      if (user == null) return Stream.value(null);
      return cachedDocument('construtoras/$c/construtora_members/${user.uid}');
    });
final currentPermissionsProvider = StreamProvider.autoDispose
    .family<ObraMember?, ObraScope>((ref, scope) {
      final user = ref.watch(authStateChangesProvider).value;
      if (user == null) return Stream.value(null);
      final dev = ref.watch(trustedDevProvider).value == true;
      final cm = ref
          .watch(construtoraPermissionProvider(scope.construtoraId))
          .value;
      if (dev ||
          cm?['isActive'] == true &&
              (cm?['isAdmin'] == true || cm?['isOwner'] == true)) {
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
      if (cm?['isActive'] != true) return Stream.value(null);
      return cachedDocument(
        'construtoras/${scope.construtoraId}/obras/${scope.obraId}/members/${user.uid}',
      ).map((doc) {
        if (doc?['isActive'] != true) return null;
        final data = doc!;
        data['modules'] = (data['modules'] as List? ?? [])
            .map((m) => normalizeModule(m as String))
            .toList();
        return ObraMember.fromJson(data);
      });
    });

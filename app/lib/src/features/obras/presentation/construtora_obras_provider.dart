import '../../authentication/data/user_repository.dart';
import '../../construtoras/domain/construtora_member.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';
import '../../construtoras/data/construtora_repository.dart';
import '../data/obra_repository.dart';
import '../domain/obra.dart';

final construtoraObrasProvider = FutureProvider.autoDispose
    .family<List<Obra>, String>((ref, construtoraId) async {
      final user = ref.watch(authStateChangesProvider).value;
      if (user == null) return [];

      final construtoraRepo = ref.watch(construtoraRepositoryProvider);
      final member = ref.watch(trustedDevProvider).value == true
          ? ConstrutoraMember(
              userId: user.uid,
              isAdmin: true,
              isActive: true,
              joinedAt: DateTime(2000),
            )
          : await construtoraRepo.getMember(construtoraId, user.uid);

      if (member == null || !member.isActive) return [];

      final obraRepo = ref.watch(obraRepositoryProvider);
      return obraRepo.getConstrutoraObras(construtoraId, user.uid, member);
    });

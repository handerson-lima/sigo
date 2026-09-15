import '../../authentication/data/user_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/construtora_repository.dart';
import '../domain/construtora.dart';

final userConstrutorasProvider = FutureProvider.autoDispose<List<Construtora>>((
  ref,
) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return [];

  final repo = ref.watch(construtoraRepositoryProvider);
  return repo.getUserConstrutoras(
    user.uid,
    dev: ref.watch(trustedDevProvider).value == true,
  );
});

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/features/users/data/repositories/user_repository.dart';

part 'username_provider.g.dart';

@Riverpod(keepAlive: true)
Future<String?> username(Ref ref, String userId) async {
  final normalized = userId.trim();
  if (normalized.isEmpty) return null;

  final repository = ref.watch(userRepositoryProvider);
  if (repository == null) return null;

  final result = await repository.getUsername(userId: normalized);
  return result.fold(
    (_) => null,
    (username) => username,
  );
}

import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'repos_provider.g.dart';

/// Provides the list of all repos.
@riverpod
class Repos extends _$Repos {
  @override
  Future<List<RepoListItem>> build() async {
    final repository = ref.watch(repoRepositoryProvider);
    if (repository == null) {
      return [];
    }

    final result = await repository.listRepos();

    return unwrapOrThrow(result);
  }

  /// Refreshes the repos list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
  }
}

/// Provides details for a specific repo.
@riverpod
Future<KomodoRepo?> repoDetail(Ref ref, String repoIdOrName) async {
  final repository = ref.watch(repoRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getRepo(repoIdOrName);

  return unwrapOrThrow(result);
}

/// Action state for repo operations.
@riverpod
class RepoActions extends _$RepoActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> clone(String repoIdOrName) =>
      _executeAction((repo) => repo.cloneRepo(repoIdOrName));

  Future<bool> pull(String repoIdOrName) =>
      _executeAction((repo) => repo.pullRepo(repoIdOrName));

  Future<bool> buildRepo(String repoIdOrName) =>
      _executeAction((repo) => repo.buildRepo(repoIdOrName));

  Future<KomodoRepo?> updateRepoConfig({
    required String repoId,
    required Map<String, dynamic> partialConfig,
  }) => _executeRequest(
    (repo) =>
        repo.updateRepoConfig(repoId: repoId, partialConfig: partialConfig),
  );

  Future<bool> _executeAction(
    Future<Either<Failure, void>> Function(RepoRepository repo) action,
  ) async {
    final repository = ref.read(repoRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    final result = await action(repository);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(reposProvider);
        return true;
      },
    );
  }

  Future<T?> _executeRequest<T>(
    Future<Either<Failure, T>> Function(RepoRepository repo) request,
  ) async {
    final repository = ref.read(repoRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    final result = await request(repository);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return null;
      },
      (value) {
        state = const AsyncValue.data(null);
        ref.invalidate(reposProvider);
        return value;
      },
    );
  }
}

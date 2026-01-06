import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/repo.dart';
import '../../data/repositories/repo_repository.dart';

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

    return result.fold(
      (failure) => throw Exception(failure.displayMessage),
      (repos) => repos,
    );
  }

  /// Refreshes the repos list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
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

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (repo) => repo,
  );
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
}


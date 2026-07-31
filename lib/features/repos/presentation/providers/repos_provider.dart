import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/shared/resources/providers/resource_action_executor.dart';
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
class RepoActions extends _$RepoActions
    with ResourceActionExecutor<RepoRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  RepoRepository? readRepository() => ref.read(repoRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(reposProvider);

  @override
  bool get isMounted => ref.mounted;

  Future<bool> clone(String repoIdOrName) =>
      executeAction((repo) => repo.cloneRepo(repoIdOrName));

  Future<bool> pull(String repoIdOrName) =>
      executeAction((repo) => repo.pullRepo(repoIdOrName));

  Future<bool> buildRepo(String repoIdOrName) =>
      executeAction((repo) => repo.buildRepo(repoIdOrName));

  Future<KomodoRepo?> updateRepoConfig({
    required String repoId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) =>
        repo.updateRepoConfig(repoId: repoId, partialConfig: partialConfig),
  );
}

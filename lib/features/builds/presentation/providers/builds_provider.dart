import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/shared/resources/providers/resource_action_executor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'builds_provider.g.dart';

/// Provides the list of all builds.
@riverpod
class Builds extends _$Builds {
  @override
  Future<List<BuildListItem>> build() async {
    final repository = ref.watch(buildRepositoryProvider);
    if (repository == null) {
      return [];
    }

    final result = await repository.listBuilds();

    return unwrapOrThrow(result);
  }

  /// Refreshes the builds list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
  }
}

/// Provides details for a specific build.
@riverpod
Future<KomodoBuild?> buildDetail(Ref ref, String buildIdOrName) async {
  final repository = ref.watch(buildRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getBuild(buildIdOrName);

  return unwrapOrThrow(result);
}

/// Action state for build operations.
@riverpod
class BuildActions extends _$BuildActions
    with ResourceActionExecutor<BuildRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  BuildRepository? readRepository() => ref.read(buildRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(buildsProvider);

  @override
  bool get isMounted => ref.mounted;

  Future<bool> run(String buildIdOrName) =>
      executeAction((repo) => repo.runBuild(buildIdOrName));

  Future<bool> cancel(String buildIdOrName) =>
      executeAction((repo) => repo.cancelBuild(buildIdOrName));

  Future<KomodoBuild?> updateBuildConfig({
    required String buildId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) => repo.updateBuildConfig(buildId: buildId, partialConfig: partialConfig),
  );
}

@riverpod
Future<String?> builderName(Ref ref, String builderIdOrName) async {
  final target = builderIdOrName.trim();
  if (target.isEmpty) {
    return null;
  }

  final repository = ref.watch(buildRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getBuilderName(target);
  return result.fold((_) => null, (name) => name);
}

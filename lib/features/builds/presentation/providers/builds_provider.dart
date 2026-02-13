import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
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
class BuildActions extends _$BuildActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> run(String buildIdOrName) =>
      _executeAction((repo) => repo.runBuild(buildIdOrName));

  Future<bool> cancel(String buildIdOrName) =>
      _executeAction((repo) => repo.cancelBuild(buildIdOrName));

  Future<KomodoBuild?> updateBuildConfig({
    required String buildId,
    required Map<String, dynamic> partialConfig,
  }) => _executeRequest(
    (repo) => repo.updateBuildConfig(buildId: buildId, partialConfig: partialConfig),
  );

  Future<bool> _executeAction(
    Future<Either<Failure, void>> Function(BuildRepository repo) action,
  ) async {
    final repository = ref.read(buildRepositoryProvider);
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
        ref.invalidate(buildsProvider);
        return true;
      },
    );
  }

  Future<T?> _executeRequest<T>(
    Future<Either<Failure, T>> Function(BuildRepository repo) request,
  ) async {
    final repository = ref.read(buildRepositoryProvider);
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
        ref.invalidate(buildsProvider);
        return value;
      },
    );
  }
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

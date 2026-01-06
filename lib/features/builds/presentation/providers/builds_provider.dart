import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/build.dart';
import '../../data/repositories/build_repository.dart';

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

    return result.fold(
      (failure) => throw Exception(failure.displayMessage),
      (builds) => builds,
    );
  }

  /// Refreshes the builds list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
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

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (build) => build,
  );
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
}


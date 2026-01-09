import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/data/repositories/builder_repository.dart';

part 'builders_provider.g.dart';

@riverpod
class Builders extends _$Builders {
  @override
  Future<List<BuilderListItem>> build() async {
    final repository = ref.watch(builderRepositoryProvider);
    if (repository == null) return [];

    final result = await repository.listBuilders();
    return result.fold(
      (failure) => throw Exception(failure.displayMessage),
      (items) => items..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

@riverpod
Future<Map<String, dynamic>?> builderJson(
  Ref ref,
  String builderIdOrName,
) async {
  final repository = ref.watch(builderRepositoryProvider);
  if (repository == null) return null;

  final result = await repository.getBuilderJson(
    builderIdOrName: builderIdOrName,
  );
  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (json) => json,
  );
}

@riverpod
class BuilderActions extends _$BuilderActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> rename({required String id, required String name}) async {
    return _execute((repo) => repo.renameBuilder(id: id, name: name));
  }

  Future<bool> delete({required String id}) async {
    return _execute((repo) => repo.deleteBuilder(id: id));
  }

  Future<bool> updateConfig({
    required String id,
    required Map<String, dynamic> config,
  }) async {
    return _execute((repo) => repo.updateBuilderConfig(id: id, config: config));
  }

  Future<bool> _execute(
    Future<Either<Failure, void>> Function(BuilderRepository repo) action,
  ) async {
    final repository = ref.read(builderRepositoryProvider);
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
        ref.invalidate(buildersProvider);
        return true;
      },
    );
  }
}

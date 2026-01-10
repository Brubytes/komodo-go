import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/data/repositories/tag_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tags_provider.g.dart';

@riverpod
class Tags extends _$Tags {
  @override
  Future<List<KomodoTag>> build() async {
    final repository = ref.watch(tagRepositoryProvider);
    if (repository == null) return [];

    final result = await repository.listTags();
    final tags = unwrapOrThrow(result);
    return tags..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

@riverpod
class TagActions extends _$TagActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> create({required String name, TagColor? color}) async {
    return _execute((repo) => repo.createTag(name: name, color: color));
  }

  Future<bool> delete(String id) async {
    return _execute((repo) => repo.deleteTag(id: id));
  }

  Future<bool> update({
    required KomodoTag original,
    required String name,
    required TagColor color,
  }) async {
    final repository = ref.read(tagRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    if (name.trim() != original.name.trim()) {
      final r = await repository.renameTag(id: original.id, name: name.trim());
      final ok = r.fold((failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      }, (_) => true);
      if (!ok) return false;
    }

    if (color != original.color) {
      final r = await repository.updateTagColor(
        tagIdOrName: original.id,
        color: color,
      );
      return r.fold(
        (failure) {
          state = AsyncValue.error(failure.displayMessage, StackTrace.current);
          return false;
        },
        (_) {
          state = const AsyncValue.data(null);
          ref.invalidate(tagsProvider);
          return true;
        },
      );
    }

    state = const AsyncValue.data(null);
    ref.invalidate(tagsProvider);
    return true;
  }

  Future<bool> _execute(
    Future<Either<Failure, KomodoTag>> Function(TagRepository repo) action,
  ) async {
    final repository = ref.read(tagRepositoryProvider);
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
        ref.invalidate(tagsProvider);
        return true;
      },
    );
  }
}

import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';
import 'package:komodo_go/shared/resources/providers/resource_action_executor.dart';
import 'package:komodo_go/shared/resources/providers/resource_activity_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'syncs_provider.g.dart';

/// Provides the list of all syncs.
@riverpod
class Syncs extends _$Syncs {
  @override
  Future<List<ResourceSyncListItem>> build() async {
    ref.watch(resourceActivityProvider);
    final repository = ref.watch(syncRepositoryProvider);
    if (repository == null) {
      return [];
    }

    final result = await repository.listSyncs();

    return unwrapOrThrow(result);
  }

  /// Refreshes the syncs list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
  }
}

/// Provides details for a specific sync.
@riverpod
Future<KomodoResourceSync?> syncDetail(Ref ref, String syncIdOrName) async {
  ref.watch(resourceActivityProvider);
  final repository = ref.watch(syncRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getSync(syncIdOrName);

  return unwrapOrThrow(result);
}

/// Action state for sync operations.
@riverpod
class SyncActions extends _$SyncActions
    with ResourceActionExecutor<SyncRepository> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  SyncRepository? readRepository() => ref.read(syncRepositoryProvider);

  @override
  void invalidateList() => ref.invalidate(syncsProvider);

  @override
  void markResourceActivity() => ref.markResourceActivity();

  @override
  bool get isMounted => ref.mounted;

  Future<bool> run(String syncIdOrName) =>
      executeAction((repo) => repo.runSync(syncIdOrName));

  Future<bool> runSelected(
    String syncIdOrName,
    List<ResourceSyncDiff> diffs,
  ) => executeAction((repo) => repo.runSelected(syncIdOrName, diffs));

  Future<KomodoResourceSync?> refreshPending(String syncIdOrName) =>
      executeRequest((repo) => repo.refreshPending(syncIdOrName));

  Future<bool> commit(String syncIdOrName) =>
      executeAction((repo) => repo.commitSync(syncIdOrName));

  Future<bool> writeFileContents({
    required String syncIdOrName,
    required String resourcePath,
    required String filePath,
    required String contents,
  }) => executeAction(
    (repo) => repo.writeFileContents(
      syncIdOrName: syncIdOrName,
      resourcePath: resourcePath,
      filePath: filePath,
      contents: contents,
    ),
  );

  Future<String?> exportResourcesToToml(
    List<SyncResourceTarget> targets,
  ) => executeRequest((repo) => repo.exportResourcesToToml(targets));

  Future<KomodoResourceSync?> updateSyncConfig({
    required String syncId,
    required Map<String, dynamic> partialConfig,
  }) => executeRequest(
    (repo) =>
        repo.updateSyncConfig(syncId: syncId, partialConfig: partialConfig),
  );
}

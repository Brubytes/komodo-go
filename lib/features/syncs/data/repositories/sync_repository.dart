import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/paginated_read.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/utils/debug_log.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_repository.g.dart';

/// Repository for resource sync-related operations.
class SyncRepository {
  SyncRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all syncs.
  Future<Either<Failure, List<ResourceSyncListItem>>> listSyncs([
    ResourceListOptions options = const ResourceListOptions(),
  ]) async {
    return apiCall(
      () async {
        final syncsJson = await readAllPages(
          _client,
          type: 'ListResourceSyncs',
          params: options.params(
            specific: <String, dynamic>{'repos': <String>[]},
          ),
          pageSize: options.pageSize,
        );
        return syncsJson
            .map(
              (json) =>
                  ResourceSyncListItem.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      },
      onUnknown: (error) {
        debugLog('Error parsing syncs', name: 'API', error: error);
        return Failure.unknown(message: error.toString());
      },
    );
  }

  /// Gets a specific sync by ID or name.
  Future<Either<Failure, KomodoResourceSync>> getSync(
    String syncIdOrName,
  ) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(type: 'GetResourceSync', params: {'sync': syncIdOrName}),
        );
        return KomodoResourceSync.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Sync not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Runs the target sync.
  Future<Either<Failure, void>> runSync(
    String syncIdOrName, {
    String? resourceType,
    List<String>? resources,
  }) async {
    return apiCall(
      () async {
        await _client.execute(
          RpcRequest(
            type: 'RunSync',
            params: {
              'sync': syncIdOrName,
              'resource_type': resourceType,
              'resources': resources,
            },
          ),
        );
        return;
      },
    );
  }

  Future<Either<Failure, void>> runSelected(
    String syncIdOrName,
    List<ResourceSyncDiff> diffs,
  ) {
    return apiCall(() async {
      final grouped = <String, List<String>>{};
      for (final diff in diffs) {
        final resource = diff.name.trim();
        if (resource.isEmpty) continue;
        grouped.putIfAbsent(diff.target.type, () => <String>[]).add(resource);
      }
      for (final entry in grouped.entries) {
        await _client.execute(
          RpcRequest(
            type: 'RunSync',
            params: <String, dynamic>{
              'sync': syncIdOrName,
              'resource_type': entry.key,
              'resources': entry.value,
            },
          ),
        );
      }
    });
  }

  Future<Either<Failure, KomodoResourceSync>> refreshPending(
    String syncIdOrName,
  ) {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'RefreshResourceSyncPending',
          params: <String, dynamic>{'sync': syncIdOrName},
        ),
      );
      return KomodoResourceSync.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, String?>> commitSync(String syncIdOrName) {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'CommitSync',
          params: <String, dynamic>{'sync': syncIdOrName},
        ),
      );
      return _updateId(response);
    });
  }

  Future<Either<Failure, String?>> writeFileContents({
    required String syncIdOrName,
    required String resourcePath,
    required String filePath,
    required String contents,
  }) {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'WriteSyncFileContents',
          params: <String, dynamic>{
            'sync': syncIdOrName,
            'resource_path': resourcePath,
            'file_path': filePath,
            'contents': contents,
          },
        ),
      );
      return _updateId(response);
    });
  }

  Future<Either<Failure, String>> exportResourcesToToml(
    List<SyncResourceTarget> targets,
  ) {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(
          type: 'ExportResourcesToToml',
          params: <String, dynamic>{
            'targets': [
              for (final target in targets)
                _client.capabilities.encodeResourceTarget(
                  type: ResourceKindX.fromVariant(target.type).variant,
                  id: target.id,
                ),
            ],
            'user_groups': <String>[],
            'include_variables': false,
          },
        ),
      );
      if (response is! Map || response['toml'] is! String) {
        throw const FormatException('Export response is missing TOML.');
      }
      return response['toml'] as String;
    });
  }

  /// Updates a resource sync configuration and returns the updated sync.
  ///
  /// Uses the `/write` module `UpdateResourceSync` RPC.
  ///
  /// Note: Only fields included in [partialConfig] will be updated.
  Future<Either<Failure, KomodoResourceSync>> updateSyncConfig({
    required String syncId,
    required Map<String, dynamic> partialConfig,
  }) async {
    return apiCall(
      () async {
        final response = await _client.write(
          RpcRequest(
            type: 'UpdateResourceSync',
            params: <String, dynamic>{
              'id': syncId,
              'config': partialConfig,
            },
          ),
        );

        return KomodoResourceSync.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Sync not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }
}

String? _updateId(Object? response) {
  if (response is! Map) return null;
  final raw = response['id'] ?? response['_id'];
  final id = raw is Map ? raw[r'$oid'] : raw;
  return id is String && id.isNotEmpty ? id : null;
}

@riverpod
SyncRepository? syncRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return SyncRepository(client);
}

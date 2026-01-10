import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_call.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/query_templates.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/utils/debug_log.dart';
import '../models/sync.dart';

part 'sync_repository.g.dart';

/// Repository for resource sync-related operations.
class SyncRepository {
  SyncRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all syncs.
  Future<Either<Failure, List<ResourceSyncListItem>>> listSyncs() async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListResourceSyncs',
            params: <String, dynamic>{
              'query': emptyQuery(
                specific: <String, dynamic>{'repos': <String>[]},
              ),
            },
          ),
        );

        final syncsJson = response as List<dynamic>? ?? [];
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
        return null;
      },
    );
  }
}

@riverpod
SyncRepository? syncRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return SyncRepository(client);
}

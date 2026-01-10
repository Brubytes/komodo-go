import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/utils/debug_log.dart';
import '../models/sync.dart';

part 'sync_repository.g.dart';

/// Repository for resource sync-related operations.
class SyncRepository {
  SyncRepository(this._client);

  final KomodoApiClient _client;

  static const Map<String, dynamic> _emptySyncQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{'repos': <String>[]},
  };

  /// Lists all syncs.
  Future<Either<Failure, List<ResourceSyncListItem>>> listSyncs() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListResourceSyncs',
          params: <String, dynamic>{'query': _emptySyncQuery},
        ),
      );

      final syncsJson = response as List<dynamic>? ?? [];
      final syncs = syncsJson
          .map(
            (json) =>
                ResourceSyncListItem.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      return Right(syncs);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e, stackTrace) {
      debugLog(
        'Error parsing syncs',
        name: 'API',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets a specific sync by ID or name.
  Future<Either<Failure, KomodoResourceSync>> getSync(
    String syncIdOrName,
  ) async {
    try {
      final response = await _client.read(
        RpcRequest(type: 'GetResourceSync', params: {'sync': syncIdOrName}),
      );

      return Right(
        KomodoResourceSync.fromJson(response as Map<String, dynamic>),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      if (e.isNotFound) {
        return const Left(Failure.server(message: 'Sync not found'));
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Runs the target sync.
  Future<Either<Failure, void>> runSync(
    String syncIdOrName, {
    String? resourceType,
    List<String>? resources,
  }) async {
    try {
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
      return const Right(null);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
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

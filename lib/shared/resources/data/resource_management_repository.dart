import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'resource_management_repository.g.dart';

class ResourceManagementRepository {
  ResourceManagementRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, void>> updateMetadata({
    required ResourceMetadata metadata,
    required ResourceMetadataDraft draft,
  }) {
    return apiCall(() async {
      await _client.write(
        RpcRequest(
          type: 'UpdateResourceMeta',
          params: <String, dynamic>{
            'target': <String, dynamic>{
              ..._client.capabilities.encodeResourceTarget(
                type: metadata.kind.variant,
                id: metadata.id,
              ),
            },
            'description': draft.description,
            'template': draft.template,
            'tags': draft.tags,
          },
        ),
      );
    });
  }

  Future<Either<Failure, void>> copy({
    required ResourceKind kind,
    required String id,
    required String name,
  }) {
    return _writeLifecycle(
      verb: 'Copy',
      kind: kind,
      params: <String, dynamic>{'id': id, 'name': name},
    );
  }

  Future<Either<Failure, void>> rename({
    required ResourceKind kind,
    required String id,
    required String name,
  }) {
    return _writeLifecycle(
      verb: 'Rename',
      kind: kind,
      params: <String, dynamic>{'id': id, 'name': name},
    );
  }

  Future<Either<Failure, void>> delete({
    required ResourceKind kind,
    required String id,
  }) {
    return _writeLifecycle(
      verb: 'Delete',
      kind: kind,
      params: <String, dynamic>{'id': id},
    );
  }

  Future<Either<Failure, void>> _writeLifecycle({
    required String verb,
    required ResourceKind kind,
    required Map<String, dynamic> params,
  }) {
    return apiCall(() async {
      await _client.write(
        RpcRequest(type: '$verb${kind.variant}', params: params),
      );
    });
  }
}

@riverpod
ResourceManagementRepository? resourceManagementRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return ResourceManagementRepository(client);
}

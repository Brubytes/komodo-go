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

  Future<Either<Failure, CreatedResource>> create({
    required ResourceKind kind,
    required String name,
    required Map<String, dynamic> config,
  }) {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'Create${kind.variant}',
          params: <String, dynamic>{'name': name, 'config': config},
        ),
      );
      return CreatedResource.fromResponse(response, fallbackName: name);
    });
  }

  Future<Either<Failure, CreatedResource>> copyAndReturn({
    required ResourceKind kind,
    required String id,
    required String name,
  }) {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'Copy${kind.variant}',
          params: <String, dynamic>{'id': id, 'name': name},
        ),
      );
      return CreatedResource.fromResponse(response, fallbackName: name);
    });
  }

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

class CreatedResource {
  const CreatedResource({required this.id, required this.name});

  factory CreatedResource.fromResponse(
    Object? response, {
    required String fallbackName,
  }) {
    if (response is! Map) {
      throw const FormatException('Resource response is not an object.');
    }
    final rawId = response['id'] ?? response['_id'];
    final id = rawId is Map ? rawId[r'$oid'] : rawId;
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Resource response is missing its id.');
    }
    final rawName = response['name'];
    return CreatedResource(
      id: id,
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName
          : fallbackName,
    );
  }

  final String id;
  final String name;
}

@riverpod
ResourceManagementRepository? resourceManagementRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return ResourceManagementRepository(client);
}

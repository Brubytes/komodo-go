import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_batch.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'resource_batch_repository.g.dart';

class ResourceBatchRepository {
  ResourceBatchRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, List<ResourceBatchResult>>> execute({
    required ResourceKind kind,
    required ResourceBatchAction action,
    required List<ResourceBatchItem> items,
  }) {
    return apiCall(() async {
      if (items.isEmpty) return const <ResourceBatchResult>[];
      final batchRpc = _nativeBatchRpc(kind, action);
      if (batchRpc != null) {
        final response = await _client.execute(
          RpcRequest(
            type: batchRpc,
            params: <String, dynamic>{
              'pattern': items.map((item) => item.name).join(', '),
            },
          ),
        );
        return _parseBatchResponse(response, items);
      }

      return Future.wait(
        items.map((item) => _executeOne(kind, action, item)),
      );
    });
  }

  Future<ResourceBatchResult> _executeOne(
    ResourceKind kind,
    ResourceBatchAction action,
    ResourceBatchItem item,
  ) async {
    try {
      final request = _individualRequest(kind, action, item.id);
      final response = await _client.execute(request);
      return ResourceBatchResult(
        item: item,
        success: true,
        updateId: _readUpdateId(response),
      );
    } on Object catch (error) {
      return ResourceBatchResult(
        item: item,
        success: false,
        error: error.toString(),
      );
    }
  }

  static String? _nativeBatchRpc(
    ResourceKind kind,
    ResourceBatchAction action,
  ) => switch ((kind, action)) {
    (ResourceKind.stacks, ResourceBatchAction.deploy) => 'BatchDeployStack',
    (ResourceKind.stacks, ResourceBatchAction.pull) => 'BatchPullStack',
    (ResourceKind.stacks, ResourceBatchAction.destroy) => 'BatchDestroyStack',
    (ResourceKind.deployments, ResourceBatchAction.deploy) => 'BatchDeploy',
    (ResourceKind.deployments, ResourceBatchAction.destroy) =>
      'BatchDestroyDeployment',
    (ResourceKind.builds, ResourceBatchAction.run) => 'BatchRunBuild',
    (ResourceKind.repos, ResourceBatchAction.pull) => 'BatchPullRepo',
    (ResourceKind.repos, ResourceBatchAction.run) => 'BatchBuildRepo',
    (ResourceKind.actions, ResourceBatchAction.run) => 'BatchRunAction',
    (ResourceKind.procedures, ResourceBatchAction.run) => 'BatchRunProcedure',
    _ => null,
  };

  RpcRequest<dynamic> _individualRequest(
    ResourceKind kind,
    ResourceBatchAction action,
    String id,
  ) {
    final (type, key) = switch ((kind, action)) {
      (ResourceKind.stacks, ResourceBatchAction.start) => (
        'StartStack',
        'stack',
      ),
      (ResourceKind.stacks, ResourceBatchAction.stop) => ('StopStack', 'stack'),
      (ResourceKind.stacks, ResourceBatchAction.restart) => (
        'RestartStack',
        'stack',
      ),
      (ResourceKind.deployments, ResourceBatchAction.pull) => (
        'PullDeployment',
        'deployment',
      ),
      (ResourceKind.deployments, ResourceBatchAction.start) => (
        'StartDeployment',
        'deployment',
      ),
      (ResourceKind.deployments, ResourceBatchAction.stop) => (
        'StopDeployment',
        'deployment',
      ),
      (ResourceKind.deployments, ResourceBatchAction.restart) => (
        'RestartDeployment',
        'deployment',
      ),
      (ResourceKind.builds, ResourceBatchAction.cancel) => (
        'CancelBuild',
        'build',
      ),
      (ResourceKind.repos, ResourceBatchAction.cancel) => (
        'CancelRepoBuild',
        'repo',
      ),
      (ResourceKind.actions, ResourceBatchAction.cancel) => (
        'CancelAction',
        'action',
      ),
      (ResourceKind.procedures, ResourceBatchAction.cancel) => (
        'CancelProcedure',
        'procedure',
      ),
      _ => throw ArgumentError('Unsupported $action for $kind.'),
    };
    return RpcRequest(type: type, params: <String, dynamic>{key: id});
  }

  static List<ResourceBatchResult> _parseBatchResponse(
    Object? response,
    List<ResourceBatchItem> requested,
  ) {
    if (response is! List) {
      throw const FormatException('Batch response is not a list.');
    }
    final byName = {for (final item in requested) item.name: item};
    final byId = {for (final item in requested) item.id: item};
    final remaining = [...requested];
    final results = <ResourceBatchResult>[];
    for (final raw in response) {
      if (raw is! Map) {
        throw const FormatException('Batch result is not an object.');
      }
      final status = raw['status']?.toString().toLowerCase();
      final data = raw['data'];
      if (status == 'ok') {
        final name = data is Map ? _readResourceName(data) : null;
        final id = data is Map ? _readResourceId(data) : null;
        final item = _takeMatching(remaining, byId[id] ?? byName[name]);
        results.add(
          ResourceBatchResult(
            item: item,
            success: true,
            updateId: _readUpdateId(data),
          ),
        );
      } else {
        final errorMap = data is Map ? data : raw;
        final name = errorMap['name']?.toString();
        final item = _takeMatching(remaining, byName[name]);
        results.add(
          ResourceBatchResult(
            item: item,
            success: false,
            error: _readError(errorMap['error']),
          ),
        );
      }
    }
    return results;
  }

  static ResourceBatchItem _takeMatching(
    List<ResourceBatchItem> remaining,
    ResourceBatchItem? match,
  ) {
    if (match != null && remaining.remove(match)) return match;
    if (remaining.isEmpty) {
      return const ResourceBatchItem(id: '', name: 'Unknown resource');
    }
    return remaining.removeAt(0);
  }

  static String? _readResourceName(Map<dynamic, dynamic> update) {
    final target = update['target'];
    if (target is Map && target['name'] is String) {
      return target['name'] as String;
    }
    return update['name'] as String?;
  }

  static String? _readResourceId(Map<dynamic, dynamic> update) {
    final target = update['target'];
    if (target is Map) {
      final value = target['id'];
      if (value is String) return value;
      if (target.length == 1 && target.values.first is String) {
        return target.values.first as String;
      }
    }
    return null;
  }

  static String? _readUpdateId(Object? response) {
    if (response is! Map) return null;
    final value = response['id'] ?? response['_id'];
    final id = value is Map ? value[r'$oid'] : value;
    return id is String && id.isNotEmpty ? id : null;
  }

  static String _readError(Object? error) {
    if (error is Map) {
      return (error['message'] ?? error['error'] ?? error).toString();
    }
    return error?.toString() ?? 'Unknown error';
  }
}

@riverpod
ResourceBatchRepository? resourceBatchRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return client == null ? null : ResourceBatchRepository(client);
}

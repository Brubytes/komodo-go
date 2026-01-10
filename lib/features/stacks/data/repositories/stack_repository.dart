import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/query_templates.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/utils/debug_log.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stack_repository.g.dart';

/// Repository for stack-related operations.
class StackRepository {
  StackRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all stacks.
  Future<Either<Failure, List<StackListItem>>> listStacks() async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListStacks',
            params: <String, dynamic>{
              'query': emptyQuery(
                specific: <String, dynamic>{
                  'server_ids': <String>[],
                  'linked_repos': <String>[],
                  'repos': <String>[],
                  'update_available': false,
                },
              ),
            },
          ),
        );

        final stacksJson = response as List<dynamic>? ?? [];
        return stacksJson
            .map((json) => StackListItem.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      onUnknown: (error) {
        debugLog('Error parsing stacks', name: 'API', error: error);
        return Failure.unknown(message: error.toString());
      },
    );
  }

  /// Gets a specific stack by ID or name.
  Future<Either<Failure, KomodoStack>> getStack(String stackIdOrName) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(type: 'GetStack', params: {'stack': stackIdOrName}),
        );
        return KomodoStack.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Stack not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Lists services (containers) for a stack.
  Future<Either<Failure, List<StackService>>> listStackServices(
    String stackIdOrName,
  ) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListStackServices',
            params: {'stack': stackIdOrName},
          ),
        );

        final servicesJson = response as List<dynamic>? ?? [];
        return servicesJson
            .map((json) => StackService.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// Retrieves recent logs for a stack.
  Future<Either<Failure, StackLog>> getStackLog({
    required String stackIdOrName,
    List<String> services = const [],
    int tail = 200,
    bool timestamps = true,
  }) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'GetStackLog',
            params: <String, dynamic>{
              'stack': stackIdOrName,
              'services': services,
              'tail': tail,
              'timestamps': timestamps,
            },
          ),
        );

        return StackLog.fromJson(response as Map<String, dynamic>);
      },
    );
  }

  Future<Either<Failure, void>> deployStack(
    String stackIdOrName, {
    List<String> services = const [],
    int? stopTime,
  }) async {
    return _executeAction('DeployStack', <String, dynamic>{
      'stack': stackIdOrName,
      'services': services,
      'stop_time': stopTime,
    });
  }

  Future<Either<Failure, void>> pullStackImages(
    String stackIdOrName, {
    List<String> services = const [],
  }) async {
    return _executeAction('PullStack', <String, dynamic>{
      'stack': stackIdOrName,
      'services': services,
    });
  }

  Future<Either<Failure, void>> restartStack(
    String stackIdOrName, {
    List<String> services = const [],
  }) async {
    return _executeAction('RestartStack', <String, dynamic>{
      'stack': stackIdOrName,
      'services': services,
    });
  }

  Future<Either<Failure, void>> pauseStack(
    String stackIdOrName, {
    List<String> services = const [],
  }) async {
    return _executeAction('PauseStack', <String, dynamic>{
      'stack': stackIdOrName,
      'services': services,
    });
  }

  Future<Either<Failure, void>> startStack(
    String stackIdOrName, {
    List<String> services = const [],
  }) async {
    return _executeAction('StartStack', <String, dynamic>{
      'stack': stackIdOrName,
      'services': services,
    });
  }

  Future<Either<Failure, void>> stopStack(
    String stackIdOrName, {
    List<String> services = const [],
    int? stopTime,
  }) async {
    return _executeAction('StopStack', <String, dynamic>{
      'stack': stackIdOrName,
      'services': services,
      'stop_time': stopTime,
    });
  }

  Future<Either<Failure, void>> destroyStack(
    String stackIdOrName, {
    List<String> services = const [],
  }) async {
    return _executeAction('DestroyStack', <String, dynamic>{
      'stack': stackIdOrName,
      'services': services,
    });
  }

  Future<Either<Failure, void>> _executeAction(
    String actionType,
    Map<String, dynamic> params,
  ) async {
    return apiCall(
      () async {
        await _client.execute(RpcRequest(type: actionType, params: params));
        return;
      },
    );
  }
}

@riverpod
StackRepository? stackRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return StackRepository(client);
}

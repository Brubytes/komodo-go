import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
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

  static const Map<String, dynamic> _emptyStackQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{
      'server_ids': <String>[],
      'linked_repos': <String>[],
      'repos': <String>[],
      'update_available': false,
    },
  };

  /// Lists all stacks.
  Future<Either<Failure, List<StackListItem>>> listStacks() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListStacks',
          params: <String, dynamic>{'query': _emptyStackQuery},
        ),
      );

      final stacksJson = response as List<dynamic>? ?? [];
      final stacks = stacksJson
          .map((json) => StackListItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(stacks);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e, stackTrace) {
      debugLog(
        'Error parsing stacks',
        name: 'API',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets a specific stack by ID or name.
  Future<Either<Failure, KomodoStack>> getStack(String stackIdOrName) async {
    try {
      final response = await _client.read(
        RpcRequest(type: 'GetStack', params: {'stack': stackIdOrName}),
      );

      return Right(KomodoStack.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      if (e.isNotFound) {
        return const Left(Failure.server(message: 'Stack not found'));
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Lists services (containers) for a stack.
  Future<Either<Failure, List<StackService>>> listStackServices(
    String stackIdOrName,
  ) async {
    try {
      final response = await _client.read(
        RpcRequest(type: 'ListStackServices', params: {'stack': stackIdOrName}),
      );

      final servicesJson = response as List<dynamic>? ?? [];
      final services = servicesJson
          .map((json) => StackService.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(services);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Retrieves recent logs for a stack.
  Future<Either<Failure, StackLog>> getStackLog({
    required String stackIdOrName,
    List<String> services = const [],
    int tail = 200,
    bool timestamps = true,
  }) async {
    try {
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

      return Right(StackLog.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
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
    try {
      await _client.execute(RpcRequest(type: actionType, params: params));
      return const Right(null);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
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

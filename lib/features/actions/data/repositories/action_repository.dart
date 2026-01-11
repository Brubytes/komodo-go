import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/query_templates.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/utils/debug_log.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'action_repository.g.dart';

/// Repository for action-related operations.
class ActionRepository {
  ActionRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all actions.
  Future<Either<Failure, List<ActionListItem>>> listActions() async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListActions',
            params: <String, dynamic>{'query': emptyQuery()},
          ),
        );
        final actionsJson = response as List<dynamic>? ?? [];
        return actionsJson
            .map(
              (json) => ActionListItem.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      },
      onUnknown: (error) {
        debugLog('Error parsing actions', name: 'API', error: error);
        return Failure.unknown(message: error.toString());
      },
    );
  }

  /// Gets a specific action by ID or name.
  Future<Either<Failure, KomodoAction>> getAction(String actionIdOrName) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(type: 'GetAction', params: {'action': actionIdOrName}),
        );
        return KomodoAction.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Action not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Runs the target action.
  Future<Either<Failure, void>> runAction(
    String actionIdOrName, {
    Map<String, dynamic>? args,
  }) async {
    return apiCall(() async {
      await _client.execute(
        RpcRequest(
          type: 'RunAction',
          params: {'action': actionIdOrName, 'args': args},
        ),
      );
      return;
    });
  }

  /// Updates an action configuration and returns the updated action.
  ///
  /// Uses the `/write` module `UpdateAction` RPC.
  ///
  /// Note: Only fields included in [partialConfig] will be updated.
  Future<Either<Failure, KomodoAction>> updateActionConfig({
    required String actionId,
    required Map<String, dynamic> partialConfig,
  }) async {
    return apiCall(
      () async {
        final response = await _client.write(
          RpcRequest(
            type: 'UpdateAction',
            params: <String, dynamic>{'id': actionId, 'config': partialConfig},
          ),
        );

        return KomodoAction.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Action not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }
}

@riverpod
ActionRepository? actionRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return ActionRepository(client);
}

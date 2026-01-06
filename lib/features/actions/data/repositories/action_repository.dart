import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../models/action.dart';

part 'action_repository.g.dart';

/// Repository for action-related operations.
class ActionRepository {
  ActionRepository(this._client);

  final KomodoApiClient _client;

  static const Map<String, dynamic> _emptyActionQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{},
  };

  /// Lists all actions.
  Future<Either<Failure, List<ActionListItem>>> listActions() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListActions',
          params: <String, dynamic>{'query': _emptyActionQuery},
        ),
      );

      final actionsJson = response as List<dynamic>? ?? [];
      final actions = actionsJson
          .map((json) => ActionListItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(actions);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error parsing actions: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets a specific action by ID or name.
  Future<Either<Failure, KomodoAction>> getAction(String actionIdOrName) async {
    try {
      final response = await _client.read(
        RpcRequest(type: 'GetAction', params: {'action': actionIdOrName}),
      );

      return Right(KomodoAction.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      if (e.isNotFound) {
        return const Left(Failure.server(message: 'Action not found'));
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Runs the target action.
  Future<Either<Failure, void>> runAction(
    String actionIdOrName, {
    Map<String, dynamic>? args,
  }) async {
    try {
      await _client.execute(
        RpcRequest(
          type: 'RunAction',
          params: {'action': actionIdOrName, 'args': args},
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
ActionRepository? actionRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return ActionRepository(client);
}

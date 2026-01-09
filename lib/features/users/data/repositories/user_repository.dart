import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';

part 'user_repository.g.dart';

class UserRepository {
  UserRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, String>> getUsername({required String userId}) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'GetUsername',
          params: <String, dynamic>{'user_id': userId},
        ),
      );

      final json = response as Map<String, dynamic>;
      final username = (json['username'] as String?)?.trim() ?? '';
      if (username.isEmpty) {
        return const Left(Failure.server(message: 'User not found'));
      }
      return Right(username);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}

@riverpod
UserRepository? userRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return UserRepository(client);
}


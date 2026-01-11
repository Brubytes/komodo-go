import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_repository.g.dart';

class UserRepository {
  UserRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, String>> getUsername({required String userId}) async {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(
          type: 'GetUsername',
          params: <String, dynamic>{'user_id': userId},
        ),
      );

      final json = response as Map<String, dynamic>;
      final username = (json['username'] as String?)?.trim() ?? '';
      if (username.isEmpty) {
        throw const ApiException(message: 'User not found', statusCode: 404);
      }
      return username;
    });
  }
}

@riverpod
UserRepository? userRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return UserRepository(client);
}

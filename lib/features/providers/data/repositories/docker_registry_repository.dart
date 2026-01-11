import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'docker_registry_repository.g.dart';

class DockerRegistryRepository {
  DockerRegistryRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, List<DockerRegistryAccount>>> listAccounts({
    String? domain,
    String? username,
  }) async {
    return apiCall(() async {
      final params = <String, dynamic>{
        if (domain != null && domain.trim().isNotEmpty) 'domain': domain.trim(),
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim(),
      };

      final response = await _client.read(
        RpcRequest(type: 'ListDockerRegistryAccounts', params: params),
      );

      final itemsJson = response as List<dynamic>? ?? [];
      return itemsJson
          .whereType<Map>()
          .map(
            (json) =>
                DockerRegistryAccount.fromJson(json.cast<String, dynamic>()),
          )
          .toList();
    });
  }

  Future<Either<Failure, DockerRegistryAccount>> createAccount({
    required String domain,
    required String username,
    required String token,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'CreateDockerRegistryAccount',
          params: <String, dynamic>{
            'account': <String, dynamic>{
              'domain': domain.trim(),
              'username': username.trim(),
              'token': token,
            },
          },
        ),
      );

      return DockerRegistryAccount.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, DockerRegistryAccount>> updateAccount({
    required String id,
    String? domain,
    String? username,
    String? token,
  }) async {
    return apiCall(() async {
      final account = <String, dynamic>{
        if (domain != null && domain.trim().isNotEmpty) 'domain': domain.trim(),
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim(),
        if (token != null && token.trim().isNotEmpty) 'token': token.trim(),
      };

      final response = await _client.write(
        RpcRequest(
          type: 'UpdateDockerRegistryAccount',
          params: <String, dynamic>{'id': id, 'account': account},
        ),
      );

      return DockerRegistryAccount.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, DockerRegistryAccount>> deleteAccount({
    required String id,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'DeleteDockerRegistryAccount',
          params: <String, dynamic>{'id': id},
        ),
      );

      return DockerRegistryAccount.fromJson(response as Map<String, dynamic>);
    });
  }
}

@riverpod
DockerRegistryRepository? dockerRegistryRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return DockerRegistryRepository(client);
}

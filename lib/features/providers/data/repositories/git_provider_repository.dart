import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'git_provider_repository.g.dart';

class GitProviderRepository {
  GitProviderRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, List<GitProviderAccount>>> listAccounts({
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
        RpcRequest(type: 'ListGitProviderAccounts', params: params),
      );

      final itemsJson = response as List<dynamic>? ?? [];
      return itemsJson
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (json) => GitProviderAccount.fromJson(json.cast<String, dynamic>()),
          )
          .toList();
    });
  }

  Future<Either<Failure, GitProviderAccount>> createAccount({
    required String domain,
    required String username,
    required String token,
    required bool https,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'CreateGitProviderAccount',
          params: <String, dynamic>{
            'account': <String, dynamic>{
              'domain': domain.trim(),
              'username': username.trim(),
              'token': token,
              'https': https,
            },
          },
        ),
      );

      return GitProviderAccount.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, GitProviderAccount>> updateAccount({
    required String id,
    String? domain,
    String? username,
    String? token,
    bool? https,
  }) async {
    return apiCall(() async {
      final account = <String, dynamic>{
        if (domain != null && domain.trim().isNotEmpty) 'domain': domain.trim(),
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim(),
        if (token != null && token.trim().isNotEmpty) 'token': token.trim(),
        'https': ?https,
      };

      final response = await _client.write(
        RpcRequest(
          type: 'UpdateGitProviderAccount',
          params: <String, dynamic>{'id': id, 'account': account},
        ),
      );

      return GitProviderAccount.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, GitProviderAccount>> deleteAccount({
    required String id,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'DeleteGitProviderAccount',
          params: <String, dynamic>{'id': id},
        ),
      );

      return GitProviderAccount.fromJson(response as Map<String, dynamic>);
    });
  }
}

@riverpod
GitProviderRepository? gitProviderRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return GitProviderRepository(client);
}

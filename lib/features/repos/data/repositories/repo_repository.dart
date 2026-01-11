import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/query_templates.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/utils/debug_log.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'repo_repository.g.dart';

/// Repository for repo-related operations.
class RepoRepository {
  RepoRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all repos.
  Future<Either<Failure, List<RepoListItem>>> listRepos() async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListRepos',
            params: <String, dynamic>{
              'query': emptyQuery(specific: <String, dynamic>{'repos': <String>[]}),
            },
          ),
        );

        final reposJson = response as List<dynamic>? ?? [];
        return reposJson
            .map((json) => RepoListItem.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      onUnknown: (error) {
        debugLog('Error parsing repos', name: 'API', error: error);
        return Failure.unknown(message: error.toString());
      },
    );
  }

  /// Gets a specific repo by ID or name.
  Future<Either<Failure, KomodoRepo>> getRepo(String repoIdOrName) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(type: 'GetRepo', params: {'repo': repoIdOrName}),
        );

        return KomodoRepo.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Repo not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Clones the target repo on its server.
  Future<Either<Failure, void>> cloneRepo(String repoIdOrName) async {
    return _executeAction('CloneRepo', {'repo': repoIdOrName});
  }

  /// Pulls the target repo on its server.
  Future<Either<Failure, void>> pullRepo(String repoIdOrName) async {
    return _executeAction('PullRepo', {'repo': repoIdOrName});
  }

  /// Builds the target repo using its attached builder.
  Future<Either<Failure, void>> buildRepo(String repoIdOrName) async {
    return _executeAction('BuildRepo', {'repo': repoIdOrName});
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
RepoRepository? repoRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return RepoRepository(client);
}

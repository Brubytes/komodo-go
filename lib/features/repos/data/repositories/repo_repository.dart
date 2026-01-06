import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../models/repo.dart';

part 'repo_repository.g.dart';

/// Repository for repo-related operations.
class RepoRepository {
  RepoRepository(this._client);

  final KomodoApiClient _client;

  static const Map<String, dynamic> _emptyRepoQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{'repos': <String>[]},
  };

  /// Lists all repos.
  Future<Either<Failure, List<RepoListItem>>> listRepos() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListRepos',
          params: <String, dynamic>{'query': _emptyRepoQuery},
        ),
      );

      final reposJson = response as List<dynamic>? ?? [];
      final repos = reposJson
          .map((json) => RepoListItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(repos);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error parsing repos: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets a specific repo by ID or name.
  Future<Either<Failure, KomodoRepo>> getRepo(String repoIdOrName) async {
    try {
      final response = await _client.read(
        RpcRequest(type: 'GetRepo', params: {'repo': repoIdOrName}),
      );

      return Right(KomodoRepo.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      if (e.isNotFound) {
        return const Left(Failure.server(message: 'Repo not found'));
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
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
    try {
      await _client.execute(RpcRequest(type: actionType, params: params));
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
RepoRepository? repoRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return RepoRepository(client);
}


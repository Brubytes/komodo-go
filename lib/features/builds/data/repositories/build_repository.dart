import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../models/build.dart';

part 'build_repository.g.dart';

/// Repository for build-related operations.
class BuildRepository {
  BuildRepository(this._client);

  final KomodoApiClient _client;

  static const Map<String, dynamic> _emptyBuildQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{
      'builder_ids': <String>[],
      'repos': <String>[],
      'built_since': 0,
    },
  };

  /// Lists all builds.
  Future<Either<Failure, List<BuildListItem>>> listBuilds() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListBuilds',
          params: <String, dynamic>{'query': _emptyBuildQuery},
        ),
      );

      final buildsJson = response as List<dynamic>? ?? [];
      final builds = buildsJson
          .map((json) => BuildListItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(builds);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error parsing builds: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets a specific build by ID or name.
  Future<Either<Failure, KomodoBuild>> getBuild(String buildIdOrName) async {
    try {
      final response = await _client.read(
        RpcRequest(type: 'GetBuild', params: {'build': buildIdOrName}),
      );

      return Right(KomodoBuild.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      if (e.isNotFound) {
        return const Left(Failure.server(message: 'Build not found'));
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Runs the target build.
  Future<Either<Failure, void>> runBuild(String buildIdOrName) async {
    return _executeAction('RunBuild', {'build': buildIdOrName});
  }

  /// Cancels the target build (only if currently building).
  Future<Either<Failure, void>> cancelBuild(String buildIdOrName) async {
    return _executeAction('CancelBuild', {'build': buildIdOrName});
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
BuildRepository? buildRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return BuildRepository(client);
}


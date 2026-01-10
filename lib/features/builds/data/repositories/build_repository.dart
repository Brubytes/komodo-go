import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_call.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/query_templates.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/utils/debug_log.dart';
import '../models/build.dart';

part 'build_repository.g.dart';

/// Repository for build-related operations.
class BuildRepository {
  BuildRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all builds.
  Future<Either<Failure, List<BuildListItem>>> listBuilds() async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListBuilds',
            params: <String, dynamic>{
              'query': emptyQuery(
                specific: <String, dynamic>{
                  'builder_ids': <String>[],
                  'repos': <String>[],
                  'built_since': 0,
                },
              ),
            },
          ),
        );

        final buildsJson = response as List<dynamic>? ?? [];
        return buildsJson
            .map((json) => BuildListItem.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      onUnknown: (error) {
        debugLog('Error parsing builds', name: 'API', error: error);
        return Failure.unknown(message: error.toString());
      },
    );
  }

  /// Gets a specific build by ID or name.
  Future<Either<Failure, KomodoBuild>> getBuild(String buildIdOrName) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(type: 'GetBuild', params: {'build': buildIdOrName}),
        );
        return KomodoBuild.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Build not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Runs the target build.
  Future<Either<Failure, void>> runBuild(String buildIdOrName) async {
    return _executeAction('RunBuild', {'build': buildIdOrName});
  }

  /// Cancels the target build (only if currently building).
  Future<Either<Failure, void>> cancelBuild(String buildIdOrName) async {
    return _executeAction('CancelBuild', {'build': buildIdOrName});
  }

  /// Resolves a builder id/name to its display name.
  Future<Either<Failure, String?>> getBuilderName(
    String builderIdOrName,
  ) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(type: 'GetBuilder', params: {'builder': builderIdOrName}),
        );

        if (response is Map) {
          final name = response['name'];
          if (name is String && name.trim().isNotEmpty) {
            return name.trim();
          }
        }

        return null;
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Builder not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  Future<Either<Failure, void>> _executeAction(
    String actionType,
    Map<String, dynamic> params,
  ) async {
    return apiCall(
      () async {
        await _client.execute(RpcRequest(type: actionType, params: params));
        return null;
      },
    );
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

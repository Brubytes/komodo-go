import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/query_templates.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/utils/debug_log.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_repository.g.dart';

/// Repository for server-related operations.
class ServerRepository {
  ServerRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all servers.
  Future<Either<Failure, List<Server>>> listServers() async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListServers',
            params: <String, dynamic>{'query': emptyQuery()},
          ),
        );

        // API returns array directly for list endpoints
        final serversJson = response as List<dynamic>? ?? [];
        return serversJson
            .map((json) => Server.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      onUnknown: (error) {
        debugLog('Error parsing servers', name: 'API', error: error);
        return Failure.unknown(message: error.toString());
      },
    );
  }

  /// Gets a specific server by ID or name.
  Future<Either<Failure, Server>> getServer(String serverIdOrName) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(type: 'GetServer', params: {'server': serverIdOrName}),
        );

        return Server.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Server not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Gets system stats for a server.
  Future<Either<Failure, SystemStats>> getSystemStats(
    String serverIdOrName,
  ) async {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(type: 'GetSystemStats', params: {'server': serverIdOrName}),
      );

      return SystemStats.fromJson(response as Map<String, dynamic>);
    });
  }

  /// Gets system information for a server.
  Future<Either<Failure, SystemInformation>> getSystemInformation(
    String serverIdOrName,
  ) async {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(
          type: 'GetSystemInformation',
          params: {'server': serverIdOrName},
        ),
      );

      return SystemInformation.fromJson(response as Map<String, dynamic>);
    });
  }

  /// Updates a server configuration and returns the updated server.
  ///
  /// Uses the `/write` module `UpdateServer` RPC.
  ///
  /// Note: Only fields included in [partialConfig] will be updated.
  Future<Either<Failure, Server>> updateServerConfig({
    required String serverId,
    required Map<String, dynamic> partialConfig,
  }) async {
    return apiCall(
      () async {
        final response = await _client.write(
          RpcRequest(
            type: 'UpdateServer',
            params: <String, dynamic>{'id': serverId, 'config': partialConfig},
          ),
        );

        return Server.fromJson(response as Map<String, dynamic>);
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        if (e.isNotFound) {
          return const Failure.server(message: 'Server not found');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }

  /// Lists Docker networks available on a server.
  Future<Either<Failure, List<String>>> listDockerNetworks(
    String serverIdOrName,
  ) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListDockerNetworks',
            params: {'server': serverIdOrName},
          ),
        );

        final networksList = response as List<dynamic>? ?? [];
        final names = <String>[];
        for (final item in networksList) {
          if (item is Map) {
            final name = item['name'];
            if (name is String && name.trim().isNotEmpty) {
              names.add(name.trim());
            }
          }
        }
        return names;
      },
      onApiException: (e) {
        if (e.isUnauthorized) return const Failure.auth();
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
    );
  }
}

@riverpod
ServerRepository? serverRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return ServerRepository(client);
}

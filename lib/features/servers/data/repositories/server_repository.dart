import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_repository.g.dart';

/// Repository for server-related operations.
class ServerRepository {
  ServerRepository(this._client);

  final KomodoApiClient _client;

  static const Map<String, dynamic> _emptyServerQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{},
  };

  /// Lists all servers.
  Future<Either<Failure, List<Server>>> listServers() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListServers',
          params: <String, dynamic>{'query': _emptyServerQuery},
        ),
      );

      // API returns array directly for list endpoints
      final serversJson = response as List<dynamic>? ?? [];
      final servers = serversJson
          .map((json) => Server.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(servers);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e, stackTrace) {
      // Logging parsing errors helps diagnose API mismatch during development.
      // ignore: avoid_print
      print('Error parsing servers: $e');
      // Logging stack traces helps diagnose API mismatch during development.
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets a specific server by ID or name.
  Future<Either<Failure, Server>> getServer(String serverIdOrName) async {
    try {
      final response = await _client.read(
        RpcRequest(type: 'GetServer', params: {'server': serverIdOrName}),
      );

      return Right(Server.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      if (e.isNotFound) {
        return const Left(Failure.server(message: 'Server not found'));
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets system stats for a server.
  Future<Either<Failure, SystemStats>> getSystemStats(
    String serverIdOrName,
  ) async {
    try {
      final response = await _client.read(
        RpcRequest(type: 'GetSystemStats', params: {'server': serverIdOrName}),
      );

      return Right(SystemStats.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets system information for a server.
  Future<Either<Failure, SystemInformation>> getSystemInformation(
    String serverIdOrName,
  ) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'GetSystemInformation',
          params: {'server': serverIdOrName},
        ),
      );

      return Right(
        SystemInformation.fromJson(response as Map<String, dynamic>),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
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

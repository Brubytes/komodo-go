import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../models/server.dart';
import '../models/system_stats.dart';

part 'server_repository.g.dart';

/// Repository for server-related operations.
class ServerRepository {
  ServerRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all servers.
  Future<Either<Failure, List<Server>>> listServers() async {
    try {
      final response = await _client.read(
        const RpcRequest(type: 'ListServers', params: <String, dynamic>{}),
      );

      final serversJson = response['servers'] as List<dynamic>? ?? [];
      final servers = serversJson
          .map((json) => Server.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(servers);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(
        Failure.server(message: e.message, statusCode: e.statusCode),
      );
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets a specific server by ID or name.
  Future<Either<Failure, Server>> getServer(String serverIdOrName) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'GetServer',
          params: {'server': serverIdOrName},
        ),
      );

      return Right(Server.fromJson(response));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      if (e.isNotFound) {
        return const Left(Failure.server(message: 'Server not found'));
      }
      return Left(
        Failure.server(message: e.message, statusCode: e.statusCode),
      );
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Gets system stats for a server.
  Future<Either<Failure, SystemStats>> getSystemStats(
    String serverIdOrName,
  ) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'GetSystemStats',
          params: {'server': serverIdOrName},
        ),
      );

      return Right(SystemStats.fromJson(response));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(
        Failure.server(message: e.message, statusCode: e.statusCode),
      );
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}

@riverpod
ServerRepository serverRepository(Ref ref) {
  return ServerRepository(ref.watch(apiClientProvider));
}

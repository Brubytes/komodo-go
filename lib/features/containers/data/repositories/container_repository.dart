import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../models/container.dart';

part 'container_repository.g.dart';

/// Repository for docker container related operations.
class ContainerRepository {
  ContainerRepository(this._client);

  final KomodoApiClient _client;

  /// Lists all docker containers on the target server.
  Future<Either<Failure, List<ContainerListItem>>> listDockerContainers(
    String serverIdOrName,
  ) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'ListDockerContainers',
          params: {'server': serverIdOrName},
        ),
      );

      final itemsJson = response as List<dynamic>? ?? [];
      final items = itemsJson
          .map(
            (json) => ContainerListItem.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      return Right(items);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error parsing containers: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}

@riverpod
ContainerRepository? containerRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return ContainerRepository(client);
}

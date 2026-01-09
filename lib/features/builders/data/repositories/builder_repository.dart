import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';

part 'builder_repository.g.dart';

class BuilderRepository {
  BuilderRepository(this._client);

  final KomodoApiClient _client;

  static const Map<String, dynamic> _emptyBuilderQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{},
  };

  Future<Either<Failure, List<BuilderListItem>>> listBuilders() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListBuilders',
          params: <String, dynamic>{'query': _emptyBuilderQuery},
        ),
      );

      final itemsJson = response as List<dynamic>? ?? [];
      final items = itemsJson
          .map((json) => BuilderListItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(items);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> getBuilderJson({
    required String builderIdOrName,
  }) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'GetBuilder',
          params: <String, dynamic>{'builder': builderIdOrName},
        ),
      );

      return Right(response as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, void>> renameBuilder({
    required String id,
    required String name,
  }) async {
    try {
      await _client.write(
        RpcRequest(
          type: 'RenameBuilder',
          params: <String, dynamic>{'id': id, 'name': name},
        ),
      );
      return const Right(null);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, void>> deleteBuilder({required String id}) async {
    try {
      await _client.write(
        RpcRequest(type: 'DeleteBuilder', params: <String, dynamic>{'id': id}),
      );
      return const Right(null);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, void>> updateBuilderConfig({
    required String id,
    required Map<String, dynamic> config,
  }) async {
    try {
      await _client.write(
        RpcRequest(
          type: 'UpdateBuilder',
          params: <String, dynamic>{'id': id, 'config': config},
        ),
      );
      return const Right(null);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}

@riverpod
BuilderRepository? builderRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return BuilderRepository(client);
}

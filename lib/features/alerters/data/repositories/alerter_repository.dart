import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';

part 'alerter_repository.g.dart';

class AlerterRepository {
  AlerterRepository(this._client);

  final KomodoApiClient _client;

  static const Map<String, dynamic> _emptyAlerterQuery = <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': <String, dynamic>{'enabled': null, 'types': <String>[]},
  };

  Future<Either<Failure, List<AlerterListItem>>> listAlerters() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListAlerters',
          params: <String, dynamic>{'query': _emptyAlerterQuery},
        ),
      );

      final itemsJson = response as List<dynamic>? ?? [];
      final items = itemsJson
          .map((json) => AlerterListItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(items);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, AlerterDetail>> getAlerterDetail({
    required String alerterIdOrName,
  }) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'GetAlerter',
          params: <String, dynamic>{'alerter': alerterIdOrName},
        ),
      );

      return Right(
        AlerterDetail.fromApiJson(response as Map<String, dynamic>),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, void>> renameAlerter({
    required String id,
    required String name,
  }) async {
    try {
      await _client.write(
        RpcRequest(
          type: 'RenameAlerter',
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

  Future<Either<Failure, void>> deleteAlerter({required String id}) async {
    try {
      await _client.write(
        RpcRequest(type: 'DeleteAlerter', params: <String, dynamic>{'id': id}),
      );
      return const Right(null);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, void>> setEnabled({
    required String id,
    required bool enabled,
  }) async {
    return updateAlerterConfig(
      id: id,
      config: <String, dynamic>{'enabled': enabled},
    );
  }

  Future<Either<Failure, void>> updateAlerterConfig({
    required String id,
    required Map<String, dynamic> config,
  }) async {
    try {
      await _client.write(
        RpcRequest(
          type: 'UpdateAlerter',
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

  Future<Either<Failure, void>> testAlerter({required String idOrName}) async {
    try {
      await _client.execute(
        RpcRequest(
          type: 'TestAlerter',
          params: <String, dynamic>{'alerter': idOrName},
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
AlerterRepository? alerterRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return AlerterRepository(client);
}

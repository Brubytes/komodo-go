import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/query_templates.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';

part 'alerter_repository.g.dart';

class AlerterRepository {
  AlerterRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, List<AlerterListItem>>> listAlerters() async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'ListAlerters',
            params: <String, dynamic>{
              'query': emptyQuery(
                specific: <String, dynamic>{
                  'enabled': null,
                  'types': <String>[],
                },
              ),
            },
          ),
        );

        final itemsJson = response as List<dynamic>? ?? [];
        return itemsJson
            .map((json) => AlerterListItem.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<Either<Failure, AlerterDetail>> getAlerterDetail({
    required String alerterIdOrName,
  }) async {
    return apiCall(
      () async {
        final response = await _client.read(
          RpcRequest(
            type: 'GetAlerter',
            params: <String, dynamic>{'alerter': alerterIdOrName},
          ),
        );
        return AlerterDetail.fromApiJson(response as Map<String, dynamic>);
      },
    );
  }

  Future<Either<Failure, void>> renameAlerter({
    required String id,
    required String name,
  }) async {
    return apiCall(
      () async {
        await _client.write(
          RpcRequest(
            type: 'RenameAlerter',
            params: <String, dynamic>{'id': id, 'name': name},
          ),
        );
        return null;
      },
    );
  }

  Future<Either<Failure, void>> deleteAlerter({required String id}) async {
    return apiCall(
      () async {
        await _client.write(
          RpcRequest(
            type: 'DeleteAlerter',
            params: <String, dynamic>{'id': id},
          ),
        );
        return null;
      },
    );
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
    return apiCall(
      () async {
        await _client.write(
          RpcRequest(
            type: 'UpdateAlerter',
            params: <String, dynamic>{'id': id, 'config': config},
          ),
        );
        return null;
      },
    );
  }

  Future<Either<Failure, void>> testAlerter({required String idOrName}) async {
    return apiCall(
      () async {
        await _client.execute(
          RpcRequest(
            type: 'TestAlerter',
            params: <String, dynamic>{'alerter': idOrName},
          ),
        );
        return null;
      },
    );
  }
}

@riverpod
AlerterRepository? alerterRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return AlerterRepository(client);
}

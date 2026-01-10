import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/api/query_templates.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';

part 'builder_repository.g.dart';

class BuilderRepository {
  BuilderRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, List<BuilderListItem>>> listBuilders() async {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(
          type: 'ListBuilders',
          params: <String, dynamic>{'query': emptyQuery()},
        ),
      );

      final itemsJson = response as List<dynamic>? ?? [];
      return itemsJson
          .map((json) => BuilderListItem.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Either<Failure, Map<String, dynamic>>> getBuilderJson({
    required String builderIdOrName,
  }) async {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(
          type: 'GetBuilder',
          params: <String, dynamic>{'builder': builderIdOrName},
        ),
      );

      return response as Map<String, dynamic>;
    });
  }

  Future<Either<Failure, void>> renameBuilder({
    required String id,
    required String name,
  }) async {
    return apiCall(() async {
      await _client.write(
        RpcRequest(
          type: 'RenameBuilder',
          params: <String, dynamic>{'id': id, 'name': name},
        ),
      );
      return null;
    });
  }

  Future<Either<Failure, void>> deleteBuilder({required String id}) async {
    return apiCall(() async {
      await _client.write(
        RpcRequest(type: 'DeleteBuilder', params: <String, dynamic>{'id': id}),
      );
      return null;
    });
  }

  Future<Either<Failure, void>> updateBuilderConfig({
    required String id,
    required Map<String, dynamic> config,
  }) async {
    return apiCall(() async {
      await _client.write(
        RpcRequest(
          type: 'UpdateBuilder',
          params: <String, dynamic>{'id': id, 'config': config},
        ),
      );
      return null;
    });
  }
}

@riverpod
BuilderRepository? builderRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return BuilderRepository(client);
}

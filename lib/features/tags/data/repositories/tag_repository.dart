import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/api/query_templates.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';

part 'tag_repository.g.dart';

class TagRepository {
  TagRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, List<KomodoTag>>> listTags() async {
    return apiCall(() async {
      final response = await _client.read(
        RpcRequest(
          type: 'ListTags',
          params: <String, dynamic>{'query': emptyQuery()},
        ),
      );

      final tagsJson = response as List<dynamic>? ?? [];
      return tagsJson
          .map((json) => KomodoTag.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Either<Failure, KomodoTag>> createTag({
    required String name,
    TagColor? color,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'CreateTag',
          params: <String, dynamic>{
            'name': name,
            'color': color == null ? null : color.token,
          },
        ),
      );

      return KomodoTag.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, KomodoTag>> deleteTag({required String id}) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(type: 'DeleteTag', params: <String, dynamic>{'id': id}),
      );

      return KomodoTag.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, KomodoTag>> renameTag({
    required String id,
    required String name,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'RenameTag',
          params: <String, dynamic>{'id': id, 'name': name},
        ),
      );

      return KomodoTag.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<Either<Failure, KomodoTag>> updateTagColor({
    required String tagIdOrName,
    required TagColor color,
  }) async {
    return apiCall(() async {
      final response = await _client.write(
        RpcRequest(
          type: 'UpdateTagColor',
          params: <String, dynamic>{'tag': tagIdOrName, 'color': color.token},
        ),
      );

      return KomodoTag.fromJson(response as Map<String, dynamic>);
    });
  }
}

@riverpod
TagRepository? tagRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return TagRepository(client);
}

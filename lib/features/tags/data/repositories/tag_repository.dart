import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';

part 'tag_repository.g.dart';

class TagRepository {
  TagRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, List<KomodoTag>>> listTags() async {
    try {
      final response = await _client.read(
        const RpcRequest(
          type: 'ListTags',
          params: <String, dynamic>{'query': null},
        ),
      );

      final tagsJson = response as List<dynamic>? ?? [];
      final tags = tagsJson
          .map((json) => KomodoTag.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(tags);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, KomodoTag>> createTag({
    required String name,
    TagColor? color,
  }) async {
    try {
      final response = await _client.write(
        RpcRequest(
          type: 'CreateTag',
          params: <String, dynamic>{
            'name': name,
            'color': color == null ? null : color.token,
          },
        ),
      );

      return Right(KomodoTag.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, KomodoTag>> deleteTag({required String id}) async {
    try {
      final response = await _client.write(
        RpcRequest(type: 'DeleteTag', params: <String, dynamic>{'id': id}),
      );

      return Right(KomodoTag.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, KomodoTag>> renameTag({
    required String id,
    required String name,
  }) async {
    try {
      final response = await _client.write(
        RpcRequest(
          type: 'RenameTag',
          params: <String, dynamic>{'id': id, 'name': name},
        ),
      );

      return Right(KomodoTag.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, KomodoTag>> updateTagColor({
    required String tagIdOrName,
    required TagColor color,
  }) async {
    try {
      final response = await _client.write(
        RpcRequest(
          type: 'UpdateTagColor',
          params: <String, dynamic>{'tag': tagIdOrName, 'color': color.token},
        ),
      );

      return Right(KomodoTag.fromJson(response as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return const Left(Failure.auth());
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on Object catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}

@riverpod
TagRepository? tagRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return TagRepository(client);
}


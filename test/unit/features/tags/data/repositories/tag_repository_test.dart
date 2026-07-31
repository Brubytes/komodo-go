import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/data/repositories/tag_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

T _rightOrFail<T>(Either<Failure, T> result) => result.fold(
  (failure) => fail('Expected Right, got $failure'),
  (value) => value,
);

const _tagJson = <String, dynamic>{
  'id': 'tag-1',
  'name': 'prod',
  'owner': 'admin',
  'color': 'Red',
};

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRpcRequest());
  });

  group('TagRepository', () {
    late _MockApiClient client;
    late TagRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = TagRepository(client);
    });

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedWrite() =>
        verify(() => client.write(captureAny())).captured.single
            as RpcRequest<dynamic>;

    test('listTags sends ListTags with empty params', () async {
      when(() => client.read(any())).thenAnswer((_) async => [_tagJson]);

      final result = await repository.listTags();

      final tags = _rightOrFail(result);
      expect(tags.single.name, 'prod');
      expect(tags.single.color, TagColor.red);

      final request = capturedRead();
      expect(request.type, 'ListTags');
      expect(request.params, <String, dynamic>{});
    });

    test('createTag sends CreateTag via write with name and color token',
        () async {
      when(() => client.write(any())).thenAnswer((_) async => _tagJson);

      final result = await repository.createTag(
        name: 'prod',
        color: TagColor.darkGreen,
      );

      expect(_rightOrFail(result).id, 'tag-1');

      final request = capturedWrite();
      expect(request.type, 'CreateTag');
      expect(request.params, <String, dynamic>{
        'name': 'prod',
        'color': 'DarkGreen',
      });
      verifyNever(() => client.execute(any()));
    });

    test('createTag sends null color when color is omitted', () async {
      when(() => client.write(any())).thenAnswer((_) async => _tagJson);

      final result = await repository.createTag(name: 'prod');

      expect(_rightOrFail(result).name, 'prod');

      final request = capturedWrite();
      expect(request.type, 'CreateTag');
      expect(request.params, <String, dynamic>{'name': 'prod', 'color': null});
    });

    test('deleteTag sends DeleteTag via write with id param', () async {
      when(() => client.write(any())).thenAnswer((_) async => _tagJson);

      final result = await repository.deleteTag(id: 'tag-1');

      expect(_rightOrFail(result).id, 'tag-1');

      final request = capturedWrite();
      expect(request.type, 'DeleteTag');
      expect(request.params, <String, dynamic>{'id': 'tag-1'});
      verifyNever(() => client.execute(any()));
    });

    test('renameTag sends RenameTag via write with id and name', () async {
      when(() => client.write(any())).thenAnswer((_) async => _tagJson);

      final result = await repository.renameTag(id: 'tag-1', name: 'staging');

      expect(_rightOrFail(result).id, 'tag-1');

      final request = capturedWrite();
      expect(request.type, 'RenameTag');
      expect(request.params, <String, dynamic>{
        'id': 'tag-1',
        'name': 'staging',
      });
    });

    test('updateTagColor sends UpdateTagColor via write with tag and token',
        () async {
      when(() => client.write(any())).thenAnswer((_) async => _tagJson);

      final result = await repository.updateTagColor(
        tagIdOrName: 'tag-1',
        color: TagColor.lightBlue,
      );

      expect(_rightOrFail(result).id, 'tag-1');

      final request = capturedWrite();
      expect(request.type, 'UpdateTagColor');
      expect(request.params, <String, dynamic>{
        'tag': 'tag-1',
        'color': 'LightBlue',
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/builders/data/repositories/builder_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

T _rightOrFail<T>(Either<Failure, T> result) => result.fold(
  (failure) => fail('Expected Right, got $failure'),
  (value) => value,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRpcRequest());
  });

  group('BuilderRepository', () {
    late _MockApiClient client;
    late BuilderRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = BuilderRepository(client);
    });

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedWrite() =>
        verify(() => client.write(captureAny())).captured.single
            as RpcRequest<dynamic>;

    test('listBuilders sends ListBuilders with exact query payload', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {'id': 'builder-1', 'name': 'local', 'info': <String, dynamic>{}},
        ],
      );

      final result = await repository.listBuilders();

      expect(_rightOrFail(result).single.id, 'builder-1');

      final request = capturedRead();
      expect(request.type, 'ListBuilders');
      expect(request.params, <String, dynamic>{
        'query': <String, dynamic>{
          'terms': '',
          'names': <String>[],
          'templates': 'Include',
          'tags': <String>[],
          'tag_behavior': 'All',
          'specific': <String, dynamic>{},
        },
        'sort_by': 'Name',
        'sort_desc': false,
        'page': 0,
        'limit': 50,
      });
    });

    test('getBuilderJson sends GetBuilder with builder param', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{'id': 'builder-1', 'name': 'local'},
      );

      final result = await repository.getBuilderJson(
        builderIdOrName: 'builder-1',
      );

      expect(_rightOrFail(result), {'id': 'builder-1', 'name': 'local'});

      final request = capturedRead();
      expect(request.type, 'GetBuilder');
      expect(request.params, <String, dynamic>{'builder': 'builder-1'});
    });

    test('renameBuilder sends RenameBuilder via write with id and name',
        () async {
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.renameBuilder(
        id: 'builder-1',
        name: 'remote',
      );

      _rightOrFail(result);

      final request = capturedWrite();
      expect(request.type, 'RenameBuilder');
      expect(request.params, <String, dynamic>{
        'id': 'builder-1',
        'name': 'remote',
      });
      verifyNever(() => client.execute(any()));
    });

    test('deleteBuilder sends DeleteBuilder via write with id param',
        () async {
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.deleteBuilder(id: 'builder-1');

      _rightOrFail(result);

      final request = capturedWrite();
      expect(request.type, 'DeleteBuilder');
      expect(request.params, <String, dynamic>{'id': 'builder-1'});
      verifyNever(() => client.execute(any()));
    });

    test('updateBuilderConfig sends UpdateBuilder via write with id and config',
        () async {
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.updateBuilderConfig(
        id: 'builder-1',
        config: {'type': 'Server'},
      );

      _rightOrFail(result);

      final request = capturedWrite();
      expect(request.type, 'UpdateBuilder');
      expect(request.params, <String, dynamic>{
        'id': 'builder-1',
        'config': {'type': 'Server'},
      });
      verifyNever(() => client.execute(any()));
    });
  });
}

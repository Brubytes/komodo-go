import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {
  @override
  KomodoApiCapabilities get capabilities =>
      KomodoApiCapabilities.v23AndNewer;
}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

T _rightOrFail<T>(Either<Failure, T> result) => result.fold(
  (failure) => fail('Expected Right, got $failure'),
  (value) => value,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRpcRequest());
  });

  group('BuildRepository', () {
    late _MockApiClient client;
    late BuildRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = BuildRepository(client);
    });

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedWrite() =>
        verify(() => client.write(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedExecute() =>
        verify(() => client.execute(captureAny())).captured.single
            as RpcRequest<dynamic>;

    test('listBuilds sends ListBuilds with exact query payload', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {'id': 'build-1', 'name': 'image', 'info': <String, dynamic>{}},
        ],
      );

      final result = await repository.listBuilds();

      expect(_rightOrFail(result).single.id, 'build-1');

      final request = capturedRead();
      expect(request.type, 'ListBuilds');
      expect(request.params, <String, dynamic>{
        'query': <String, dynamic>{
          'terms': '',
          'names': <String>[],
          'templates': 'Include',
          'tags': <String>[],
          'tag_behavior': 'All',
          'specific': <String, dynamic>{
            'builder_ids': <String>[],
            'repos': <String>[],
            'built_since': 0,
          },
        },
        'sort_by': 'Name',
        'sort_desc': false,
        'page': 0,
        'limit': 50,
      });
    });

    test('getBuild sends GetBuild with build param', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'build-1',
          'name': 'image',
          'config': <String, dynamic>{},
          'info': <String, dynamic>{},
        },
      );

      final result = await repository.getBuild('build-1');

      expect(_rightOrFail(result).name, 'image');

      final request = capturedRead();
      expect(request.type, 'GetBuild');
      expect(request.params, <String, dynamic>{'build': 'build-1'});
    });

    test('getBuilderName sends GetBuilder and trims the name', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{'name': ' local '},
      );

      final result = await repository.getBuilderName('builder-1');

      expect(_rightOrFail(result), 'local');

      final request = capturedRead();
      expect(request.type, 'GetBuilder');
      expect(request.params, <String, dynamic>{'builder': 'builder-1'});
    });

    test('runBuild sends RunBuild via execute with exact payload', () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.runBuild('build-1');

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'RunBuild');
      expect(request.params, <String, dynamic>{'build': 'build-1'});
      verifyNever(() => client.write(any()));
    });

    test('cancelBuild sends CancelBuild via execute with exact payload',
        () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.cancelBuild('build-1');

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'CancelBuild');
      expect(request.params, <String, dynamic>{'build': 'build-1'});
      verifyNever(() => client.write(any()));
    });

    test('updateBuildConfig sends UpdateBuild via write with id and config',
        () async {
      when(() => client.write(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'build-1',
          'name': 'image',
          'config': <String, dynamic>{},
          'info': <String, dynamic>{},
        },
      );

      final result = await repository.updateBuildConfig(
        buildId: 'build-1',
        partialConfig: {'branch': 'main'},
      );

      expect(_rightOrFail(result).id, 'build-1');

      final request = capturedWrite();
      expect(request.type, 'UpdateBuild');
      expect(request.params, <String, dynamic>{
        'id': 'build-1',
        'config': {'branch': 'main'},
      });
      verifyNever(() => client.execute(any()));
    });

    test('runBuild maps 401 to auth failure', () async {
      when(() => client.execute(any())).thenThrow(
        const ApiException(message: 'Unauthorized', statusCode: 401),
      );

      final result = await repository.runBuild('build-1');

      result.fold(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Expected auth failure'),
      );
    });
  });
}

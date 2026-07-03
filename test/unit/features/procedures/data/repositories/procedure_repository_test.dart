import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
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

  group('ProcedureRepository', () {
    late _MockApiClient client;
    late ProcedureRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = ProcedureRepository(client);
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

    test('listProcedures sends ListProcedures with exact query payload',
        () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {'id': 'proc-1', 'name': 'backup', 'info': <String, dynamic>{}},
        ],
      );

      final result = await repository.listProcedures();

      expect(_rightOrFail(result).single.id, 'proc-1');

      final request = capturedRead();
      expect(request.type, 'ListProcedures');
      expect(request.params, <String, dynamic>{
        'query': <String, dynamic>{
          'names': <String>[],
          'templates': 'Include',
          'tags': <String>[],
          'tag_behavior': 'All',
          'specific': <String, dynamic>{},
        },
      });
    });

    test('getProcedure sends GetProcedure with procedure param', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'proc-1',
          'name': 'backup',
          'config': <String, dynamic>{},
        },
      );

      final result = await repository.getProcedure('proc-1');

      expect(_rightOrFail(result).name, 'backup');

      final request = capturedRead();
      expect(request.type, 'GetProcedure');
      expect(request.params, <String, dynamic>{'procedure': 'proc-1'});
    });

    test('runProcedure sends RunProcedure via execute with exact payload',
        () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.runProcedure('proc-1');

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'RunProcedure');
      expect(request.params, <String, dynamic>{'procedure': 'proc-1'});
      verifyNever(() => client.write(any()));
    });

    test(
        'updateProcedureConfig sends UpdateProcedure via write '
        'with id and config', () async {
      when(() => client.write(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'proc-1',
          'name': 'backup',
          'config': <String, dynamic>{},
        },
      );

      final result = await repository.updateProcedureConfig(
        procedureId: 'proc-1',
        partialConfig: {'schedule': 'every day at 03:00'},
      );

      expect(_rightOrFail(result).id, 'proc-1');

      final request = capturedWrite();
      expect(request.type, 'UpdateProcedure');
      expect(request.params, <String, dynamic>{
        'id': 'proc-1',
        'config': {'schedule': 'every day at 03:00'},
      });
      verifyNever(() => client.execute(any()));
    });

    test('runProcedure maps 401 to auth failure', () async {
      when(() => client.execute(any())).thenThrow(
        const ApiException(message: 'Unauthorized', statusCode: 401),
      );

      final result = await repository.runProcedure('proc-1');

      result.fold(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Expected auth failure'),
      );
    });

    test('runProcedure maps generic ApiException to server failure', () async {
      when(() => client.execute(any())).thenThrow(
        const ApiException(message: 'boom', statusCode: 500),
      );

      final result = await repository.runProcedure('proc-1');

      result.fold(
        (failure) => expect(
          failure,
          const Failure.server(message: 'boom', statusCode: 500),
        ),
        (_) => fail('Expected server failure'),
      );
    });
  });
}

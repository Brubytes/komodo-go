import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {
  KomodoApiCapabilities capabilitiesValue =
      KomodoApiCapabilities.v23AndNewer;

  @override
  KomodoApiCapabilities get capabilities => capabilitiesValue;
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

  group('ActionRepository', () {
    late _MockApiClient client;
    late ActionRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = ActionRepository(client);
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

    test('listActions sends ListActions with exact query payload', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {'id': 'action-1', 'name': 'cleanup', 'info': <String, dynamic>{}},
        ],
      );

      final result = await repository.listActions();

      expect(_rightOrFail(result).single.id, 'action-1');

      final request = capturedRead();
      expect(request.type, 'ListActions');
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

    test('getAction sends GetAction with action param', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'action-1',
          'name': 'cleanup',
          'config': <String, dynamic>{},
        },
      );

      final result = await repository.getAction('action-1');

      expect(_rightOrFail(result).name, 'cleanup');

      final request = capturedRead();
      expect(request.type, 'GetAction');
      expect(request.params, <String, dynamic>{'action': 'action-1'});
    });

    test('runAction sends RunAction via execute with null args by default',
        () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.runAction('action-1');

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'RunAction');
      expect(request.params, <String, dynamic>{
        'action': 'action-1',
        'args': null,
      });
      verifyNever(() => client.write(any()));
    });

    test('runAction forwards args map', () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.runAction(
        'action-1',
        args: {'target': 'web'},
      );

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'RunAction');
      expect(request.params, <String, dynamic>{
        'action': 'action-1',
        'args': {'target': 'web'},
      });
    });

    test('cancelAction sends CancelAction with an optional update id',
        () async {
      when(() => client.execute(any()))
          .thenAnswer((_) async => <String, dynamic>{});

      _rightOrFail(
        await repository.cancelAction('action-1', updateId: 'update-1'),
      );

      final request = capturedExecute();
      expect(request.type, 'CancelAction');
      expect(request.params, <String, dynamic>{
        'action': 'action-1',
        'update_id': 'update-1',
      });
    });

    test('Komodo 2.2 reports action cancellation as unsupported', () async {
      client.capabilitiesValue = KomodoApiCapabilities.v22;

      final result = await repository.cancelAction('action-1');

      result.fold(
        (failure) => expect(
          failure,
          const Failure.server(
            message: 'Canceling actions requires Komodo 2.3 or newer.',
          ),
        ),
        (_) => fail('Expected cancellation to be unsupported'),
      );
      verifyNever(() => client.execute(any()));
    });

    test('updateActionConfig sends UpdateAction via write with id and config',
        () async {
      when(() => client.write(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'action-1',
          'name': 'cleanup',
          'config': <String, dynamic>{},
        },
      );

      final result = await repository.updateActionConfig(
        actionId: 'action-1',
        partialConfig: {'schedule_enabled': true},
      );

      expect(_rightOrFail(result).id, 'action-1');

      final request = capturedWrite();
      expect(request.type, 'UpdateAction');
      expect(request.params, <String, dynamic>{
        'id': 'action-1',
        'config': {'schedule_enabled': true},
      });
      verifyNever(() => client.execute(any()));
    });

    test('runAction maps 401 to auth failure', () async {
      when(() => client.execute(any())).thenThrow(
        const ApiException(message: 'Unauthorized', statusCode: 401),
      );

      final result = await repository.runAction('action-1');

      result.fold(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Expected auth failure'),
      );
    });
  });
}

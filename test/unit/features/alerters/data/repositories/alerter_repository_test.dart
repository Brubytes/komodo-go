import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/alerters/data/repositories/alerter_repository.dart';
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

  group('AlerterRepository', () {
    late _MockApiClient client;
    late AlerterRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = AlerterRepository(client);
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

    test('listAlerters sends ListAlerters with exact query payload', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {'id': 'alerter-1', 'name': 'slack', 'info': <String, dynamic>{}},
        ],
      );

      final result = await repository.listAlerters();

      expect(_rightOrFail(result).single.id, 'alerter-1');

      final request = capturedRead();
      expect(request.type, 'ListAlerters');
      expect(request.params, <String, dynamic>{
        'query': <String, dynamic>{
          'terms': '',
          'names': <String>[],
          'templates': 'Include',
          'tags': <String>[],
          'tag_behavior': 'All',
          'specific': <String, dynamic>{
            'enabled': null,
            'types': <String>[],
          },
        },
        'sort_by': 'Name',
        'sort_desc': false,
        'page': 0,
        'limit': 50,
      });
    });

    test('getAlerterDetail sends GetAlerter with alerter param', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'alerter-1',
          'name': 'slack',
          'config': <String, dynamic>{'enabled': true},
        },
      );

      final result = await repository.getAlerterDetail(
        alerterIdOrName: 'alerter-1',
      );

      final detail = _rightOrFail(result);
      expect(detail.name, 'slack');
      expect(detail.config.enabled, isTrue);

      final request = capturedRead();
      expect(request.type, 'GetAlerter');
      expect(request.params, <String, dynamic>{'alerter': 'alerter-1'});
    });

    test('renameAlerter sends RenameAlerter via write with id and name',
        () async {
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.renameAlerter(
        id: 'alerter-1',
        name: 'discord',
      );

      _rightOrFail(result);

      final request = capturedWrite();
      expect(request.type, 'RenameAlerter');
      expect(request.params, <String, dynamic>{
        'id': 'alerter-1',
        'name': 'discord',
      });
      verifyNever(() => client.execute(any()));
    });

    test('deleteAlerter sends DeleteAlerter via write with id param',
        () async {
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.deleteAlerter(id: 'alerter-1');

      _rightOrFail(result);

      final request = capturedWrite();
      expect(request.type, 'DeleteAlerter');
      expect(request.params, <String, dynamic>{'id': 'alerter-1'});
      verifyNever(() => client.execute(any()));
    });

    test('updateAlerterConfig sends UpdateAlerter via write with id and config',
        () async {
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.updateAlerterConfig(
        id: 'alerter-1',
        config: {'alert_types': <String>[]},
      );

      _rightOrFail(result);

      final request = capturedWrite();
      expect(request.type, 'UpdateAlerter');
      expect(request.params, <String, dynamic>{
        'id': 'alerter-1',
        'config': {'alert_types': <String>[]},
      });
    });

    test('setEnabled delegates to UpdateAlerter with enabled-only config',
        () async {
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.setEnabled(id: 'alerter-1', enabled: false);

      _rightOrFail(result);

      final request = capturedWrite();
      expect(request.type, 'UpdateAlerter');
      expect(request.params, <String, dynamic>{
        'id': 'alerter-1',
        'config': {'enabled': false},
      });
    });

    test('testAlerter sends TestAlerter via execute with alerter param',
        () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.testAlerter(idOrName: 'alerter-1');

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'TestAlerter');
      expect(request.params, <String, dynamic>{'alerter': 'alerter-1'});
      verifyNever(() => client.write(any()));
    });

    test('deleteAlerter maps 401 to auth failure', () async {
      when(() => client.write(any())).thenThrow(
        const ApiException(message: 'Unauthorized', statusCode: 401),
      );

      final result = await repository.deleteAlerter(id: 'alerter-1');

      result.fold(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Expected auth failure'),
      );
    });
  });
}

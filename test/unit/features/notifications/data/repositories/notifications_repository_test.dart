import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/repositories/notifications_repository.dart';
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

  group('NotificationsRepository', () {
    late _MockApiClient client;
    late NotificationsRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = NotificationsRepository(client);
    });

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    test(
      'listAlerts sends ListAlerts with query and page and parses page',
      () async {
        when(() => client.read(any())).thenAnswer(
          (_) async => <String, dynamic>{
            'alerts': [
              <String, dynamic>{
                'id': 'alert-1',
                'ts': 1700000000000,
                'resolved': false,
                'level': 'Warning',
                'data': <String, dynamic>{
                  'type': 'ServerCpu',
                  'data': <String, dynamic>{'name': 'alpha'},
                },
              },
            ],
            'next_page': 3,
          },
        );

        final result = await repository.listAlerts(
          page: 2,
          query: <String, dynamic>{
            'types': ['ServerCpu'],
          },
        );

        final page = _rightOrFail(result);
        expect(page.alerts.single.id, 'alert-1');
        expect(page.alerts.single.level, SeverityLevel.warning);
        expect(page.nextPage, 3);

        final request = capturedRead();
        expect(request.type, 'ListAlerts');
        expect(request.params, <String, dynamic>{
          'query': <String, dynamic>{
            'types': ['ServerCpu'],
          },
          'page': 2,
        });
      },
    );

    test(
      'listAlerts sends null query by default and handles non-map response',
      () async {
        when(() => client.read(any())).thenAnswer((_) async => <dynamic>[]);

        final result = await repository.listAlerts(page: 0);

        final page = _rightOrFail(result);
        expect(page.alerts, isEmpty);
        expect(page.nextPage, isNull);

        final request = capturedRead();
        expect(request.type, 'ListAlerts');
        expect(request.params, <String, dynamic>{'query': null, 'page': 0});
      },
    );

    test(
      'listUpdates sends ListUpdates with query and page and parses items',
      () async {
        when(() => client.read(any())).thenAnswer(
          (_) async => <String, dynamic>{
            'updates': [
              <String, dynamic>{
                'id': 'update-1',
                'operation': 'DeployStack',
                'start_ts': 1700000000000,
                'success': true,
                'username': 'jan',
                'operator': 'jan',
                'status': 'Complete',
                'version': <String, dynamic>{
                  'major': 1,
                  'minor': 2,
                  'patch': 3,
                },
              },
            ],
            'next_page': null,
          },
        );

        final result = await repository.listUpdates(page: 1);

        final page = _rightOrFail(result);
        expect(page.updates.single.id, 'update-1');
        expect(page.updates.single.operation, 'DeployStack');
        expect(page.nextPage, isNull);

        final request = capturedRead();
        expect(request.type, 'ListUpdates');
        expect(request.params, <String, dynamic>{'query': null, 'page': 1});
      },
    );

    test('getUpdate sends GetUpdate and parses full detail', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'update-1',
          'operation': 'RunAction',
          'start_ts': 1700000000000,
          'end_ts': 1700000001000,
          'success': true,
          'operator': 'jan',
          'status': 'Complete',
          'logs': <dynamic>[],
          'version': <String, dynamic>{'major': 2, 'minor': 3, 'patch': 1},
        },
      );

      final detail = _rightOrFail(await repository.getUpdate('update-1'));

      expect(detail.operation, 'RunAction');
      expect(detail.duration, const Duration(seconds: 1));
      final request = capturedRead();
      expect(request.type, 'GetUpdate');
      expect(request.params, <String, dynamic>{'id': 'update-1'});
    });
  });
}

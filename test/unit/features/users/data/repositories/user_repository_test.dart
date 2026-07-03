import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/users/data/repositories/user_repository.dart';
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

  group('UserRepository', () {
    late _MockApiClient client;
    late UserRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = UserRepository(client);
    });

    test('getUsername sends GetUsername with user_id param and trims name',
        () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{'username': ' jan '},
      );

      final result = await repository.getUsername(userId: 'user-1');

      expect(_rightOrFail(result), 'jan');

      final request = verify(() => client.read(captureAny())).captured.single
          as RpcRequest<dynamic>;
      expect(request.type, 'GetUsername');
      expect(request.params, <String, dynamic>{'user_id': 'user-1'});
    });

    test('getUsername maps empty username to server failure', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{'username': '  '},
      );

      final result = await repository.getUsername(userId: 'user-1');

      result.fold(
        (failure) => expect(
          failure,
          const Failure.server(message: 'User not found', statusCode: 404),
        ),
        (_) => fail('Expected server failure'),
      );
    });

    test('getUsername maps 401 to auth failure', () async {
      when(() => client.read(any())).thenThrow(
        const ApiException(message: 'Unauthorized', statusCode: 401),
      );

      final result = await repository.getUsername(userId: 'user-1');

      result.fold(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Expected auth failure'),
      );
    });
  });
}

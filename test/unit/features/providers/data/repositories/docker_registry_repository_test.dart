import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/providers/data/repositories/docker_registry_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

T _rightOrFail<T>(Either<Failure, T> result) => result.fold(
  (failure) => fail('Expected Right, got $failure'),
  (value) => value,
);

const _accountJson = <String, dynamic>{
  'id': 'reg-1',
  'domain': 'docker.io',
  'username': 'me',
};

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRpcRequest());
  });

  group('DockerRegistryRepository', () {
    late _MockApiClient client;
    late DockerRegistryRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = DockerRegistryRepository(client);
    });

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedWrite() =>
        verify(() => client.write(captureAny())).captured.single
            as RpcRequest<dynamic>;

    test('listAccounts sends ListDockerRegistryAccounts with empty params',
        () async {
      when(() => client.read(any())).thenAnswer((_) async => [_accountJson]);

      final result = await repository.listAccounts();

      expect(_rightOrFail(result).single.id, 'reg-1');

      final request = capturedRead();
      expect(request.type, 'ListDockerRegistryAccounts');
      expect(request.params, <String, dynamic>{});
    });

    test('listAccounts trims and forwards domain and username filters',
        () async {
      when(() => client.read(any())).thenAnswer((_) async => <dynamic>[]);

      await repository.listAccounts(domain: ' docker.io ', username: ' me ');

      final request = capturedRead();
      expect(request.type, 'ListDockerRegistryAccounts');
      expect(request.params, <String, dynamic>{
        'domain': 'docker.io',
        'username': 'me',
      });
    });

    test(
        'createAccount sends CreateDockerRegistryAccount via write '
        'with nested trimmed account', () async {
      when(() => client.write(any())).thenAnswer((_) async => _accountJson);

      final result = await repository.createAccount(
        domain: ' docker.io ',
        username: ' me ',
        token: 'tok',
      );

      expect(_rightOrFail(result).domain, 'docker.io');

      final request = capturedWrite();
      expect(request.type, 'CreateDockerRegistryAccount');
      expect(request.params, <String, dynamic>{
        'account': <String, dynamic>{
          'domain': 'docker.io',
          'username': 'me',
          'token': 'tok',
        },
      });
      verifyNever(() => client.execute(any()));
    });

    test(
        'updateAccount sends UpdateDockerRegistryAccount via write '
        'with id and only provided fields', () async {
      when(() => client.write(any())).thenAnswer((_) async => _accountJson);

      final result = await repository.updateAccount(
        id: 'reg-1',
        token: ' new-tok ',
      );

      expect(_rightOrFail(result).id, 'reg-1');

      final request = capturedWrite();
      expect(request.type, 'UpdateDockerRegistryAccount');
      expect(request.params, <String, dynamic>{
        'id': 'reg-1',
        'account': <String, dynamic>{'token': 'new-tok'},
      });
    });

    test('deleteAccount sends DeleteDockerRegistryAccount via write with id',
        () async {
      when(() => client.write(any())).thenAnswer((_) async => _accountJson);

      final result = await repository.deleteAccount(id: 'reg-1');

      expect(_rightOrFail(result).id, 'reg-1');

      final request = capturedWrite();
      expect(request.type, 'DeleteDockerRegistryAccount');
      expect(request.params, <String, dynamic>{'id': 'reg-1'});
      verifyNever(() => client.execute(any()));
    });
  });
}

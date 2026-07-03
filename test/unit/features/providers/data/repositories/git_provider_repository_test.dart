import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/providers/data/repositories/git_provider_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

T _rightOrFail<T>(Either<Failure, T> result) => result.fold(
  (failure) => fail('Expected Right, got $failure'),
  (value) => value,
);

const _accountJson = <String, dynamic>{
  'id': 'acc-1',
  'domain': 'github.com',
  'username': 'me',
};

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRpcRequest());
  });

  group('GitProviderRepository', () {
    late _MockApiClient client;
    late GitProviderRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = GitProviderRepository(client);
    });

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedWrite() =>
        verify(() => client.write(captureAny())).captured.single
            as RpcRequest<dynamic>;

    test('listAccounts sends ListGitProviderAccounts with empty params',
        () async {
      when(() => client.read(any())).thenAnswer((_) async => [_accountJson]);

      final result = await repository.listAccounts();

      expect(_rightOrFail(result).single.id, 'acc-1');

      final request = capturedRead();
      expect(request.type, 'ListGitProviderAccounts');
      expect(request.params, <String, dynamic>{});
    });

    test('listAccounts trims and forwards domain and username filters',
        () async {
      when(() => client.read(any())).thenAnswer((_) async => <dynamic>[]);

      await repository.listAccounts(domain: ' github.com ', username: ' me ');

      final request = capturedRead();
      expect(request.type, 'ListGitProviderAccounts');
      expect(request.params, <String, dynamic>{
        'domain': 'github.com',
        'username': 'me',
      });
    });

    test(
        'createAccount sends CreateGitProviderAccount via write '
        'with nested trimmed account', () async {
      when(() => client.write(any())).thenAnswer((_) async => _accountJson);

      final result = await repository.createAccount(
        domain: ' github.com ',
        username: ' me ',
        token: 'tok',
        https: true,
      );

      expect(_rightOrFail(result).domain, 'github.com');

      final request = capturedWrite();
      expect(request.type, 'CreateGitProviderAccount');
      expect(request.params, <String, dynamic>{
        'account': <String, dynamic>{
          'domain': 'github.com',
          'username': 'me',
          'token': 'tok',
          'https': true,
        },
      });
      verifyNever(() => client.execute(any()));
    });

    test(
        'updateAccount sends UpdateGitProviderAccount via write '
        'with id and only provided fields', () async {
      when(() => client.write(any())).thenAnswer((_) async => _accountJson);

      final result = await repository.updateAccount(
        id: 'acc-1',
        username: 'new-me',
        https: false,
      );

      expect(_rightOrFail(result).id, 'acc-1');

      final request = capturedWrite();
      expect(request.type, 'UpdateGitProviderAccount');
      expect(request.params, <String, dynamic>{
        'id': 'acc-1',
        'account': <String, dynamic>{'username': 'new-me', 'https': false},
      });
    });

    test('deleteAccount sends DeleteGitProviderAccount via write with id',
        () async {
      when(() => client.write(any())).thenAnswer((_) async => _accountJson);

      final result = await repository.deleteAccount(id: 'acc-1');

      expect(_rightOrFail(result).id, 'acc-1');

      final request = capturedWrite();
      expect(request.type, 'DeleteGitProviderAccount');
      expect(request.params, <String, dynamic>{'id': 'acc-1'});
      verifyNever(() => client.execute(any()));
    });
  });
}

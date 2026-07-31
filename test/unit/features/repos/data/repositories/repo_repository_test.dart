import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
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

  group('RepoRepository', () {
    late _MockApiClient client;
    late RepoRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = RepoRepository(client);
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

    test('listRepos sends ListRepos with exact query payload', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {'id': 'repo-1', 'name': 'infra', 'info': <String, dynamic>{}},
        ],
      );

      final result = await repository.listRepos();

      expect(_rightOrFail(result).single.id, 'repo-1');

      final request = capturedRead();
      expect(request.type, 'ListRepos');
      expect(request.params, <String, dynamic>{
        'query': <String, dynamic>{
          'terms': '',
          'names': <String>[],
          'templates': 'Include',
          'tags': <String>[],
          'tag_behavior': 'All',
          'specific': <String, dynamic>{'repos': <String>[]},
        },
        'sort_by': 'Name',
        'sort_desc': false,
        'page': 0,
        'limit': 50,
      });
    });

    test('getRepo sends GetRepo with repo param', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'repo-1',
          'name': 'infra',
          'config': <String, dynamic>{},
          'info': <String, dynamic>{},
        },
      );

      final result = await repository.getRepo('repo-1');

      expect(_rightOrFail(result).name, 'infra');

      final request = capturedRead();
      expect(request.type, 'GetRepo');
      expect(request.params, <String, dynamic>{'repo': 'repo-1'});
    });

    group('execute payloads', () {
      setUp(() {
        when(
          () => client.execute(any()),
        ).thenAnswer((_) async => <String, dynamic>{});
      });

      final actions = <String, Future<Either<Failure, void>> Function()>{
        'CloneRepo': () => repository.cloneRepo('repo-1'),
        'PullRepo': () => repository.pullRepo('repo-1'),
        'BuildRepo': () => repository.buildRepo('repo-1'),
      };

      for (final entry in actions.entries) {
        test('${entry.key} is sent via execute with exact payload', () async {
          final result = await entry.value();

          _rightOrFail(result);

          final request = capturedExecute();
          expect(request.type, entry.key);
          expect(request.params, <String, dynamic>{'repo': 'repo-1'});
          verifyNever(() => client.write(any()));
        });
      }
    });

    test('updateRepoConfig sends UpdateRepo via write with id and config',
        () async {
      when(() => client.write(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'repo-1',
          'name': 'infra',
          'config': <String, dynamic>{},
          'info': <String, dynamic>{},
        },
      );

      final result = await repository.updateRepoConfig(
        repoId: 'repo-1',
        partialConfig: {'branch': 'main'},
      );

      expect(_rightOrFail(result).id, 'repo-1');

      final request = capturedWrite();
      expect(request.type, 'UpdateRepo');
      expect(request.params, <String, dynamic>{
        'id': 'repo-1',
        'config': {'branch': 'main'},
      });
      verifyNever(() => client.execute(any()));
    });

    test('pullRepo maps 401 to auth failure', () async {
      when(() => client.execute(any())).thenThrow(
        const ApiException(message: 'Unauthorized', statusCode: 401),
      );

      final result = await repository.pullRepo('repo-1');

      result.fold(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Expected auth failure'),
      );
    });
  });
}

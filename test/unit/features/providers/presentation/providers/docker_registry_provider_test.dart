import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:komodo_go/features/providers/data/repositories/docker_registry_repository.dart';
import 'package:komodo_go/features/providers/presentation/providers/docker_registry_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockDockerRegistryRepository extends Mock
    implements DockerRegistryRepository {}

void main() {
  group('Docker registry accounts', () {
    test('returns sorted accounts when repository succeeds', () async {
      final repository = _MockDockerRegistryRepository();
      when(repository.listAccounts).thenAnswer(
        (_) async => Right([
          DockerRegistryAccount.fromJson(<String, dynamic>{
            'id': 'd1',
            'domain': 'b.registry.io',
            'username': 'alpha',
          }),
          DockerRegistryAccount.fromJson(<String, dynamic>{
            'id': 'd2',
            'domain': 'a.registry.io',
            'username': 'zeta',
          }),
          DockerRegistryAccount.fromJson(<String, dynamic>{
            'id': 'd3',
            'domain': 'a.registry.io',
            'username': 'beta',
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [
          dockerRegistryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, dockerRegistryAccountsProvider);
      addTearDown(subscription.close);

      final accounts = await readAsyncProvider(
        container,
        dockerRegistryAccountsProvider.future,
      );

      expect(accounts, hasLength(3));
      expect(accounts.first.domain, 'a.registry.io');
      expect(accounts.first.username, 'beta');
      expect(accounts.last.domain, 'b.registry.io');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [dockerRegistryRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, dockerRegistryAccountsProvider);
      addTearDown(subscription.close);

      final accounts = await readAsyncProvider(
        container,
        dockerRegistryAccountsProvider.future,
      );

      expect(accounts, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockDockerRegistryRepository();
      when(repository.listAccounts).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [
          dockerRegistryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, dockerRegistryAccountsProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(dockerRegistryAccountsProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(dockerRegistryAccountsProvider));
    });
  });

  group('Docker registry actions', () {
    test('create returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [dockerRegistryRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dockerRegistryActionsProvider.notifier);
      final ok = await notifier.create(
        domain: 'registry.io',
        username: 'user',
        token: 'token',
      );

      expect(ok, isFalse);
      expectAsyncError(container.read(dockerRegistryActionsProvider));
    });

    test('create returns true on success', () async {
      final repository = _MockDockerRegistryRepository();
      when(
        () => repository.createAccount(
          domain: 'registry.io',
          username: 'user',
          token: 'token',
        ),
      ).thenAnswer(
        (_) async => Right(
          DockerRegistryAccount.fromJson(<String, dynamic>{
            'id': 'd1',
            'domain': 'registry.io',
            'username': 'user',
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [
          dockerRegistryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dockerRegistryActionsProvider.notifier);
      final ok = await notifier.create(
        domain: 'registry.io',
        username: 'user',
        token: 'token',
      );

      expect(ok, isTrue);
      expect(container.read(dockerRegistryActionsProvider).hasError, isFalse);
    });

    test('update returns true on success', () async {
      final repository = _MockDockerRegistryRepository();
      when(
        () => repository.updateAccount(
          id: 'd1',
          domain: 'b.registry.io',
          username: 'new',
        ),
      ).thenAnswer(
        (_) async => Right(
          DockerRegistryAccount.fromJson(<String, dynamic>{
            'id': 'd1',
            'domain': 'b.registry.io',
            'username': 'new',
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [
          dockerRegistryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dockerRegistryActionsProvider.notifier);
      final ok = await notifier.update(
        original: DockerRegistryAccount.fromJson(<String, dynamic>{
          'id': 'd1',
          'domain': 'a.registry.io',
          'username': 'old',
        }),
        domain: 'b.registry.io',
        username: 'new',
        token: '',
      );

      expect(ok, isTrue);
      expect(container.read(dockerRegistryActionsProvider).hasError, isFalse);
    });

    test('delete returns true on success', () async {
      final repository = _MockDockerRegistryRepository();
      when(() => repository.deleteAccount(id: 'd1')).thenAnswer(
        (_) async => Right(
          DockerRegistryAccount.fromJson(<String, dynamic>{
            'id': 'd1',
            'domain': 'registry.io',
            'username': 'user',
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [
          dockerRegistryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dockerRegistryActionsProvider.notifier);
      final ok = await notifier.delete('d1');

      expect(ok, isTrue);
      expect(container.read(dockerRegistryActionsProvider).hasError, isFalse);
    });
  });
}

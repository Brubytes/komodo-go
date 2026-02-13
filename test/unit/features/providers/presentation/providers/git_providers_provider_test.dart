import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/providers/data/repositories/git_provider_repository.dart';
import 'package:komodo_go/features/providers/presentation/providers/git_providers_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockGitProviderRepository extends Mock implements GitProviderRepository {}

void main() {
  group('Git providers', () {
    test('returns sorted accounts when repository succeeds', () async {
      final repository = _MockGitProviderRepository();
      when(repository.listAccounts).thenAnswer(
        (_) async => Right([
          GitProviderAccount.fromJson(<String, dynamic>{
            'id': 'g1',
            'domain': 'b.example.com',
            'username': 'alpha',
          }),
          GitProviderAccount.fromJson(<String, dynamic>{
            'id': 'g2',
            'domain': 'a.example.com',
            'username': 'zeta',
          }),
          GitProviderAccount.fromJson(<String, dynamic>{
            'id': 'g3',
            'domain': 'a.example.com',
            'username': 'beta',
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [gitProviderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, gitProvidersProvider);
      addTearDown(subscription.close);

      final accounts = await readAsyncProvider(
        container,
        gitProvidersProvider.future,
      );

      expect(accounts, hasLength(3));
      expect(accounts.first.domain, 'a.example.com');
      expect(accounts.first.username, 'beta');
      expect(accounts.last.domain, 'b.example.com');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [gitProviderRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, gitProvidersProvider);
      addTearDown(subscription.close);

      final accounts = await readAsyncProvider(
        container,
        gitProvidersProvider.future,
      );

      expect(accounts, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockGitProviderRepository();
      when(repository.listAccounts).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [gitProviderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, gitProvidersProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(gitProvidersProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(gitProvidersProvider));
    });
  });

  group('Git provider actions', () {
    test('create returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [gitProviderRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gitProviderActionsProvider.notifier);
      final ok = await notifier.create(
        domain: 'example.com',
        username: 'user',
        token: 'token',
        https: true,
      );

      expect(ok, isFalse);
      expectAsyncError(container.read(gitProviderActionsProvider));
    });

    test('create returns true on success', () async {
      final repository = _MockGitProviderRepository();
      when(
        () => repository.createAccount(
          domain: 'example.com',
          username: 'user',
          token: 'token',
          https: true,
        ),
      ).thenAnswer(
        (_) async => Right(
          GitProviderAccount.fromJson(<String, dynamic>{
            'id': 'g1',
            'domain': 'example.com',
            'username': 'user',
            'https': true,
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [gitProviderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gitProviderActionsProvider.notifier);
      final ok = await notifier.create(
        domain: 'example.com',
        username: 'user',
        token: 'token',
        https: true,
      );

      expect(ok, isTrue);
      expect(container.read(gitProviderActionsProvider).hasError, isFalse);
    });

    test('update returns true on success', () async {
      final repository = _MockGitProviderRepository();
      when(
        () => repository.updateAccount(
          id: 'g1',
          domain: 'b.example.com',
          username: 'new',
          https: false,
        ),
      ).thenAnswer(
        (_) async => Right(
          GitProviderAccount.fromJson(<String, dynamic>{
            'id': 'g1',
            'domain': 'b.example.com',
            'username': 'new',
            'https': false,
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [gitProviderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gitProviderActionsProvider.notifier);
      final ok = await notifier.update(
        original: GitProviderAccount.fromJson(<String, dynamic>{
          'id': 'g1',
          'domain': 'a.example.com',
          'username': 'old',
          'https': true,
        }),
        domain: 'b.example.com',
        username: 'new',
        https: false,
        token: '',
      );

      expect(ok, isTrue);
      expect(container.read(gitProviderActionsProvider).hasError, isFalse);
    });

    test('delete returns true on success', () async {
      final repository = _MockGitProviderRepository();
      when(() => repository.deleteAccount(id: 'g1')).thenAnswer(
        (_) async => Right(
          GitProviderAccount.fromJson(<String, dynamic>{
            'id': 'g1',
            'domain': 'example.com',
            'username': 'user',
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [gitProviderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gitProviderActionsProvider.notifier);
      final ok = await notifier.delete('g1');

      expect(ok, isTrue);
      expect(container.read(gitProviderActionsProvider).hasError, isFalse);
    });
  });
}

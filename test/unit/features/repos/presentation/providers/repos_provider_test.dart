import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockRepoRepository extends Mock implements RepoRepository {}

void main() {
  group('Repos provider', () {
    test('returns repos when repository succeeds', () async {
      final repository = _MockRepoRepository();
      when(repository.listRepos).thenAnswer(
        (_) async => Right([
          RepoListItem.fromJson(<String, dynamic>{
            'id': 'r1',
            'name': 'Repo A',
            'info': <String, dynamic>{},
          }),
          RepoListItem.fromJson(<String, dynamic>{
            'id': 'r2',
            'name': 'Repo B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [repoRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, reposProvider);
      addTearDown(subscription.close);

      final repos = await readAsyncProvider(container, reposProvider.future);

      expect(repos, hasLength(2));
      expect(repos.first.name, 'Repo A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [repoRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, reposProvider);
      addTearDown(subscription.close);

      final repos = await readAsyncProvider(container, reposProvider.future);

      expect(repos, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockRepoRepository();
      when(repository.listRepos).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [repoRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, reposProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(reposProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(reposProvider));
    });
  });

  group('Repo detail provider', () {
    test('returns repo detail when repository succeeds', () async {
      final repository = _MockRepoRepository();
      when(() => repository.getRepo('r1')).thenAnswer(
        (_) async => Right(
          KomodoRepo.fromJson(<String, dynamic>{
            'id': 'r1',
            'name': 'Repo A',
            'config': <String, dynamic>{},
            'info': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [repoRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final repo = await readAsyncProvider(
        container,
        repoDetailProvider('r1').future,
      );

      expect(repo?.name, 'Repo A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [repoRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final repo = await readAsyncProvider(
        container,
        repoDetailProvider('r1').future,
      );

      expect(repo, isNull);
    });
  });

  group('Repo actions provider', () {
    test('clone returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [repoRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(repoActionsProvider.notifier);
      final ok = await notifier.clone('r1');

      expect(ok, isFalse);
      expectAsyncError(container.read(repoActionsProvider));
    });

    test('pull returns true on success', () async {
      final repository = _MockRepoRepository();
      when(() => repository.pullRepo('r1'))
          .thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [repoRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(repoActionsProvider.notifier);
      final ok = await notifier.pull('r1');

      expect(ok, isTrue);
      expect(container.read(repoActionsProvider).hasError, isFalse);
    });

    test('update config returns repo on success', () async {
      final repository = _MockRepoRepository();
      when(
        () => repository.updateRepoConfig(
          repoId: 'r1',
          partialConfig: {'webhook_enabled': true},
        ),
      ).thenAnswer(
        (_) async => Right(
          KomodoRepo.fromJson(<String, dynamic>{
            'id': 'r1',
            'name': 'Repo A',
            'config': <String, dynamic>{},
            'info': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [repoRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(repoActionsProvider.notifier);
      final updated = await notifier.updateRepoConfig(
        repoId: 'r1',
        partialConfig: {'webhook_enabled': true},
      );

      expect(updated?.id, 'r1');
    });
  });
}

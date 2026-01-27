import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockSyncRepository extends Mock implements SyncRepository {}

void main() {
  group('Syncs provider', () {
    test('returns syncs when repository succeeds', () async {
      final repository = _MockSyncRepository();
      when(repository.listSyncs).thenAnswer(
        (_) async => Right([
          ResourceSyncListItem.fromJson(<String, dynamic>{
            'id': 's1',
            'name': 'Sync A',
            'info': <String, dynamic>{},
          }),
          ResourceSyncListItem.fromJson(<String, dynamic>{
            'id': 's2',
            'name': 'Sync B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [syncRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, syncsProvider);
      addTearDown(subscription.close);

      final syncs = await readAsyncProvider(container, syncsProvider.future);

      expect(syncs, hasLength(2));
      expect(syncs.first.name, 'Sync A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [syncRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, syncsProvider);
      addTearDown(subscription.close);

      final syncs = await readAsyncProvider(container, syncsProvider.future);

      expect(syncs, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockSyncRepository();
      when(repository.listSyncs).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [syncRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, syncsProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(syncsProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(syncsProvider));
    });
  });

  group('Sync detail provider', () {
    test('returns sync detail when repository succeeds', () async {
      final repository = _MockSyncRepository();
      when(() => repository.getSync('s1')).thenAnswer(
        (_) async => Right(
          KomodoResourceSync.fromJson(<String, dynamic>{
            'id': 's1',
            'name': 'Sync A',
            'config': <String, dynamic>{},
            'info': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [syncRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final sync = await readAsyncProvider(
        container,
        syncDetailProvider('s1').future,
      );

      expect(sync?.name, 'Sync A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [syncRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final sync = await readAsyncProvider(
        container,
        syncDetailProvider('s1').future,
      );

      expect(sync, isNull);
    });
  });

  group('Sync actions provider', () {
    test('run returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [syncRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(syncActionsProvider.notifier);
      final ok = await notifier.run('s1');

      expect(ok, isFalse);
      expectAsyncError(container.read(syncActionsProvider));
    });

    test('run returns true on success', () async {
      final repository = _MockSyncRepository();
      when(() => repository.runSync('s1'))
          .thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [syncRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(syncActionsProvider.notifier);
      final ok = await notifier.run('s1');

      expect(ok, isTrue);
      expect(container.read(syncActionsProvider).hasError, isFalse);
    });

    test('update config returns sync on success', () async {
      final repository = _MockSyncRepository();
      when(
        () => repository.updateSyncConfig(
          syncId: 's1',
          partialConfig: {'include_resources': true},
        ),
      ).thenAnswer(
        (_) async => Right(
          KomodoResourceSync.fromJson(<String, dynamic>{
            'id': 's1',
            'name': 'Sync A',
            'config': <String, dynamic>{},
            'info': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [syncRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(syncActionsProvider.notifier);
      final updated = await notifier.updateSyncConfig(
        syncId: 's1',
        partialConfig: {'include_resources': true},
      );

      expect(updated?.id, 's1');
    });
  });
}

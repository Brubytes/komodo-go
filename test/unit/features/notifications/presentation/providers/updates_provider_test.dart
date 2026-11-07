import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/data/repositories/notifications_repository.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/shared/resources/providers/resource_activity_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

UpdateListItem _update(String id, {bool success = true}) =>
    UpdateListItem.fromJson(<String, dynamic>{
      'id': id,
      'operation': 'RunBuild',
      'success': success,
      'status': 'Complete',
    });

UpdatesPage _page(List<String> ids, int? next) =>
    UpdatesPage(updates: ids.map(_update).toList(), nextPage: next);

void main() {
  group('appendDedupedById', () {
    test('keeps the first occurrence and the order', () {
      final result = appendDedupedById<String>(
        ['a', 'b'],
        ['b', 'c', 'a', 'd'],
        (s) => s,
      );
      expect(result, ['a', 'b', 'c', 'd']);
    });
  });

  group('Updates provider', () {
    late _MockNotificationsRepository repository;

    setUp(() {
      repository = _MockNotificationsRepository();
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('activity merge then load-more never duplicates rows', () async {
      when(
        () => repository.listUpdates(page: 0),
      ).thenAnswer((_) async => Right(_page(['a', 'b'], 1)));
      when(
        () => repository.listUpdates(page: 1),
      ).thenAnswer((_) async => Right(_page(['b', 'c'], null)));

      final container = createProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(updatesProvider, (_, _) {});
      await container.read(updatesProvider.future);

      // A new update arrived: page 0 is now [n, a, b].
      when(
        () => repository.listUpdates(page: 0),
      ).thenAnswer((_) async => Right(_page(['n', 'a', 'b'], 1)));
      container.read(resourceActivityProvider.notifier).markChanged();
      await settle();
      await settle();

      var state = container.read(updatesProvider).requireValue;
      expect([for (final i in state.items) i.id], ['n', 'a', 'b']);
      expect(state.loadedPages, 1);
      expect(state.nextPage, 1);

      await container.read(updatesProvider.notifier).fetchNextPage();
      state = container.read(updatesProvider).requireValue;
      expect([for (final i in state.items) i.id], ['n', 'a', 'b', 'c']);
      expect(state.loadedPages, 2);
      expect(state.nextPage, isNull);
    });

    test('merge keeps the cursor once more pages are loaded', () async {
      when(
        () => repository.listUpdates(page: 0),
      ).thenAnswer((_) async => Right(_page(['a', 'b'], 1)));
      when(
        () => repository.listUpdates(page: 1),
      ).thenAnswer((_) async => Right(_page(['c', 'd'], 2)));

      final container = createProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(updatesProvider, (_, _) {});
      await container.read(updatesProvider.future);
      await container.read(updatesProvider.notifier).fetchNextPage();

      when(
        () => repository.listUpdates(page: 0),
      ).thenAnswer((_) async => Right(_page(['n', 'a', 'b'], 1)));
      container.read(resourceActivityProvider.notifier).markChanged();
      await settle();
      await settle();

      final state = container.read(updatesProvider).requireValue;
      expect([for (final i in state.items) i.id], ['n', 'a', 'b', 'c', 'd']);
      expect(state.nextPage, 2);
      expect(state.loadedPages, 2);
    });

    test('load-more still works after a failed refresh', () async {
      when(
        () => repository.listUpdates(page: 0),
      ).thenAnswer((_) async => Right(_page(['a'], 1)));
      when(
        () => repository.listUpdates(page: 1),
      ).thenAnswer((_) async => Right(_page(['b'], null)));

      final container = createProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(updatesProvider, (_, _) {});
      await container.read(updatesProvider.future);

      when(
        () => repository.listUpdates(page: 0),
      ).thenAnswer((_) async => const Left(Failure.server(message: 'boom')));
      await container.read(updatesProvider.notifier).refresh();
      expect(container.read(updatesProvider).hasError, isTrue);
      expect(container.read(updatesProvider).hasValue, isTrue);

      await container.read(updatesProvider.notifier).fetchNextPage();
      final state = container.read(updatesProvider).requireValue;
      expect([for (final i in state.items) i.id], ['a', 'b']);
    });
  });
}

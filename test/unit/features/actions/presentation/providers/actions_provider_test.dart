import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockActionRepository extends Mock implements ActionRepository {}

void main() {
  group('Actions provider', () {
    test('returns actions when repository succeeds', () async {
      final repository = _MockActionRepository();
      when(repository.listActions).thenAnswer(
        (_) async => Right([
          ActionListItem.fromJson(<String, dynamic>{
            'id': 'a1',
            'name': 'Action A',
            'info': <String, dynamic>{},
          }),
          ActionListItem.fromJson(<String, dynamic>{
            'id': 'a2',
            'name': 'Action B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [actionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, actionsProvider);
      addTearDown(subscription.close);

      final actions = await readAsyncProvider(container, actionsProvider.future);

      expect(actions, hasLength(2));
      expect(actions.first.name, 'Action A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [actionRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, actionsProvider);
      addTearDown(subscription.close);

      final actions = await readAsyncProvider(container, actionsProvider.future);

      expect(actions, isEmpty);
    });
  });

  group('Action detail provider', () {
    test('returns action detail when repository succeeds', () async {
      final repository = _MockActionRepository();
      when(() => repository.getAction('a1')).thenAnswer(
        (_) async => Right(
          KomodoAction.fromJson(<String, dynamic>{
            'id': 'a1',
            'name': 'Action A',
            'config': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [actionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final action = await readAsyncProvider(
        container,
        actionDetailProvider('a1').future,
      );

      expect(action?.name, 'Action A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [actionRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final action = await readAsyncProvider(
        container,
        actionDetailProvider('a1').future,
      );

      expect(action, isNull);
    });
  });

  group('Action actions provider', () {
    test('run returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [actionRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(actionActionsProvider.notifier);
      final ok = await notifier.run('a1');

      expect(ok, isFalse);
      expectAsyncError(container.read(actionActionsProvider));
    });

    test('run returns true on success', () async {
      final repository = _MockActionRepository();
      when(() => repository.runAction('a1', args: null))
          .thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [actionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(actionActionsProvider.notifier);
      final ok = await notifier.run('a1');

      expect(ok, isTrue);
      expect(container.read(actionActionsProvider).hasError, isFalse);
    });

    test('update config returns action on success', () async {
      final repository = _MockActionRepository();
      when(
        () => repository.updateActionConfig(
          actionId: 'a1',
          partialConfig: {'schedule_enabled': true},
        ),
      ).thenAnswer(
        (_) async => Right(
          KomodoAction.fromJson(<String, dynamic>{
            'id': 'a1',
            'name': 'Action A',
            'config': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [actionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(actionActionsProvider.notifier);
      final updated = await notifier.updateActionConfig(
        actionId: 'a1',
        partialConfig: {'schedule_enabled': true},
      );

      expect(updated?.id, 'a1');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockStackRepository extends Mock implements StackRepository {}

void main() {
  group('Stacks provider', () {
    test('returns stacks when repository succeeds', () async {
      final repository = _MockStackRepository();
      when(repository.listStacks).thenAnswer(
        (_) async => Right([
          StackListItem.fromJson(<String, dynamic>{
            'id': 's1',
            'name': 'Stack A',
            'info': <String, dynamic>{},
          }),
          StackListItem.fromJson(<String, dynamic>{
            'id': 's2',
            'name': 'Stack B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        stacksProvider.future,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final stacks = await readAsyncProvider(container, stacksProvider.future);

      expect(stacks, hasLength(2));
      expect(stacks.first.name, 'Stack A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, stacksProvider);
      addTearDown(subscription.close);

      final stacks = await readAsyncProvider(container, stacksProvider.future);

      expect(stacks, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockStackRepository();
      when(repository.listStacks).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, stacksProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(stacksProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(stacksProvider));
    });
  });

  group('Stack detail providers', () {
    test('returns stack detail when repository succeeds', () async {
      final repository = _MockStackRepository();
      when(() => repository.getStack('s1')).thenAnswer(
        (_) async => Right(
          KomodoStack.fromJson(
            {
              'id': 's1',
              'name': 'Stack A',
              'config': <String, dynamic>{},
              'info': <String, dynamic>{},
            },
          ),
        ),
      );

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final stack = await readAsyncProvider(
        container,
        stackDetailProvider('s1').future,
      );

      expect(stack?.name, 'Stack A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final stack = await readAsyncProvider(
        container,
        stackDetailProvider('s1').future,
      );

      expect(stack, isNull);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockStackRepository();
      when(() => repository.getStack('s1')).thenAnswer(
        (_) async => const Left(Failure.server(message: 'nope')),
      );

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(
        container,
        stackDetailProvider('s1'),
      );
      addTearDown(subscription.close);

      await expectLater(
        container.read(stackDetailProvider('s1').future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(stackDetailProvider('s1')));
    });

    test('returns services when repository succeeds', () async {
      final repository = _MockStackRepository();
      when(() => repository.listStackServices('s1')).thenAnswer(
        (_) async => Right([
          StackService.fromJson(<String, dynamic>{'service': 'web'}),
          StackService.fromJson(<String, dynamic>{'service': 'db'}),
        ]),
      );

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final services = await readAsyncProvider(
        container,
        stackServicesProvider('s1').future,
      );

      expect(services, hasLength(2));
    });

    test('returns empty services when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final services = await readAsyncProvider(
        container,
        stackServicesProvider('s1').future,
      );

      expect(services, isEmpty);
    });

    test('returns log when repository succeeds', () async {
      final repository = _MockStackRepository();
      when(
        () => repository.getStackLog(stackIdOrName: 's1'),
      ).thenAnswer(
        (_) async => Right(StackLog.fromJson(<String, dynamic>{'stdout': 'ok'})),
      );

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final log = await readAsyncProvider(
        container,
        stackLogProvider('s1').future,
      );

      expect(log?.stdout, 'ok');
    });

    test('returns null log when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final log = await readAsyncProvider(
        container,
        stackLogProvider('s1').future,
      );

      expect(log, isNull);
    });
  });

  group('Stack actions provider', () {
    test('deploy returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stackActionsProvider.notifier);
      final ok = await notifier.deploy('s1');

      expect(ok, isFalse);
      expectAsyncError(container.read(stackActionsProvider));
    });

    test('deploy returns false on failure', () async {
      final repository = _MockStackRepository();
      when(() => repository.deployStack('s1')).thenAnswer(
        (_) async => const Left(Failure.server(message: 'nope')),
      );

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stackActionsProvider.notifier);
      final ok = await notifier.deploy('s1');

      expect(ok, isFalse);
      expectAsyncError(container.read(stackActionsProvider));
    });

    test('deploy returns true on success', () async {
      final repository = _MockStackRepository();
      when(() => repository.deployStack('s1'))
          .thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stackActionsProvider.notifier);
      final ok = await notifier.deploy('s1');

      expect(ok, isTrue);
      expect(container.read(stackActionsProvider).hasError, isFalse);
    });

    test('update config returns stack on success', () async {
      final repository = _MockStackRepository();
      when(
        () => repository.updateStackConfig(
          stackId: 's1',
          partialConfig: {'auto_pull': true},
        ),
      ).thenAnswer(
        (_) async => Right(
          KomodoStack.fromJson(
            {
              'id': 's1',
              'name': 'Stack A',
              'config': <String, dynamic>{},
              'info': <String, dynamic>{},
            },
          ),
        ),
      );

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stackActionsProvider.notifier);
      final updated = await notifier.updateStackConfig(
        stackId: 's1',
        partialConfig: {'auto_pull': true},
      );

      expect(updated?.id, 's1');
    });
  });
}

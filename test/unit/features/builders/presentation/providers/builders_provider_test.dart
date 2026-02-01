import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/data/repositories/builder_repository.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockBuilderRepository extends Mock implements BuilderRepository {}

void main() {
  group('Builders provider', () {
    test('returns sorted builders when repository succeeds', () async {
      final repository = _MockBuilderRepository();
      when(repository.listBuilders).thenAnswer(
        (_) async => Right([
          BuilderListItem.fromJson(<String, dynamic>{
            'id': 'b2',
            'name': 'Builder B',
            'info': <String, dynamic>{},
          }),
          BuilderListItem.fromJson(<String, dynamic>{
            'id': 'b1',
            'name': 'Builder A',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [builderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, buildersProvider);
      addTearDown(subscription.close);

      final builders = await readAsyncProvider(
        container,
        buildersProvider.future,
      );

      expect(builders, hasLength(2));
      expect(builders.first.name, 'Builder A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [builderRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, buildersProvider);
      addTearDown(subscription.close);

      final builders = await readAsyncProvider(
        container,
        buildersProvider.future,
      );

      expect(builders, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockBuilderRepository();
      when(repository.listBuilders).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [builderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, buildersProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(buildersProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(buildersProvider));
    });
  });

  group('Builder detail provider', () {
    test('returns builder json when repository succeeds', () async {
      final repository = _MockBuilderRepository();
      when(
        () => repository.getBuilderJson(builderIdOrName: 'b1'),
      ).thenAnswer(
        (_) async => const Right(<String, dynamic>{'name': 'Builder A'}),
      );

      final container = createProviderContainer(
        overrides: [builderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final json = await readAsyncProvider(
        container,
        builderJsonProvider('b1').future,
      );

      expect(json?['name'], 'Builder A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [builderRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final json = await readAsyncProvider(
        container,
        builderJsonProvider('b1').future,
      );

      expect(json, isNull);
    });
  });

  group('Builder actions provider', () {
    test('rename returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [builderRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(builderActionsProvider.notifier);
      final ok = await notifier.rename(id: 'b1', name: 'Builder A');

      expect(ok, isFalse);
      expectAsyncError(container.read(builderActionsProvider));
    });

    test('update config returns true on success', () async {
      final repository = _MockBuilderRepository();
      when(
        () => repository.updateBuilderConfig(
          id: 'b1',
          config: {'threads': 4},
        ),
      ).thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [builderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(builderActionsProvider.notifier);
      final ok = await notifier.updateConfig(
        id: 'b1',
        config: {'threads': 4},
      );

      expect(ok, isTrue);
      expect(container.read(builderActionsProvider).hasError, isFalse);
    });
  });
}

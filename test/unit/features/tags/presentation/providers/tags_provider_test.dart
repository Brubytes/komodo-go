import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/data/repositories/tag_repository.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockTagRepository extends Mock implements TagRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(TagColor.slate);
  });

  group('Tags provider', () {
    test('returns sorted tags when repository succeeds', () async {
      final repository = _MockTagRepository();
      when(repository.listTags).thenAnswer(
        (_) async => Right([
          KomodoTag.fromJson({'id': 't2', 'name': 'beta', 'color': 'Slate'}),
          KomodoTag.fromJson({'id': 't1', 'name': 'alpha', 'color': 'Slate'}),
        ]),
      );

      final container = createProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, tagsProvider);
      addTearDown(subscription.close);

      final tags = await readAsyncProvider(container, tagsProvider.future);

      expect(tags, hasLength(2));
      expect(tags.first.name, 'alpha');
      expect(tags.last.name, 'beta');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, tagsProvider);
      addTearDown(subscription.close);

      final tags = await readAsyncProvider(container, tagsProvider.future);

      expect(tags, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockTagRepository();
      when(repository.listTags).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, tagsProvider);
      addTearDown(subscription.close);

      expect(
        () => readAsyncProvider(container, tagsProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Tag actions provider', () {
    test('create returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tagActionsProvider.notifier);
      final ok = await notifier.create(name: 'test', color: TagColor.slate);

      expect(ok, isFalse);
      expectAsyncError(container.read(tagActionsProvider));
    });

    test('create returns false on server failure', () async {
      final repository = _MockTagRepository();
      when(() => repository.createTag(name: any(named: 'name'), color: any(named: 'color')))
          .thenAnswer(
        (_) async => const Left(Failure.server(message: 'nope')),
      );

      final container = createProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tagActionsProvider.notifier);
      final ok = await notifier.create(name: 'test', color: TagColor.slate);

      expect(ok, isFalse);
      expectAsyncError(container.read(tagActionsProvider));
    });

    test('create returns true on success', () async {
      final repository = _MockTagRepository();
      when(() => repository.createTag(name: any(named: 'name'), color: any(named: 'color')))
          .thenAnswer(
        (_) async => Right(
          KomodoTag.fromJson({'id': 't1', 'name': 'test', 'color': 'Slate'}),
        ),
      );

      final container = createProviderContainer(
        overrides: [tagRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tagActionsProvider.notifier);
      final ok = await notifier.create(name: 'test', color: TagColor.slate);

      expect(ok, isTrue);
      expect(container.read(tagActionsProvider).hasError, isFalse);
    });
  });
}

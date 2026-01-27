import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockBuildRepository extends Mock implements BuildRepository {}

void main() {
  group('Builds provider', () {
    test('returns builds when repository succeeds', () async {
      final repository = _MockBuildRepository();
      when(repository.listBuilds).thenAnswer(
        (_) async => Right([
          BuildListItem.fromJson(<String, dynamic>{
            'id': 'b1',
            'name': 'Build A',
            'info': <String, dynamic>{},
          }),
          BuildListItem.fromJson(<String, dynamic>{
            'id': 'b2',
            'name': 'Build B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [buildRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        buildsProvider.future,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final builds = await readAsyncProvider(container, buildsProvider.future);

      expect(builds, hasLength(2));
      expect(builds.first.name, 'Build A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [buildRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, buildsProvider);
      addTearDown(subscription.close);

      final builds = await readAsyncProvider(container, buildsProvider.future);

      expect(builds, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockBuildRepository();
      when(repository.listBuilds).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [buildRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, buildsProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(buildsProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(buildsProvider));
    });
  });

  group('Build detail provider', () {
    test('returns build detail when repository succeeds', () async {
      final repository = _MockBuildRepository();
      when(() => repository.getBuild('b1')).thenAnswer(
        (_) async => Right(
          KomodoBuild.fromJson(
            {
              'id': 'b1',
              'name': 'Build A',
              'config': <String, dynamic>{},
              'info': <String, dynamic>{},
            },
          ),
        ),
      );

      final container = createProviderContainer(
        overrides: [buildRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final build = await readAsyncProvider(
        container,
        buildDetailProvider('b1').future,
      );

      expect(build?.name, 'Build A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [buildRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final build = await readAsyncProvider(
        container,
        buildDetailProvider('b1').future,
      );

      expect(build, isNull);
    });
  });

  group('Build actions provider', () {
    test('run returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [buildRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(buildActionsProvider.notifier);
      final ok = await notifier.run('b1');

      expect(ok, isFalse);
      expectAsyncError(container.read(buildActionsProvider));
    });

    test('run returns true on success', () async {
      final repository = _MockBuildRepository();
      when(() => repository.runBuild('b1'))
          .thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [buildRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(buildActionsProvider.notifier);
      final ok = await notifier.run('b1');

      expect(ok, isTrue);
      expect(container.read(buildActionsProvider).hasError, isFalse);
    });

    test('update config returns build on success', () async {
      final repository = _MockBuildRepository();
      when(
        () => repository.updateBuildConfig(
          buildId: 'b1',
          partialConfig: {'auto_increment_version': true},
        ),
      ).thenAnswer(
        (_) async => Right(
          KomodoBuild.fromJson(
            {
              'id': 'b1',
              'name': 'Build A',
              'config': <String, dynamic>{},
              'info': <String, dynamic>{},
            },
          ),
        ),
      );

      final container = createProviderContainer(
        overrides: [buildRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(buildActionsProvider.notifier);
      final updated = await notifier.updateBuildConfig(
        buildId: 'b1',
        partialConfig: {'auto_increment_version': true},
      );

      expect(updated?.id, 'b1');
    });
  });
}

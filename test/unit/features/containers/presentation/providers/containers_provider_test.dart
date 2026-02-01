import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:komodo_go/features/containers/presentation/providers/containers_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockContainerRepository extends Mock implements ContainerRepository {}

class _MockServerRepository extends Mock implements ServerRepository {}

void main() {
  group('Containers provider', () {
    test('returns sorted containers across servers', () async {
      final serverRepository = _MockServerRepository();
      final containerRepository = _MockContainerRepository();

      when(serverRepository.listServers).thenAnswer(
        (_) async => Right([
          Server.fromJson(<String, dynamic>{
            'id': 'srv1',
            'name': 'Server A',
            'info': <String, dynamic>{},
          }),
          Server.fromJson(<String, dynamic>{
            'id': 'srv2',
            'name': 'Server B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      when(() => containerRepository.listDockerContainers('srv1')).thenAnswer(
        (_) async => Right([
          ContainerListItem.fromJson(<String, dynamic>{'id': 'c1', 'name': 'zeta'}),
        ]),
      );

      when(() => containerRepository.listDockerContainers('srv2')).thenAnswer(
        (_) async => Right([
          ContainerListItem.fromJson(<String, dynamic>{'id': 'c2', 'name': 'alpha'}),
        ]),
      );

      final container = createProviderContainer(
        overrides: [
          serverRepositoryProvider.overrideWithValue(serverRepository),
          containerRepositoryProvider.overrideWithValue(containerRepository),
        ],
      );
      addTearDown(container.dispose);

      final result = await readAsyncProvider(
        container,
        containersProvider.future,
      );

      expect(result.items, hasLength(2));
      expect(result.items.first.container.name, 'alpha');
      expect(result.items.last.container.name, 'zeta');
      expect(result.errors, isEmpty);
    });

    test('collects errors when a server fails', () async {
      final serverRepository = _MockServerRepository();
      final containerRepository = _MockContainerRepository();

      when(serverRepository.listServers).thenAnswer(
        (_) async => Right([
          Server.fromJson(<String, dynamic>{
            'id': 'srv1',
            'name': 'Server A',
            'info': <String, dynamic>{},
          }),
          Server.fromJson(<String, dynamic>{
            'id': 'srv2',
            'name': 'Server B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      when(() => containerRepository.listDockerContainers('srv1')).thenAnswer(
        (_) async => const Left(Failure.server(message: 'nope')),
      );

      when(() => containerRepository.listDockerContainers('srv2')).thenAnswer(
        (_) async => Right([
          ContainerListItem.fromJson(<String, dynamic>{'id': 'c2', 'name': 'alpha'}),
        ]),
      );

      final container = createProviderContainer(
        overrides: [
          serverRepositoryProvider.overrideWithValue(serverRepository),
          containerRepositoryProvider.overrideWithValue(containerRepository),
        ],
      );
      addTearDown(container.dispose);

      final result = await readAsyncProvider(
        container,
        containersProvider.future,
      );

      expect(result.items, hasLength(1));
      expect(result.errors, hasLength(1));
      expect(result.errors.first.serverId, 'srv1');
    });

    test('returns empty result when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [containerRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final result = await readAsyncProvider(
        container,
        containersProvider.future,
      );

      expect(result.items, isEmpty);
      expect(result.errors, isEmpty);
    });
  });

  group('Container actions provider', () {
    test('stop returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [containerRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(containerActionsProvider.notifier);
      final ok = await notifier.stop(
        serverIdOrName: 'srv1',
        containerIdOrName: 'c1',
      );

      expect(ok, isFalse);
      expectAsyncError(container.read(containerActionsProvider));
    });

    test('restart returns true on success', () async {
      final repository = _MockContainerRepository();
      when(
        () => repository.restartContainer(
          serverIdOrName: 'srv1',
          containerIdOrName: 'c1',
        ),
      ).thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [containerRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(containerActionsProvider.notifier);
      final ok = await notifier.restart(
        serverIdOrName: 'srv1',
        containerIdOrName: 'c1',
      );

      expect(ok, isTrue);
      expect(container.read(containerActionsProvider).hasError, isFalse);
    });
  });
}

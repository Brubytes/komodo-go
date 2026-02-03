import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockDeploymentRepository extends Mock implements DeploymentRepository {}

void main() {
  group('Deployments provider', () {
    test('returns deployments when repository succeeds', () async {
      final repository = _MockDeploymentRepository();
      when(repository.listDeployments).thenAnswer(
        (_) async => Right([
          Deployment.fromJson(<String, dynamic>{
            'id': 'd1',
            'name': 'Dep A',
            'info': <String, dynamic>{},
          }),
          Deployment.fromJson(<String, dynamic>{
            'id': 'd2',
            'name': 'Dep B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [deploymentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        deploymentsProvider.future,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final deployments = await readAsyncProvider(
        container,
        deploymentsProvider.future,
      );

      expect(deployments, hasLength(2));
      expect(deployments.first.name, 'Dep A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [deploymentRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, deploymentsProvider);
      addTearDown(subscription.close);

      final deployments = await readAsyncProvider(
        container,
        deploymentsProvider.future,
      );

      expect(deployments, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockDeploymentRepository();
      when(repository.listDeployments).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [deploymentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, deploymentsProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(deploymentsProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(deploymentsProvider));
    });
  });

  group('Deployment detail provider', () {
    test('returns deployment detail when repository succeeds', () async {
      final repository = _MockDeploymentRepository();
      when(() => repository.getDeployment('d1')).thenAnswer(
        (_) async => Right(
          Deployment.fromJson(<String, dynamic>{
            'id': 'd1',
            'name': 'Dep A',
            'config': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [deploymentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final deployment = await readAsyncProvider(
        container,
        deploymentDetailProvider('d1').future,
      );

      expect(deployment?.name, 'Dep A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [deploymentRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final deployment = await readAsyncProvider(
        container,
        deploymentDetailProvider('d1').future,
      );

      expect(deployment, isNull);
    });
  });

  group('Deployment actions provider', () {
    test('start returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [deploymentRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deploymentActionsProvider.notifier);
      final ok = await notifier.start('d1');

      expect(ok, isFalse);
      expectAsyncError(container.read(deploymentActionsProvider));
    });

    test('start returns true on success', () async {
      final repository = _MockDeploymentRepository();
      when(() => repository.startDeployment('d1'))
          .thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [deploymentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deploymentActionsProvider.notifier);
      final ok = await notifier.start('d1');

      expect(ok, isTrue);
      expect(container.read(deploymentActionsProvider).hasError, isFalse);
    });

    test('update config returns deployment on success', () async {
      final repository = _MockDeploymentRepository();
      when(
        () => repository.updateDeploymentConfig(
          deploymentId: 'd1',
          partialConfig: {'auto_update': true},
        ),
      ).thenAnswer(
        (_) async => Right(
          Deployment.fromJson(<String, dynamic>{
            'id': 'd1',
            'name': 'Dep A',
            'config': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [deploymentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deploymentActionsProvider.notifier);
      final updated = await notifier.updateDeploymentConfig(
        deploymentId: 'd1',
        partialConfig: {'auto_update': true},
      );

      expect(updated?.id, 'd1');
    });
  });
}

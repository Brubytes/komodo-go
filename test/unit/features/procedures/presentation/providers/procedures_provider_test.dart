import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockProcedureRepository extends Mock implements ProcedureRepository {}

void main() {
  group('Procedures provider', () {
    test('returns procedures when repository succeeds', () async {
      final repository = _MockProcedureRepository();
      when(repository.listProcedures).thenAnswer(
        (_) async => Right([
          ProcedureListItem.fromJson(<String, dynamic>{
            'id': 'p1',
            'name': 'Proc A',
            'info': <String, dynamic>{},
          }),
          ProcedureListItem.fromJson(<String, dynamic>{
            'id': 'p2',
            'name': 'Proc B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [procedureRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, proceduresProvider);
      addTearDown(subscription.close);

      final procedures = await readAsyncProvider(
        container,
        proceduresProvider.future,
      );

      expect(procedures, hasLength(2));
      expect(procedures.first.name, 'Proc A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [procedureRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, proceduresProvider);
      addTearDown(subscription.close);

      final procedures = await readAsyncProvider(
        container,
        proceduresProvider.future,
      );

      expect(procedures, isEmpty);
    });
  });

  group('Procedure detail provider', () {
    test('returns procedure detail when repository succeeds', () async {
      final repository = _MockProcedureRepository();
      when(() => repository.getProcedure('p1')).thenAnswer(
        (_) async => Right(
          KomodoProcedure.fromJson(
            {'id': 'p1', 'name': 'Proc A', 'config': <String, dynamic>{}},
          ),
        ),
      );

      final container = createProviderContainer(
        overrides: [procedureRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final procedure = await readAsyncProvider(
        container,
        procedureDetailProvider('p1').future,
      );

      expect(procedure?.name, 'Proc A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [procedureRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final procedure = await readAsyncProvider(
        container,
        procedureDetailProvider('p1').future,
      );

      expect(procedure, isNull);
    });
  });

  group('Procedure actions provider', () {
    test('run returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [procedureRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(procedureActionsProvider.notifier);
      final ok = await notifier.run('p1');

      expect(ok, isFalse);
      expectAsyncError(container.read(procedureActionsProvider));
    });

    test('run returns true on success', () async {
      final repository = _MockProcedureRepository();
      when(() => repository.runProcedure('p1'))
          .thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [procedureRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(procedureActionsProvider.notifier);
      final ok = await notifier.run('p1');

      expect(ok, isTrue);
      expect(container.read(procedureActionsProvider).hasError, isFalse);
    });

    test('update config returns procedure on success', () async {
      final repository = _MockProcedureRepository();
      when(
        () => repository.updateProcedureConfig(
          procedureId: 'p1',
          partialConfig: {'schedule_enabled': true},
        ),
      ).thenAnswer(
        (_) async => Right(
          KomodoProcedure.fromJson(
            {'id': 'p1', 'name': 'Proc A', 'config': <String, dynamic>{}},
          ),
        ),
      );

      final container = createProviderContainer(
        overrides: [procedureRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(procedureActionsProvider.notifier);
      final updated = await notifier.updateProcedureConfig(
        procedureId: 'p1',
        partialConfig: {'schedule_enabled': true},
      );

      expect(updated?.id, 'p1');
    });
  });
}

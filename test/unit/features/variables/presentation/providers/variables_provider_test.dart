import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/variables/data/models/variable.dart';
import 'package:komodo_go/features/variables/data/repositories/variable_repository.dart';
import 'package:komodo_go/features/variables/presentation/providers/variables_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockVariableRepository extends Mock implements VariableRepository {}

void main() {
  group('Variables provider', () {
    test('returns variables when repository succeeds', () async {
      final repository = _MockVariableRepository();
      when(repository.listVariables).thenAnswer(
        (_) async => Right([
          KomodoVariable.fromJson(<String, dynamic>{
            'name': 'VAR_A',
            'value': '1',
          }),
          KomodoVariable.fromJson(<String, dynamic>{
            'name': 'VAR_B',
            'value': '2',
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [variableRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, variablesProvider);
      addTearDown(subscription.close);

      final variables = await readAsyncProvider(
        container,
        variablesProvider.future,
      );

      expect(variables, hasLength(2));
      expect(variables.first.name, 'VAR_A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [variableRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, variablesProvider);
      addTearDown(subscription.close);

      final variables = await readAsyncProvider(
        container,
        variablesProvider.future,
      );

      expect(variables, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockVariableRepository();
      when(repository.listVariables).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [variableRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, variablesProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(variablesProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(variablesProvider));
    });
  });

  group('Variable actions provider', () {
    test('create returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [variableRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(variableActionsProvider.notifier);
      final ok = await notifier.create(
        name: 'VAR_A',
        value: '1',
        description: 'desc',
        isSecret: false,
      );

      expect(ok, isFalse);
      expectAsyncError(container.read(variableActionsProvider));
    });

    test('create returns false on server failure', () async {
      final repository = _MockVariableRepository();
      when(
        () => repository.createVariable(
          name: 'VAR_A',
          value: '1',
          description: 'desc',
          isSecret: false,
        ),
      ).thenAnswer(
        (_) async => const Left(Failure.server(message: 'nope')),
      );

      final container = createProviderContainer(
        overrides: [variableRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(variableActionsProvider.notifier);
      final ok = await notifier.create(
        name: 'VAR_A',
        value: '1',
        description: 'desc',
        isSecret: false,
      );

      expect(ok, isFalse);
      expectAsyncError(container.read(variableActionsProvider));
    });

    test('create returns true on success', () async {
      final repository = _MockVariableRepository();
      when(
        () => repository.createVariable(
          name: 'VAR_A',
          value: '1',
          description: 'desc',
          isSecret: false,
        ),
      ).thenAnswer(
        (_) async => Right(
          KomodoVariable.fromJson(<String, dynamic>{
            'name': 'VAR_A',
            'value': '1',
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [variableRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(variableActionsProvider.notifier);
      final ok = await notifier.create(
        name: 'VAR_A',
        value: '1',
        description: 'desc',
        isSecret: false,
      );

      expect(ok, isTrue);
      expect(container.read(variableActionsProvider).hasError, isFalse);
    });

    test('delete returns true on success', () async {
      final repository = _MockVariableRepository();
      when(() => repository.deleteVariable(name: 'VAR_A')).thenAnswer(
        (_) async => Right(
          KomodoVariable.fromJson(<String, dynamic>{
            'name': 'VAR_A',
            'value': '1',
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [variableRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(variableActionsProvider.notifier);
      final ok = await notifier.delete('VAR_A');

      expect(ok, isTrue);
      expect(container.read(variableActionsProvider).hasError, isFalse);
    });

    test('update returns true when value changes', () async {
      final repository = _MockVariableRepository();
      when(
        () => repository.updateVariableValue(
          name: 'VAR_A',
          value: '2',
        ),
      ).thenAnswer(
        (_) async => Right(
          KomodoVariable.fromJson(<String, dynamic>{
            'name': 'VAR_A',
            'value': '2',
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [variableRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(variableActionsProvider.notifier);
      final ok = await notifier.update(
        original: KomodoVariable.fromJson(<String, dynamic>{
          'name': 'VAR_A',
          'value': '1',
          'description': 'desc',
          'is_secret': false,
        }),
        value: '2',
        description: 'desc',
        isSecret: false,
      );

      expect(ok, isTrue);
      expect(container.read(variableActionsProvider).hasError, isFalse);
    });

    test('update returns false when description update fails', () async {
      final repository = _MockVariableRepository();
      when(
        () => repository.updateVariableDescription(
          name: 'VAR_A',
          description: 'new',
        ),
      ).thenAnswer(
        (_) async => const Left(Failure.server(message: 'nope')),
      );

      final container = createProviderContainer(
        overrides: [variableRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(variableActionsProvider.notifier);
      final ok = await notifier.update(
        original: KomodoVariable.fromJson(<String, dynamic>{
          'name': 'VAR_A',
          'value': '1',
          'description': 'old',
          'is_secret': false,
        }),
        value: '1',
        description: 'new',
        isSecret: false,
      );

      expect(ok, isFalse);
      expectAsyncError(container.read(variableActionsProvider));
    });
  });
}

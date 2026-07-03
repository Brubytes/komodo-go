import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockStackRepository extends Mock implements StackRepository {}

void main() {
  group('StackActions lifecycle', () {
    test('deploy survives disposal while the action is in flight', () async {
      final repository = _MockStackRepository();
      final completer = Completer<Either<Failure, void>>();
      when(() => repository.deployStack('s1'))
          .thenAnswer((_) => completer.future);

      final container = createProviderContainer(
        overrides: [stackRepositoryProvider.overrideWithValue(repository)],
      );

      final notifier = container.read(stackActionsProvider.notifier);
      final pendingAction = notifier.deploy('s1');

      // Simulate the user leaving the screen (last listener unmounts and the
      // notifier is disposed) while the request is still in flight.
      container.dispose();
      completer.complete(const Right(null));

      // Without a `ref.mounted` guard this throws a StateError because the
      // notifier sets `state` after disposal.
      final ok = await pendingAction;

      expect(ok, isFalse);
    });
  });
}

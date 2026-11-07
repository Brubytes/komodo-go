import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/shared/resources/providers/resource_activity_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/provider_test_templates.dart';

class _MockBuildRepository extends Mock implements BuildRepository {}

BuildListItem _build(String id) => BuildListItem.fromJson(<String, dynamic>{
  'id': id,
  'name': 'Build $id',
  'info': <String, dynamic>{},
});

void main() {
  test('activity pulse refreshes a provider and keeps its value', () async {
    final repository = _MockBuildRepository();
    when(repository.listBuilds).thenAnswer((_) async => Right([_build('a')]));

    final container = createProviderContainer(
      overrides: [buildRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final states = <AsyncValue<List<BuildListItem>>>[];
    final subscription = container.listen(
      buildsProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await readAsyncProvider(container, buildsProvider.future);
    states.clear();

    // Hold the second fetch open so the in-flight state can be inspected.
    final gate = Completer<Either<Failure, List<BuildListItem>>>();
    when(repository.listBuilds).thenAnswer((_) => gate.future);

    container
        .read(resourceActivityProvider.notifier)
        .markChanged(scopes: {ActivityScope.builds});
    await Future<void>.delayed(Duration.zero);

    final inFlight = container.read(buildsProvider);
    expect(inFlight.isRefreshing, isTrue, reason: 'must be a refresh');
    expect(inFlight.isReloading, isFalse, reason: 'must not be a reload');
    expect(inFlight.value, hasLength(1), reason: 'value is retained');

    gate.complete(Right([_build('a'), _build('b')]));
    await readAsyncProvider(container, buildsProvider.future);
    expect(container.read(buildsProvider).value, hasLength(2));
    expect(
      states.any((s) => s.isLoading && !s.hasValue),
      isFalse,
      reason: 'never falls back to a value-less loading state',
    );
  });
}

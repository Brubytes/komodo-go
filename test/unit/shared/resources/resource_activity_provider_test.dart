import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/shared/resources/providers/resource_activity_provider.dart';

void main() {
  test('pulse only changes the counters of affected scopes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var stackBuilds = 0;
    var repoBuilds = 0;
    container
      ..listen(
        resourceScopeActivityProvider(ActivityScope.stacks),
        (_, _) => stackBuilds++,
      )
      ..listen(
        resourceScopeActivityProvider(ActivityScope.repos),
        (_, _) => repoBuilds++,
      );

    container
        .read(resourceActivityProvider.notifier)
        .markChanged(
          scopes: {ActivityScope.stacks},
        );

    await Future<void>.delayed(Duration.zero);
    expect(stackBuilds, 1);
    expect(repoBuilds, 0);
    expect(container.read(resourceAnyActivityProvider), 1);
  });

  test('null scopes pulse everything', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(resourceActivityProvider.notifier).markChanged();

    for (final scope in ActivityScope.values) {
      expect(container.read(resourceScopeActivityProvider(scope)), 1);
    }
  });

  test('follow-up pulses land at 2s and 8s only', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(resourceActivityProvider.notifier)
        ..markChanged(scopes: {ActivityScope.builds});
      expect(notifier.state.versionOf(ActivityScope.builds), 1);

      async.elapse(const Duration(seconds: 1));
      expect(notifier.state.versionOf(ActivityScope.builds), 1);
      async.elapse(const Duration(seconds: 1));
      expect(notifier.state.versionOf(ActivityScope.builds), 2);
      async.elapse(const Duration(seconds: 6));
      expect(notifier.state.versionOf(ActivityScope.builds), 3);
      async.elapse(const Duration(seconds: 60));
      expect(notifier.state.versionOf(ActivityScope.builds), 3);
      expect(notifier.state.versionOf(ActivityScope.repos), 0);
    });
  });
}

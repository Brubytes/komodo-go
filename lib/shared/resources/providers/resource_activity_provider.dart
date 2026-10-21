import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';

/// Which family of resources an activity pulse concerns. Watchers only react
/// to the scopes they care about instead of refetching on every action.
enum ActivityScope {
  servers,
  stacks,
  deployments,
  builds,
  repos,
  procedures,
  actions,
  syncs,
  containers,
}

/// Versioned counters: [total] bumps on every pulse, [versions] per scope.
@immutable
class ResourceActivity {
  const ResourceActivity({this.total = 0, this.versions = const {}});

  final int total;
  final Map<ActivityScope, int> versions;

  int versionOf(ActivityScope scope) => versions[scope] ?? 0;

  ResourceActivity bump(Set<ActivityScope> scopes) {
    final next = {...versions};
    for (final scope in scopes) {
      next[scope] = (next[scope] ?? 0) + 1;
    }
    return ResourceActivity(total: total + 1, versions: next);
  }
}

/// A lightweight signal that resource data may have changed on Komodo.
///
/// Execute RPCs can return before derived list/detail state has settled. The
/// immediate pulse refreshes promptly, the follow-ups reconcile async state
/// transitions. Pulses carry the affected [ActivityScope]s; `null` means all.
final resourceActivityProvider =
    NotifierProvider<ResourceActivityNotifier, ResourceActivity>(
      ResourceActivityNotifier.new,
    );

/// Counter for one scope; only changes when that scope is pulsed.
final Provider<int> Function(ActivityScope) resourceScopeActivityProvider =
    Provider.family<int, ActivityScope>(
      (ref, scope) => ref.watch(
        resourceActivityProvider.select(
          (activity) => activity.versionOf(scope),
        ),
      ),
    );

/// Counter that changes on every pulse (activity feeds).
final Provider<int> resourceAnyActivityProvider = Provider<int>(
  (ref) => ref.watch(
    resourceActivityProvider.select((activity) => activity.total),
  ),
);

class ResourceActivityNotifier extends Notifier<ResourceActivity> {
  /// Delays of the follow-up pulses after the immediate one. Docker stop can
  /// take a few seconds of graceful shutdown, so the last pulse lands later.
  @visibleForTesting
  static const followUps = [Duration(seconds: 2), Duration(seconds: 8)];

  final List<Timer> _timers = <Timer>[];

  @override
  ResourceActivity build() {
    ref.onDispose(() {
      for (final timer in _timers) {
        timer.cancel();
      }
    });
    return const ResourceActivity();
  }

  void markChanged({Set<ActivityScope>? scopes}) {
    final affected = scopes ?? ActivityScope.values.toSet();
    state = state.bump(affected);
    for (final delay in followUps) {
      _schedulePulse(delay, affected);
    }
  }

  void _schedulePulse(Duration delay, Set<ActivityScope> scopes) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      state = state.bump(scopes);
    });
    _timers.add(timer);
  }
}

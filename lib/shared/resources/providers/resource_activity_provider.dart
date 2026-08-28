import 'dart:async';

import 'package:riverpod/riverpod.dart';

/// A lightweight signal that resource data may have changed on Komodo.
///
/// Execute RPCs can return before derived list/detail state has settled. The
/// immediate pulse refreshes activity feeds promptly, while the follow-up
/// pulses reconcile resource state once Komodo has finished updating it.
final resourceActivityProvider =
    NotifierProvider<ResourceActivityNotifier, int>(
      ResourceActivityNotifier.new,
    );

class ResourceActivityNotifier extends Notifier<int> {
  final List<Timer> _timers = <Timer>[];

  @override
  int build() {
    ref.onDispose(() {
      for (final timer in _timers) {
        timer.cancel();
      }
    });
    return 0;
  }

  void markChanged() {
    state++;
    _schedulePulse(const Duration(seconds: 1));
    _schedulePulse(const Duration(seconds: 3));
  }

  void _schedulePulse(Duration delay) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      state++;
    });
    _timers.add(timer);
  }
}

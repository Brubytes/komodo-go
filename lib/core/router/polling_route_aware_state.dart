import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/network/network_status.dart';
import 'package:komodo_go/core/router/route_observer.dart';

abstract class PollingRouteAwareState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T>
    with RouteAware, WidgetsBindingObserver {
  bool isRouteVisible = true;
  AppLifecycleState lifecycleState = AppLifecycleState.resumed;

  /// Throttles timer ticks on metered connections (see [shouldRunPollTick]).
  final PollGate pollGate = PollGate();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Re-sync timers when the device goes offline or comes back.
    ref.listenManual<NetworkStatus>(networkStatusProvider, (previous, next) {
      if (previous?.isOffline != next.isOffline) onVisibilityChanged();
    });
  }

  @override
  void dispose() {
    for (final observer in allAppRouteObservers) {
      observer.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      // Subscribe to all observers: only the one attached to this widget's
      // navigator (root or shell branch) will deliver callbacks.
      for (final observer in allAppRouteObservers) {
        observer.subscribe(this, route);
      }
    }
  }

  @override
  void didPush() {
    isRouteVisible = true;
    onVisibilityChanged();
  }

  @override
  void didPopNext() {
    isRouteVisible = true;
    onVisibilityChanged();
  }

  @override
  void didPushNext() {
    isRouteVisible = false;
    onVisibilityChanged();
  }

  @override
  void didPop() {
    isRouteVisible = false;
    onVisibilityChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    lifecycleState = state;
    onVisibilityChanged();
  }

  @protected
  void onVisibilityChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool shouldPoll({required bool isActiveTab, bool enabled = true}) {
    return enabled &&
        isActiveTab &&
        isRouteVisible &&
        lifecycleState == AppLifecycleState.resumed &&
        !ref.read(networkStatusProvider).isOffline;
  }

  /// Call from each periodic timer tick: false while offline, and on
  /// cellular only every third tick runs (3x the effective interval).
  bool shouldRunPollTick() =>
      pollGate.shouldRun(ref.read(networkStatusProvider));
}

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'route_observer.dart';

abstract class PollingRouteAwareState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> with RouteAware, WidgetsBindingObserver {
  bool isRouteVisible = true;
  AppLifecycleState lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
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
        lifecycleState == AppLifecycleState.resumed;
  }
}

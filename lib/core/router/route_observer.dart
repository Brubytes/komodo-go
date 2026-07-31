import 'package:flutter/widgets.dart';

/// Route observer attached to the root navigator.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// One observer per `StatefulShellBranch` navigator.
///
/// A [NavigatorObserver] can only be attached to a single navigator, so the
/// root observer never sees pushes/pops that happen inside the shell branch
/// navigators — each branch needs its own instance.
final List<RouteObserver<ModalRoute<void>>> appShellBranchObservers =
    List<RouteObserver<ModalRoute<void>>>.unmodifiable(
      List<RouteObserver<ModalRoute<void>>>.generate(
        5,
        (_) => RouteObserver<ModalRoute<void>>(),
      ),
    );

/// Every observer a route-aware widget should subscribe to; only the observer
/// attached to the widget's own navigator delivers callbacks, subscriptions
/// on the others are inert.
List<RouteObserver<ModalRoute<void>>> get allAppRouteObservers => [
  appRouteObserver,
  ...appShellBranchObservers,
];

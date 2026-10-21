import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_status.g.dart';

/// Coarse view of the device connection used to throttle background polling.
@immutable
class NetworkStatus {
  const NetworkStatus({this.isOffline = false, this.isCellular = false});

  /// Maps connectivity_plus results onto [NetworkStatus].
  ///
  /// Wi-Fi/ethernet/VPN win over cellular because they are unmetered.
  factory NetworkStatus.fromConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return const NetworkStatus(isOffline: true);
    }
    final unmetered = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.other,
    );
    final cellular = results.contains(ConnectivityResult.mobile);
    return NetworkStatus(isCellular: cellular && !unmetered);
  }

  /// Assumed state before the first connectivity report arrives.
  static const online = NetworkStatus();

  /// Interval multiplier applied to polling on metered connections.
  static const cellularMultiplier = 3;

  final bool isOffline;

  /// True when the only active transport is mobile data (metered).
  final bool isCellular;

  /// Scales [base] for this connection, or `null` when polling must pause.
  Duration? scaleInterval(Duration base) {
    if (isOffline) return null;
    return isCellular ? base * cellularMultiplier : base;
  }

  @override
  bool operator ==(Object other) =>
      other is NetworkStatus &&
      other.isOffline == isOffline &&
      other.isCellular == isCellular;

  @override
  int get hashCode => Object.hash(isOffline, isCellular);
}

/// Decides per timer tick whether a poll should run.
///
/// Timers keep ticking at their base interval; on cellular only every third
/// tick fires and while offline none do. This avoids restarting timers when
/// the connection type changes.
class PollGate {
  int _ticks = 0;

  bool shouldRun(NetworkStatus status) {
    if (status.isOffline) return false;
    _ticks++;
    if (!status.isCellular) return true;
    return _ticks % NetworkStatus.cellularMultiplier == 0;
  }
}

/// Connectivity source; overridable in tests.
@Riverpod(keepAlive: true)
Connectivity connectivity(Ref ref) => Connectivity();

/// Current [NetworkStatus]. Kept alive for the app lifetime.
@Riverpod(keepAlive: true)
class NetworkStatusNotifier extends _$NetworkStatusNotifier {
  @override
  NetworkStatus build() {
    final connectivity = ref.watch(connectivityProvider);
    final sub = connectivity.onConnectivityChanged.listen(
      (results) => state = NetworkStatus.fromConnectivity(results),
      onError: (Object _) {},
    );
    ref.onDispose(sub.cancel);
    unawaited(
      connectivity.checkConnectivity().then(
        (results) {
          if (ref.mounted) state = NetworkStatus.fromConnectivity(results);
        },
        onError: (Object _) {},
      ),
    );
    return NetworkStatus.online;
  }
}

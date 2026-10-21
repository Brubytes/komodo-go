import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/network/network_status.dart';

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.initial);

  final List<ConnectivityResult> initial;
  final controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => initial;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      controller.stream;
}

void main() {
  group('NetworkStatus.fromConnectivity', () {
    test('none or empty is offline', () {
      expect(
        NetworkStatus.fromConnectivity(const [
          ConnectivityResult.none,
        ]).isOffline,
        isTrue,
      );
      expect(NetworkStatus.fromConnectivity(const []).isOffline, isTrue);
    });

    test('mobile only is cellular', () {
      final status = NetworkStatus.fromConnectivity(const [
        ConnectivityResult.mobile,
      ]);
      expect(status.isCellular, isTrue);
      expect(status.isOffline, isFalse);
    });

    test('wifi wins over mobile', () {
      final status = NetworkStatus.fromConnectivity(const [
        ConnectivityResult.mobile,
        ConnectivityResult.wifi,
      ]);
      expect(status.isCellular, isFalse);
    });
  });

  group('interval scaling', () {
    const base = Duration(seconds: 5);

    test('unmetered keeps the interval', () {
      expect(NetworkStatus.online.scaleInterval(base), base);
    });

    test('cellular triples the interval', () {
      expect(
        const NetworkStatus(isCellular: true).scaleInterval(base),
        const Duration(seconds: 15),
      );
    });

    test('offline pauses polling', () {
      expect(const NetworkStatus(isOffline: true).scaleInterval(base), isNull);
    });
  });

  group('PollGate', () {
    test('runs every tick when unmetered', () {
      final gate = PollGate();
      expect([
        for (var i = 0; i < 6; i++) gate.shouldRun(NetworkStatus.online),
      ], everyElement(isTrue));
    });

    test('runs every third tick on cellular', () {
      final gate = PollGate();
      const cellular = NetworkStatus(isCellular: true);
      expect(
        [for (var i = 0; i < 6; i++) gate.shouldRun(cellular)],
        [false, false, true, false, false, true],
      );
    });

    test('never runs offline', () {
      final gate = PollGate();
      const offline = NetworkStatus(isOffline: true);
      expect([
        for (var i = 0; i < 4; i++) gate.shouldRun(offline),
      ], everyElement(isFalse));
    });
  });

  group('networkStatusProvider', () {
    test('follows the injected connectivity source', () async {
      final fake = _FakeConnectivity([ConnectivityResult.wifi]);
      final container = ProviderContainer(
        overrides: [connectivityProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.controller.close);

      container.listen(networkStatusProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(networkStatusProvider), NetworkStatus.online);

      fake.controller.add([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(networkStatusProvider).isCellular, isTrue);

      fake.controller.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(networkStatusProvider).isOffline, isTrue);
    });
  });
}

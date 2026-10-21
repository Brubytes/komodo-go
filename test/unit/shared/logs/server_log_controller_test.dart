import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/network/network_status.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:komodo_go/shared/logs/server_log_controller.dart';

void main() {
  test('polls every 5s by default and defaults to a 100 line tail', () {
    final controller = ServerLogController(
      loader: (_) async => const ServerLogSnapshot(),
    );
    addTearDown(controller.dispose);

    expect(controller.refreshInterval, const Duration(seconds: 5));
    expect(ServerLogController.defaultTail, 100);
  });

  test('does not poll while the app is backgrounded', () {
    fakeAsync((async) {
      var loads = 0;
      var active = false;
      final controller = ServerLogController(
        loader: (_) async {
          loads++;
          return const ServerLogSnapshot();
        },
        isAppActive: () => active,
      );
      addTearDown(controller.dispose);
      controller
        ..setAutoRefresh(value: false)
        ..setAutoRefresh(value: true);

      async.elapse(const Duration(seconds: 20));
      expect(loads, 0);

      active = true;
      async.elapse(const Duration(seconds: 5));
      expect(loads, 1);
    });
  });

  test('pauses offline and runs every third tick on cellular', () {
    fakeAsync((async) {
      var loads = 0;
      var status = const NetworkStatus(isOffline: true);
      final controller = ServerLogController(
        loader: (_) async {
          loads++;
          return const ServerLogSnapshot();
        },
        networkStatus: () => status,
        isAppActive: () => true,
      );
      addTearDown(controller.dispose);
      controller
        ..setAutoRefresh(value: false)
        ..setAutoRefresh(value: true);

      async.elapse(const Duration(seconds: 30));
      expect(loads, 0);

      status = const NetworkStatus(isCellular: true);
      async.elapse(const Duration(seconds: 30)); // 6 ticks -> 2 loads
      expect(loads, 2);
    });
  });
}

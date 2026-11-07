import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';

import '../../../../../support/fixtures.dart';

void main() {
  group('Server (captured Komodo 2.3.1 responses)', () {
    test('GetServer: info has no address, so config address is used', () {
      final server = Server.fromJson(loadKomodoFixture('get_server_populated'));

      expect(server.info?.address, '');
      expect(server.config?.address, 'https://periphery.example.com:8120');
      expect(server.address, 'https://periphery.example.com:8120');
    });

    test('GetServer: populated config and all maintenance window types', () {
      final server = Server.fromJson(loadKomodoFixture('get_server_populated'));
      final config = server.config!;

      expect(config.ignoreMounts, ['/mnt/a', '/mnt/b']);
      expect(config.sendCpuAlerts, isFalse);
      expect(config.cpuWarning, 55);
      expect(config.diskCritical, 85);
      expect(
        config.maintenanceWindows.map((w) => w.scheduleType),
        [
          MaintenanceScheduleType.daily,
          MaintenanceScheduleType.weekly,
          MaintenanceScheduleType.oneTime,
        ],
      );
      expect(config.maintenanceWindows[1].dayOfWeek, 'Monday');
      expect(config.maintenanceWindows[2].date, '2030-01-02');
    });

    test('ListServers info: 2.x container_terminals_disabled is read', () {
      final server = Server.fromJson({
        'id': 'a',
        'name': 'local',
        'info': {
          'state': 'Ok',
          'address': 'https://periphery:8120',
          'terminals_disabled': true,
          'container_terminals_disabled': true,
        },
      });

      expect(server.info?.terminalsDisabled, isTrue);
      expect(server.info?.containerExecDisabled, isTrue);
    });

    test('ListServers info: legacy container_exec_disabled still works', () {
      final server = Server.fromJson({
        'id': 'a',
        'name': 'local',
        'info': {'state': 'Ok', 'container_exec_disabled': true},
      });

      expect(server.info?.containerExecDisabled, isTrue);
    });

    test('SystemInformation reads both container terminal keys', () {
      expect(
        SystemInformation.fromJson({'container_terminals_disabled': true})
            .containerExecDisabled,
        isTrue,
      );
      expect(
        SystemInformation.fromJson({'container_exec_disabled': true})
            .containerExecDisabled,
        isTrue,
      );
      // Real GetSystemInformation 2.3.1 response carries neither flag.
      expect(
        SystemInformation.fromJson({
          'name': 'Debian GNU/Linux',
          'os': 'Linux',
          'kernel': '7.2',
          'core_count': 12,
          'logical_core_count': 12,
          'host_name': 'h',
          'cpu_brand': '',
          'cpu_arch': 'aarch64',
        }).containerExecDisabled,
        isFalse,
      );
    });
  });
}

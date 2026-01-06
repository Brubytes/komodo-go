import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';

void main() {
  group('SystemStats', () {
    test('parses payload and aggregates disk usage', () {
      final stats = SystemStats.fromJson({
        'cpu_perc': 12.5,
        'load_average': {'one': 0.1, 'five': 0.2, 'fifteen': 0.3},
        'mem_free_gb': 3.0,
        'mem_used_gb': 5.0,
        'mem_total_gb': 8.0,
        'disks': [
          {
            'mount': '/',
            'file_system': 'ext4',
            'used_gb': 10.0,
            'total_gb': 20.0,
          },
          {
            'mount': '/data',
            'file_system': 'ext4',
            'used_gb': 5.0,
            'total_gb': 10.0,
          },
        ],
        'network_ingress_bytes': 1000.0,
        'network_egress_bytes': 2000.0,
        'polling_rate': '1-sec',
        'refresh_ts': 123,
        'refresh_list_ts': 124,
      });

      expect(stats.cpuPercent, 12.5);
      expect(stats.loadAverage?.one, 0.1);
      expect(stats.memTotalGb, 8.0);
      expect(stats.memUsedGb, 5.0);
      expect(stats.memPercent, closeTo(62.5, 0.0001));

      expect(stats.diskTotalGb, 30.0);
      expect(stats.diskUsedGb, 15.0);
      expect(stats.diskPercent, closeTo(50.0, 0.0001));
    });
  });
}

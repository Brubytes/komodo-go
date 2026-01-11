import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';

void main() {
  group('AlerterDetail', () {
    test('parses standard payload shape', () {
      final detail = AlerterDetail.fromApiJson({
        '_id': {r'$oid': 'alerter-1'},
        'name': 'test',
        'updated_at': 1767970669029,
        'config': {
          'enabled': false,
          'endpoint': {
            'type': 'Slack',
            'params': {'url': 'http://localhost:7000'}
          },
          'alert_types': ['ServerCpu', 'ServerMem'],
          'resources': [
            {'type': 'Build', 'id': 'b1'},
            {'type': 'Alerter', 'id': 'a1'}
          ],
          'except_resources': [
            {'type': 'Build', 'id': 'b1'}
          ],
          'maintenance_windows': [
            {
              'name': 'Test',
              'description': 'asdf',
              'schedule_type': 'Daily',
              'day_of_week': '',
              'date': '',
              'hour': 5,
              'minute': 8,
              'duration_minutes': 60,
              'timezone': 'UTC',
              'enabled': true
            }
          ],
        },
      });

      expect(detail.name, 'test');
      expect(detail.updatedAt, '1767970669029');
      expect(detail.config.enabled, isFalse);
      expect(detail.config.endpoint?.type, 'Slack');
      expect(detail.config.endpoint?.url, 'http://localhost:7000');
      expect(detail.config.alertTypes, ['ServerCpu', 'ServerMem']);
      expect(detail.config.resources.length, 2);
      expect(detail.config.exceptResources.length, 1);
      expect(detail.config.maintenanceWindows.first.name, 'Test');
      expect(detail.config.maintenanceWindows.first.hour, 5);
    });

    test('parses alternate endpoint shape', () {
      final detail = AlerterDetail.fromApiJson({
        'id': 'alerter-2',
        'name': 'custom',
        'updated_at': '2024-01-01',
        'config': {
          'endpoint': {
            'Custom': {'url': 'https://example.com/hook'}
          },
        },
      });

      expect(detail.id, 'alerter-2');
      expect(detail.config.endpoint?.type, 'Custom');
      expect(detail.config.endpoint?.url, 'https://example.com/hook');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';

import '../../../../../support/fixtures.dart';

void main() {
  group('AlerterDetail (captured Komodo 2.3.1 response)', () {
    test(r'GetAlerter id is read from `_id.$oid`, not the name', () {
      final detail = AlerterDetail.fromApiJson(
        loadKomodoFixture('get_alerter_ntfy_populated'),
      );

      expect(detail.id, '6aef181156835308d22938c4');
      expect(detail.name, 'zz-audit-al-ntfy');
    });

    test('Ntfy endpoint, filters and maintenance window', () {
      final config = AlerterDetail.fromApiJson(
        loadKomodoFixture('get_alerter_ntfy_populated'),
      ).config;

      expect(config.endpoint?.type, 'Ntfy');
      expect(config.endpoint?.url, 'https://n.example.com/t');
      expect(config.endpoint?.email, 'x@y.z');
      expect(config.alertTypes, ['BuildFailed']);
      expect(config.resources.single.variant, 'Stack');
      expect(config.exceptResources.single.value, 'x');
      expect(config.maintenanceWindows.single.scheduleType, 'Weekly');
      expect(config.maintenanceWindows.single.dayOfWeek, 'Friday');
    });
  });
}

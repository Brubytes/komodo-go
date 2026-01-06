import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';

void main() {
  group('Procedure', () {
    test('parses list item payload (ProcedureListItem)', () {
      final procedure = ProcedureListItem.fromJson({
        'id': 'p1',
        'name': 'nightly',
        'info': {
          'stages': 3,
          'state': 'Ok',
          'last_run_at': 1,
        },
      });

      expect(procedure.id, 'p1');
      expect(procedure.name, 'nightly');
      expect(procedure.info.stages, 3);
      expect(procedure.info.state, ProcedureState.ok);
    });

    test('parses detail payload (Procedure)', () {
      final procedure = KomodoProcedure.fromJson({
        '_id': {r'$oid': 'abc123'},
        'name': 'nightly',
        'config': {
          'schedule_format': 'Cron',
          'schedule': '0 0 * * *',
          'schedule_enabled': true,
          'stages': [
            {
              'name': 'stage 1',
              'enabled': true,
              'executions': [
                {'enabled': true, 'execution': {'type': 'RunBuild'}},
              ],
            },
          ],
          'webhook_enabled': false,
        },
      });

      expect(procedure.id, 'abc123');
      expect(procedure.config.scheduleFormat, ScheduleFormat.cron);
      expect(procedure.config.stages.length, 1);
      expect(procedure.config.stages.first.executions.length, 1);
    });
  });
}


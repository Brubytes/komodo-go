import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';

void main() {
  group('Action', () {
    test('parses list item payload (ActionListItem)', () {
      final action = ActionListItem.fromJson({
        'id': 'a1',
        'name': 'cleanup',
        'info': {'state': 'Ok', 'last_run_at': 1, 'next_scheduled_run': 2},
      });

      expect(action.id, 'a1');
      expect(action.name, 'cleanup');
      expect(action.info.state, ActionState.ok);
      expect(action.info.lastRunAt, 1);
      expect(action.info.nextScheduledRun, 2);
    });

    test('parses detail payload (Action)', () {
      final action = KomodoAction.fromJson({
        '_id': {r'$oid': 'abc123'},
        'name': 'cleanup',
        'config': {
          'run_at_startup': true,
          'schedule_format': 'Cron',
          'schedule': '0 0 * * *',
          'schedule_enabled': true,
          'webhook_enabled': true,
          'webhook_secret': 'secret',
          'reload_deno_deps': false,
          'file_contents': 'console.log("hello")',
          'arguments_format': 'Json',
          'arguments': '{"hello": "world"}',
        },
      });

      expect(action.id, 'abc123');
      expect(action.config.runAtStartup, isTrue);
      expect(action.config.scheduleFormat, ScheduleFormat.cron);
      expect(action.config.argumentsFormat, FileFormat.json);
      expect(action.config.webhookEnabled, isTrue);
      expect(action.config.webhookSecret, 'secret');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';

import '../../../../../support/fixtures.dart';

void main() {
  group('Action (captured Komodo 2.3.1 response)', () {
    test('GetAction: populated config parses', () {
      final action = KomodoAction.fromJson(
        loadKomodoFixture('get_action_populated'),
      );

      expect(action.config.argumentsFormat, FileFormat.yaml);
      expect(action.config.scheduleFormat, ScheduleFormat.cron);
      expect(action.config.schedule, '0 0 3 * * *');
      expect(action.config.arguments, 'a: 1\n');
      expect(action.config.reloadDenoDeps, isTrue);
    });

    test('FileFormat is written in the snake_case Core 2.x expects', () {
      expect(
        {for (final f in FileFormat.values) f: f.apiValue},
        {
          FileFormat.keyValue: 'key_value',
          FileFormat.toml: 'toml',
          FileFormat.yaml: 'yaml',
          FileFormat.json: 'json',
        },
      );
      final json = KomodoAction.fromJson(
        loadKomodoFixture('get_action_populated'),
      ).config.toJson();
      expect(json['arguments_format'], 'yaml');
    });

    test('legacy PascalCase values are still read', () {
      final config = ActionConfig.fromJson({'arguments_format': 'KeyValue'});
      expect(config.argumentsFormat, FileFormat.keyValue);
    });
  });
}

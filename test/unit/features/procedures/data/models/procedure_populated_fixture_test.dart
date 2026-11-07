import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/widgets/procedure_stages_timeline.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';

import '../../../../../support/fixtures.dart';

void main() {
  group('Procedure (captured Komodo 2.3.1 response)', () {
    test('stages with many execution types parse', () {
      final procedure = KomodoProcedure.fromJson(
        loadKomodoFixture('get_procedure_populated'),
      );

      expect(procedure.config.stages.map((s) => s.name), ['s1', 's2', 'empty']);
      expect(procedure.config.stages[1].enabled, isFalse);
      expect(procedure.config.stages[2].executions, isEmpty);
      final types = [
        for (final stage in procedure.config.stages)
          for (final e in stage.executions) parseExecution(e.execution).type,
      ];
      expect(types, containsAll(['RunBuild', 'Deploy', 'RunSync', 'Sleep']));
      expect(procedure.config.scheduleTimezone, 'Europe/Berlin');
    });

    test('execution targets resolve for every resource-bound type', () {
      final procedure = KomodoProcedure.fromJson(
        loadKomodoFixture('get_procedure_populated'),
      );
      final kinds = {
        for (final stage in procedure.config.stages)
          for (final e in stage.executions)
            parseExecution(e.execution).type: parseExecution(e.execution)
                .target
                ?.kind,
      };

      expect(kinds['RunBuild'], ResourceKind.builds);
      expect(kinds['Deploy'], ResourceKind.deployments);
      expect(kinds['DeployStack'], ResourceKind.stacks);
      expect(kinds['RunAction'], ResourceKind.actions);
      expect(kinds['PullRepo'], ResourceKind.repos);
      expect(kinds['RunSync'], ResourceKind.syncs);
      expect(kinds['StartContainer'], ResourceKind.servers);
      expect(kinds['TestAlerter'], ResourceKind.alerters);
      expect(kinds['Sleep'], isNull);
      expect(kinds['BackupCoreDatabase'], isNull);
    });
  });
}

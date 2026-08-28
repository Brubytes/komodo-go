import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/semantic_version.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/utils/alert_navigation_utils.dart';

void main() {
  group('routeForTarget', () {
    test('maps all routeable resource target types', () {
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.server, id: 's1'),
        ),
        '${AppRoutes.servers}/s1',
      );
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.stack, id: 'st1'),
        ),
        '${AppRoutes.stacks}/st1',
      );
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.deployment, id: 'd1'),
        ),
        '${AppRoutes.deployments}/d1',
      );
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.build, id: 'b1'),
        ),
        '${AppRoutes.builds}/b1',
      );
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.repo, id: 'r1'),
        ),
        '${AppRoutes.repos}/r1',
      );
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.procedure, id: 'p1'),
        ),
        '${AppRoutes.procedures}/p1',
      );
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.action, id: 'a1'),
        ),
        '${AppRoutes.actions}/a1',
      );
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.resourceSync, id: 'y1'),
        ),
        '${AppRoutes.syncs}/y1',
      );
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.alerter, id: 'al1'),
        ),
        '${AppRoutes.komodoAlerters}/al1',
      );
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.builder, id: 'bd1'),
        ),
        AppRoutes.komodoBuilders,
      );
    });

    test('includes a resolved display name for detail route titles', () {
      expect(
        routeForTarget(
          const ResourceTarget(type: ResourceTargetType.stack, id: 'st/1'),
          displayName: 'My Stack',
        ),
        '${AppRoutes.stacks}/st%2F1?name=My+Stack',
      );
    });
  });

  group('routeForAlert', () {
    test('uses explicit alert target when present', () {
      final alert = _alert(
        target: const ResourceTarget(
          type: ResourceTargetType.deployment,
          id: 'dep-1',
        ),
        payload: const AlertPayload(
          variant: 'BuildFailed',
          data: <String, dynamic>{'id': 'build-2'},
        ),
      );

      expect(routeForAlert(alert), '${AppRoutes.deployments}/dep-1');
    });

    test('falls back to payload variant mapping when target is missing', () {
      final alert = _alert(
        payload: const AlertPayload(
          variant: 'RepoBuildFailed',
          data: <String, dynamic>{'id': 'repo-2'},
        ),
      );

      expect(routeForAlert(alert), '${AppRoutes.repos}/repo-2');
    });

    test('resolves ScheduleRun alerts from resource_type + id', () {
      final alert = _alert(
        payload: const AlertPayload(
          variant: 'ScheduleRun',
          data: <String, dynamic>{
            'resource_type': 'ResourceSync',
            'id': 'sy-7',
          },
        ),
      );

      expect(routeForAlert(alert), '${AppRoutes.syncs}/sy-7');
    });

    test('returns null when alert payload is not routeable', () {
      final alert = _alert(
        payload: const AlertPayload(
          variant: 'Custom',
          data: <String, dynamic>{'message': 'x'},
        ),
      );

      expect(routeForAlert(alert), isNull);
    });
  });

  group('routeForUpdate', () {
    test('routes update to its full detail', () {
      final update = _update(
        target: const ResourceTarget(type: ResourceTargetType.action, id: 'a7'),
      );

      expect(routeForUpdate(update), '${AppRoutes.updateDetails}/u1');
    });

    test('routes updates without targets and rejects a missing id', () {
      final update = _update(target: null);
      expect(routeForUpdate(update), '${AppRoutes.updateDetails}/u1');

      final missingId = _update(target: null, id: '');
      expect(routeForUpdate(missingId), isNull);
    });
  });
}

Alert _alert({AlertPayload? payload, ResourceTarget? target}) {
  return Alert(
    id: 'alert-1',
    ts: 1,
    resolved: false,
    level: SeverityLevel.warning,
    payload:
        payload ??
        const AlertPayload(
          variant: 'ServerUnreachable',
          data: <String, dynamic>{'id': 'server-1'},
        ),
    target: target,
  );
}

UpdateListItem _update({required ResourceTarget? target, String id = 'u1'}) {
  return UpdateListItem(
    id: id,
    operation: 'RunAction',
    startTs: 1,
    success: true,
    username: 'user',
    operatorName: 'operator',
    target: target,
    status: UpdateStatus.success,
    version: const SemanticVersion(major: 0, minor: 0, patch: 0),
    otherData: '',
  );
}

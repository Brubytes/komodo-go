import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/home/home_attention_provider.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

void main() {
  final now = DateTime.utc(2026, 7, 10, 12);
  int secs(Duration ago) => now.subtract(ago).millisecondsSinceEpoch ~/ 1000;

  Server server(String id, String state) => Server.fromJson({
    'id': id,
    'name': 'srv-$id',
    'info': {'state': state},
  });

  Alert alert(
    String id, {
    required String level,
    bool resolved = false,
    Map<String, dynamic>? target,
  }) => Alert.fromJson({
    'id': id,
    'ts': secs(const Duration(hours: 1)),
    'resolved': resolved,
    'level': level,
    'target': ?target,
    'data': {
      'type': 'ServerUnreachable',
      'data': {'id': 'srv-x', 'name': 'srv-x'},
    },
  });

  UpdateListItem update(
    String id,
    Duration ago, {
    bool success = false,
    String operation = 'DeployStack',
    String status = 'Complete',
    String targetId = 's1',
  }) => UpdateListItem.fromJson({
    'id': id,
    'operation': operation,
    'start_ts': secs(ago),
    'success': success,
    'status': status,
    'target': {'type': 'Stack', 'id': targetId},
  });

  test('is clear when nothing is unhealthy', () {
    final snapshot = buildHomeAttention(
      now: now,
      servers: [server('1', 'Ok'), server('2', 'Disabled')],
      stacks: [
        const StackListItem(
          id: 's',
          name: 's',
          info: StackListItemInfo(state: StackState.running),
        ),
      ],
      alerts: [alert('a', level: 'CRITICAL', resolved: true)],
      updates: [update('u', const Duration(hours: 1), success: true)],
    );
    expect(snapshot.isClear, isTrue);
  });

  test('collects unhealthy resources with detail routes', () {
    final snapshot = buildHomeAttention(
      now: now,
      servers: [server('1', 'NotOk')],
      stacks: [
        const StackListItem(
          id: 's1',
          name: 'web',
          info: StackListItemInfo(state: StackState.unhealthy),
        ),
        const StackListItem(
          id: 'tpl',
          name: 'tpl',
          info: StackListItemInfo(state: StackState.dead),
          template: true,
        ),
      ],
      deployments: [
        const Deployment(
          id: 'd1',
          name: 'api',
          info: DeploymentListInfo(state: DeploymentState.restarting),
        ),
      ],
      actions: [
        const ActionListItem(
          id: 'a1',
          name: 'nightly',
          info: ActionListItemInfo(state: ActionState.failed),
        ),
      ],
    );

    expect(snapshot.total, 4);
    final byKind = {for (final i in snapshot.items) i.kind: i};
    expect(
      byKind[HomeAttentionKind.server]!.route,
      '/resources/servers/1?name=srv-1',
    );
    expect(
      byKind[HomeAttentionKind.stack]!.route,
      '/resources/stacks/s1?name=web',
    );
    expect(
      byKind[HomeAttentionKind.action]!.route,
      '/resources/actions/a1?name=nightly',
    );
    // Restarting is a warning, so it sorts after the critical items.
    expect(snapshot.items.last.kind, HomeAttentionKind.deployment);
    expect(snapshot.items.last.isCritical, isFalse);
  });

  test('only unresolved critical alerts count', () {
    final snapshot = buildHomeAttention(
      now: now,
      alerts: [
        alert('a', level: 'CRITICAL'),
        alert('b', level: 'WARNING'),
        alert('c', level: 'CRITICAL', resolved: true),
      ],
    );
    expect(snapshot.total, 1);
    expect(snapshot.items.single.kind, HomeAttentionKind.alert);
  });

  test('failed updates are limited to the last 24 hours', () {
    final snapshot = buildHomeAttention(
      now: now,
      updates: [
        update('recent', const Duration(hours: 3)),
        update('old', const Duration(hours: 30)),
      ],
    );
    expect(snapshot.total, 1);
    expect(
      snapshot.items.single.route,
      '/notifications/updates/recent',
    );
    expect(snapshot.items.single.updateTarget, isNotNull);
  });

  group('failed update clearing', () {
    int total(
      List<UpdateListItem> updates, {
      Set<String> dismissed = const {},
    }) => buildHomeAttention(
      now: now,
      updates: updates,
      dismissedUpdateIds: dismissed,
    ).total;

    test('newer success of same target and operation clears it', () {
      expect(
        total([
          update('f', const Duration(hours: 3)),
          update('ok', const Duration(hours: 1), success: true),
        ]),
        0,
      );
    });

    test('older success does not clear it', () {
      expect(
        total([
          update('f', const Duration(hours: 1)),
          update('ok', const Duration(hours: 3), success: true),
        ]),
        1,
      );
    });

    test('different operation or target does not clear it', () {
      expect(
        total([
          update('f', const Duration(hours: 3)),
          update(
            'ok1',
            const Duration(hours: 1),
            success: true,
            operation: 'StartStack',
          ),
          update(
            'ok2',
            const Duration(hours: 1),
            success: true,
            targetId: 's2',
          ),
        ]),
        1,
      );
    });

    test('newer in-progress run does not clear it', () {
      expect(
        total([
          update('f', const Duration(hours: 3)),
          update('run', const Duration(hours: 1), status: 'InProgress'),
        ]),
        1,
      );
    });

    test('dismissed ids are filtered', () {
      final updates = [
        update('a', const Duration(hours: 3)),
        update('b', const Duration(hours: 2), targetId: 's2'),
      ];
      expect(total(updates, dismissed: {'a'}), 1);
      expect(total(updates, dismissed: {'a', 'b'}), 0);
      final snapshot = buildHomeAttention(
        now: now,
        updates: updates,
        dismissedUpdateIds: {'a'},
      );
      expect(snapshot.items.single.updateId, 'b');
      expect(snapshot.items.single.isDismissible, isTrue);
    });
  });
}

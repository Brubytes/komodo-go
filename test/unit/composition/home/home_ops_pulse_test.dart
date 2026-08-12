import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/home/home_ops_pulse.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';

void main() {
  test('summarizes steady, transient, attention, and failure states', () {
    final snapshot = buildHomeOpsSnapshot(
      deployments: [
        _deployment('running', DeploymentState.running),
        _deployment('stopped', DeploymentState.exited),
        _deployment('failed', DeploymentState.dead),
      ],
      stacks: [
        _stack('running', StackState.running),
        _stack('deploying', StackState.deploying),
        _stack('unhealthy', StackState.unhealthy),
        _stack('unknown', StackState.unknown),
        _stack('template', StackState.running, template: true),
      ],
      builds: [_build('build', BuildState.ok)],
      repos: [_repo('repo', RepoState.pulling)],
      procedures: [_procedure('procedure', ProcedureState.running)],
      actions: [_action('action', ActionState.failed)],
      syncs: [_sync('sync', ResourceSyncState.pending)],
    );

    expect(snapshot.totalResources, 12);
    expect(snapshot.count(HomeOpsTone.healthy), 3);
    expect(snapshot.count(HomeOpsTone.active), 3);
    expect(snapshot.count(HomeOpsTone.attention), 2);
    expect(snapshot.count(HomeOpsTone.failed), 3);
    expect(snapshot.count(HomeOpsTone.unknown), 1);

    final deployments = snapshot.rows.singleWhere(
      (row) => row.title == 'Deployments',
    );
    expect(_count(deployments, 'Running'), 1);
    expect(_count(deployments, 'Stopped'), 1);
    expect(_count(deployments, 'Failed'), 1);
  });

  test('handles the exact state casing returned by the local backend', () {
    final snapshot = buildHomeOpsSnapshot(
      deployments: [
        Deployment.fromJson({
          'id': 'deployment',
          'name': 'deployment',
          'info': {'state': 'unknown'},
        }),
      ],
      stacks: [
        StackListItem.fromJson({
          'id': 'stack',
          'name': 'stack',
          'info': {'state': 'unknown'},
        }),
      ],
      builds: [
        BuildListItem.fromJson({
          'id': 'build',
          'name': 'build',
          'info': {'state': 'Ok'},
        }),
      ],
      repos: const [],
      procedures: const [],
      actions: const [],
      syncs: [
        ResourceSyncListItem.fromJson({
          'id': 'sync',
          'name': 'sync',
          'info': {'state': 'Pending'},
        }),
      ],
    );

    expect(snapshot.count(HomeOpsTone.healthy), 1);
    expect(snapshot.count(HomeOpsTone.attention), 1);
    expect(snapshot.count(HomeOpsTone.unknown), 2);
  });
}

int _count(HomeOpsRowData row, String label) =>
    row.statuses.singleWhere((status) => status.label == label).count;

Deployment _deployment(String id, DeploymentState state) => Deployment(
  id: id,
  name: id,
  info: DeploymentListInfo(state: state),
);

StackListItem _stack(
  String id,
  StackState state, {
  bool template = false,
}) => StackListItem(
  id: id,
  name: id,
  info: StackListItemInfo(state: state),
  template: template,
);

BuildListItem _build(String id, BuildState state) => BuildListItem(
  id: id,
  name: id,
  info: BuildListItemInfo(state: state),
);

RepoListItem _repo(String id, RepoState state) => RepoListItem(
  id: id,
  name: id,
  info: RepoListItemInfo(state: state),
);

ProcedureListItem _procedure(String id, ProcedureState state) =>
    ProcedureListItem(
      id: id,
      name: id,
      info: ProcedureListItemInfo(state: state),
    );

ActionListItem _action(String id, ActionState state) => ActionListItem(
  id: id,
  name: id,
  info: ActionListItemInfo(state: state),
);

ResourceSyncListItem _sync(String id, ResourceSyncState state) =>
    ResourceSyncListItem(
      id: id,
      name: id,
      info: ResourceSyncListItemInfo(state: state),
    );

import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/shared/resources/providers/resources_target_provider.dart';

enum HomeOpsTone { healthy, active, attention, failed, unknown }

class HomeOpsStatusCount {
  const HomeOpsStatusCount({
    required this.label,
    required this.count,
    required this.tone,
  });

  final String label;
  final int count;
  final HomeOpsTone tone;
}

class HomeOpsRowData {
  const HomeOpsRowData({
    required this.title,
    required this.type,
    required this.statuses,
  });

  final String title;
  final ResourceType type;
  final List<HomeOpsStatusCount> statuses;

  int get total => statuses.fold(0, (sum, status) => sum + status.count);
}

class HomeOpsSnapshot {
  const HomeOpsSnapshot(this.rows);

  final List<HomeOpsRowData> rows;

  int count(HomeOpsTone tone) => rows.fold(
    0,
    (sum, row) =>
        sum +
        row.statuses
            .where((status) => status.tone == tone)
            .fold(0, (rowSum, status) => rowSum + status.count),
  );

  int get totalResources => rows.fold(0, (sum, row) => sum + row.total);
}

HomeOpsSnapshot buildHomeOpsSnapshot({
  required List<Deployment> deployments,
  required List<StackListItem> stacks,
  required List<BuildListItem> builds,
  required List<RepoListItem> repos,
  required List<ProcedureListItem> procedures,
  required List<ActionListItem> actions,
  required List<ResourceSyncListItem> syncs,
}) {
  final deploymentStates = deployments
      .where((item) => !item.template)
      .map((item) => item.info?.state ?? DeploymentState.unknown);
  final stackStates = stacks
      .where((item) => !item.template)
      .map((item) => item.info.state);
  final buildStates = builds
      .where((item) => !item.template)
      .map((item) => item.info.state);
  final repoStates = repos
      .where((item) => !item.template)
      .map((item) => item.info.state);
  final procedureStates = procedures
      .where((item) => !item.template)
      .map((item) => item.info.state);
  final actionStates = actions
      .where((item) => !item.template)
      .map((item) => item.info.state);
  final syncStates = syncs
      .where((item) => !item.template)
      .map((item) => item.info.state);

  return HomeOpsSnapshot([
    HomeOpsRowData(
      title: 'Stacks',
      type: ResourceType.stacks,
      statuses: [
        _status('Running', HomeOpsTone.healthy, stackStates, {
          StackState.running,
        }),
        _status('In progress', HomeOpsTone.active, stackStates, {
          StackState.deploying,
          StackState.restarting,
          StackState.removing,
        }),
        _status('Stopped', HomeOpsTone.attention, stackStates, {
          StackState.paused,
          StackState.stopped,
          StackState.created,
          StackState.down,
        }),
        _status('Unhealthy', HomeOpsTone.failed, stackStates, {
          StackState.unhealthy,
          StackState.dead,
        }),
        _status('Unknown', HomeOpsTone.unknown, stackStates, {
          StackState.unknown,
        }),
      ],
    ),
    HomeOpsRowData(
      title: 'Deployments',
      type: ResourceType.deployments,
      statuses: [
        _status('Running', HomeOpsTone.healthy, deploymentStates, {
          DeploymentState.running,
        }),
        _status('In progress', HomeOpsTone.active, deploymentStates, {
          DeploymentState.deploying,
          DeploymentState.restarting,
          DeploymentState.removing,
        }),
        _status('Stopped', HomeOpsTone.attention, deploymentStates, {
          DeploymentState.created,
          DeploymentState.paused,
          DeploymentState.exited,
          DeploymentState.notDeployed,
        }),
        _status('Failed', HomeOpsTone.failed, deploymentStates, {
          DeploymentState.dead,
        }),
        _status('Unknown', HomeOpsTone.unknown, deploymentStates, {
          DeploymentState.unknown,
        }),
      ],
    ),
    HomeOpsRowData(
      title: 'Builds',
      type: ResourceType.builds,
      statuses: [
        _status('Ok', HomeOpsTone.healthy, buildStates, {BuildState.ok}),
        _status('Building', HomeOpsTone.active, buildStates, {
          BuildState.building,
        }),
        _status('Failed', HomeOpsTone.failed, buildStates, {
          BuildState.failed,
        }),
        _status('Unknown', HomeOpsTone.unknown, buildStates, {
          BuildState.unknown,
        }),
      ],
    ),
    HomeOpsRowData(
      title: 'Repos',
      type: ResourceType.repos,
      statuses: [
        _status('Ok', HomeOpsTone.healthy, repoStates, {RepoState.ok}),
        _status('Working', HomeOpsTone.active, repoStates, {
          RepoState.cloning,
          RepoState.pulling,
          RepoState.building,
        }),
        _status('Failed', HomeOpsTone.failed, repoStates, {RepoState.failed}),
        _status('Unknown', HomeOpsTone.unknown, repoStates, {
          RepoState.unknown,
        }),
      ],
    ),
    HomeOpsRowData(
      title: 'Procedures',
      type: ResourceType.procedures,
      statuses: [
        _status('Ok', HomeOpsTone.healthy, procedureStates, {
          ProcedureState.ok,
        }),
        _status('Running', HomeOpsTone.active, procedureStates, {
          ProcedureState.running,
        }),
        _status('Failed', HomeOpsTone.failed, procedureStates, {
          ProcedureState.failed,
        }),
        _status('Unknown', HomeOpsTone.unknown, procedureStates, {
          ProcedureState.unknown,
        }),
      ],
    ),
    HomeOpsRowData(
      title: 'Actions',
      type: ResourceType.actions,
      statuses: [
        _status('Ok', HomeOpsTone.healthy, actionStates, {ActionState.ok}),
        _status('Running', HomeOpsTone.active, actionStates, {
          ActionState.running,
        }),
        _status('Failed', HomeOpsTone.failed, actionStates, {
          ActionState.failed,
        }),
        _status('Unknown', HomeOpsTone.unknown, actionStates, {
          ActionState.unknown,
        }),
      ],
    ),
    HomeOpsRowData(
      title: 'Syncs',
      type: ResourceType.syncs,
      statuses: [
        _status('Ok', HomeOpsTone.healthy, syncStates, {
          ResourceSyncState.ok,
        }),
        _status('Syncing', HomeOpsTone.active, syncStates, {
          ResourceSyncState.syncing,
        }),
        _status('Pending', HomeOpsTone.attention, syncStates, {
          ResourceSyncState.pending,
        }),
        _status('Failed', HomeOpsTone.failed, syncStates, {
          ResourceSyncState.failed,
        }),
        _status('Unknown', HomeOpsTone.unknown, syncStates, {
          ResourceSyncState.unknown,
        }),
      ],
    ),
  ]);
}

HomeOpsStatusCount _status<T>(
  String label,
  HomeOpsTone tone,
  Iterable<T> states,
  Set<T> matches,
) => HomeOpsStatusCount(
  label: label,
  count: states.where(matches.contains).length,
  tone: tone,
);

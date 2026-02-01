import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';

class HomeServerListTile extends StatelessWidget {
  const HomeServerListTile({required this.server, super.key});

  final Server server;

  @override
  Widget build(BuildContext context) {
    final state = server.info?.state ?? ServerState.unknown;
    final color = switch (state) {
      ServerState.ok => Colors.green,
      ServerState.notOk => Colors.red,
      ServerState.disabled => Colors.grey,
      ServerState.unknown => Colors.orange,
    };

    return _wrapCardTile(
      ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(server.name),
        subtitle: Text(server.address),
        trailing: Icon(AppIcons.chevron),
        onTap: () => context.go(
          '${AppRoutes.servers}/${server.id}?name=${Uri.encodeComponent(server.name)}',
        ),
      ),
    );
  }
}

class HomeDeploymentListTile extends StatelessWidget {
  const HomeDeploymentListTile({required this.deployment, super.key});

  final Deployment deployment;

  @override
  Widget build(BuildContext context) {
    final state = deployment.info?.state ?? DeploymentState.unknown;
    final color = switch (state) {
      DeploymentState.deploying => Colors.blue,
      DeploymentState.running => Colors.green,
      DeploymentState.created => Colors.grey,
      DeploymentState.restarting => Colors.blue,
      DeploymentState.removing => Colors.grey,
      DeploymentState.exited => Colors.orange,
      DeploymentState.dead => Colors.red,
      DeploymentState.paused => Colors.grey,
      DeploymentState.notDeployed => Colors.grey,
      DeploymentState.unknown => Colors.orange,
    };

    final imageLabel = deployment.imageLabel;

    return _wrapCardTile(
      ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(deployment.name),
        subtitle: Text(imageLabel.isNotEmpty ? imageLabel : 'No image'),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class HomeStackListTile extends StatelessWidget {
  const HomeStackListTile({required this.stack, super.key});

  final StackListItem stack;

  @override
  Widget build(BuildContext context) {
    final state = stack.info.state;
    final color = switch (state) {
      StackState.deploying => Colors.blue,
      StackState.running => Colors.green,
      StackState.paused => Colors.grey,
      StackState.stopped => Colors.orange,
      StackState.created => Colors.grey,
      StackState.restarting => Colors.blue,
      StackState.removing => Colors.grey,
      StackState.unhealthy => Colors.red,
      StackState.down => Colors.grey,
      StackState.dead => Colors.red,
      StackState.unknown => Colors.orange,
    };

    final repo = stack.info.repo;
    final branch = stack.info.branch;
    final subtitle = repo.isNotEmpty
        ? (branch.isNotEmpty ? '$repo · $branch' : repo)
        : 'No repo';

    return _wrapCardTile(
      ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(stack.name),
        subtitle: Text(subtitle),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.stacks}/${stack.id}?name=${Uri.encodeComponent(stack.name)}',
        ),
      ),
    );
  }
}

class HomeRepoListTile extends StatelessWidget {
  const HomeRepoListTile({required this.repo, super.key});

  final RepoListItem repo;

  @override
  Widget build(BuildContext context) {
    final state = repo.info.state;
    final color = switch (state) {
      RepoState.ok => Colors.green,
      RepoState.failed => Colors.red,
      RepoState.cloning => Colors.blue,
      RepoState.pulling => Colors.blue,
      RepoState.building => Colors.orange,
      RepoState.unknown => Colors.orange,
    };

    final repoPath = repo.info.repo;
    final branch = repo.info.branch;
    final subtitle = repoPath.isNotEmpty
        ? (branch.isNotEmpty ? '$repoPath · $branch' : repoPath)
        : 'No repo';

    return _wrapCardTile(
      ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(repo.name),
        subtitle: Text(subtitle),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.repos}/${repo.id}?name=${Uri.encodeComponent(repo.name)}',
        ),
      ),
    );
  }
}

class HomeSyncListTile extends StatelessWidget {
  const HomeSyncListTile({required this.sync, super.key});

  final ResourceSyncListItem sync;

  @override
  Widget build(BuildContext context) {
    final state = sync.info.state;
    final color = switch (state) {
      ResourceSyncState.syncing => Colors.blue,
      ResourceSyncState.pending => Colors.orange,
      ResourceSyncState.ok => Colors.green,
      ResourceSyncState.failed => Colors.red,
      ResourceSyncState.unknown => Colors.orange,
    };

    final repo = sync.info.repo;
    final branch = sync.info.branch;
    final subtitle = repo.isNotEmpty
        ? (branch.isNotEmpty ? '$repo · $branch' : repo)
        : 'No repo';

    return _wrapCardTile(
      ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(sync.name),
        subtitle: Text(subtitle),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.syncs}/${sync.id}?name=${Uri.encodeComponent(sync.name)}',
        ),
      ),
    );
  }
}

class HomeBuildListTile extends StatelessWidget {
  const HomeBuildListTile({required this.buildItem, super.key});

  final BuildListItem buildItem;

  @override
  Widget build(BuildContext context) {
    final state = buildItem.info.state;
    final color = switch (state) {
      BuildState.building => Colors.blue,
      BuildState.ok => Colors.green,
      BuildState.failed => Colors.red,
      BuildState.unknown => Colors.orange,
    };

    final repo = buildItem.info.repo;
    final branch = buildItem.info.branch;
    final versionLabel = buildItem.info.version.label;
    final subtitleParts = <String>[
      if (repo.isNotEmpty) branch.isNotEmpty ? '$repo · $branch' : repo,
      if (versionLabel != '0.0.0') 'v$versionLabel',
    ];

    return _wrapCardTile(
      ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(buildItem.name),
        subtitle: subtitleParts.isEmpty
            ? const Text('No repo')
            : Text(subtitleParts.join(' · ')),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.builds}/${buildItem.id}?name=${Uri.encodeComponent(buildItem.name)}',
        ),
      ),
    );
  }
}

class HomeProcedureListTile extends StatelessWidget {
  const HomeProcedureListTile({required this.procedure, super.key});

  final ProcedureListItem procedure;

  @override
  Widget build(BuildContext context) {
    final state = procedure.info.state;
    final color = switch (state) {
      ProcedureState.running => Colors.blue,
      ProcedureState.ok => Colors.green,
      ProcedureState.failed => Colors.red,
      ProcedureState.unknown => Colors.orange,
    };

    final stages = procedure.info.stages;

    return _wrapCardTile(
      ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(procedure.name),
        subtitle: Text('$stages stages'),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.procedures}/${procedure.id}?name=${Uri.encodeComponent(procedure.name)}',
        ),
      ),
    );
  }
}

class HomeActionListTile extends StatelessWidget {
  const HomeActionListTile({required this.action, super.key});

  final ActionListItem action;

  @override
  Widget build(BuildContext context) {
    final state = action.info.state;
    final color = switch (state) {
      ActionState.running => Colors.blue,
      ActionState.ok => Colors.green,
      ActionState.failed => Colors.red,
      ActionState.unknown => Colors.orange,
    };

    final hasSchedule = action.info.nextScheduledRun != null;

    return _wrapCardTile(
      ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(action.name),
        subtitle: Text(hasSchedule ? 'Scheduled' : 'No schedule'),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.actions}/${action.id}?name=${Uri.encodeComponent(action.name)}',
        ),
      ),
    );
  }
}

Widget _wrapCardTile(Widget child) {
  final cardRadius = BorderRadius.circular(AppTokens.radiusLg);
  return AppCardSurface(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      borderRadius: cardRadius,
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

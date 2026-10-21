import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/home/dismissed_updates_provider.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/utils/alert_navigation_utils.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';

enum HomeAttentionKind {
  server,
  stack,
  deployment,
  build,
  repo,
  procedure,
  action,
  sync,
  alert,
  failedUpdate,
}

/// A single item that needs the user's attention.
@immutable
class HomeAttentionItem {
  const HomeAttentionItem({
    required this.kind,
    required this.title,
    required this.reason,
    required this.route,
    this.isCritical = true,
    this.timestamp,
    this.updateTarget,
    this.updateId,
  });

  final HomeAttentionKind kind;
  final String title;
  final String reason;

  /// Detail route to open; null when the target is unknown.
  final String? route;

  /// Critical items render in the error tone, others in the warning tone.
  final bool isCritical;
  final DateTime? timestamp;

  /// For failed updates, the target whose display name must be resolved.
  final ResourceTarget? updateTarget;

  /// For failed updates, the update id (used to dismiss it).
  final String? updateId;

  bool get isDismissible =>
      kind == HomeAttentionKind.failedUpdate && updateId != null;
}

@immutable
class HomeAttentionSnapshot {
  const HomeAttentionSnapshot(this.items);

  /// Sorted: critical first, then newest first.
  final List<HomeAttentionItem> items;

  bool get isClear => items.isEmpty;
  int get total => items.length;
}

/// How long a failed update stays relevant on the home screen.
const homeAttentionUpdateWindow = Duration(hours: 24);

String? _detailRoute(ResourceTargetType type, String id, String name) =>
    routeForTarget(
      ResourceTarget(type: type, id: id),
      displayName: name,
    );

/// Whether a newer successful run of the same operation on the same target
/// exists, which makes [failed] obsolete.
bool _supersededBySuccess(UpdateListItem failed, List<UpdateListItem> all) {
  final target = failed.target;
  if (target == null) return false;
  return all.any(
    (u) =>
        u.status == UpdateStatus.success &&
        u.operation == failed.operation &&
        u.target?.type == target.type &&
        u.target?.id == target.id &&
        u.timestamp.isAfter(failed.timestamp),
  );
}

/// Pure aggregation of everything that needs attention.
HomeAttentionSnapshot buildHomeAttention({
  required DateTime now,
  List<Server> servers = const [],
  List<StackListItem> stacks = const [],
  List<Deployment> deployments = const [],
  List<BuildListItem> builds = const [],
  List<RepoListItem> repos = const [],
  List<ProcedureListItem> procedures = const [],
  List<ActionListItem> actions = const [],
  List<ResourceSyncListItem> syncs = const [],
  List<Alert> alerts = const [],
  List<UpdateListItem> updates = const [],
  Set<String> dismissedUpdateIds = const {},
}) {
  final items = <HomeAttentionItem>[];

  for (final server in servers) {
    if (server.state == ServerState.notOk) {
      items.add(
        HomeAttentionItem(
          kind: HomeAttentionKind.server,
          title: server.name,
          reason: 'Server unreachable',
          route: _detailRoute(
            ResourceTargetType.server,
            server.id,
            server.name,
          ),
        ),
      );
    }
  }

  for (final stack in stacks.where((s) => !s.template)) {
    final reason = switch (stack.info.state) {
      StackState.unhealthy => 'Stack unhealthy',
      StackState.dead => 'Stack dead',
      StackState.restarting => 'Stack restarting',
      _ => null,
    };
    if (reason == null) continue;
    items.add(
      HomeAttentionItem(
        kind: HomeAttentionKind.stack,
        title: stack.name,
        reason: reason,
        route: _detailRoute(ResourceTargetType.stack, stack.id, stack.name),
        isCritical: stack.info.state != StackState.restarting,
      ),
    );
  }

  for (final deployment in deployments.where((d) => !d.template)) {
    final state = deployment.info?.state;
    final reason = switch (state) {
      DeploymentState.dead => 'Deployment dead',
      DeploymentState.restarting => 'Deployment restarting',
      _ => null,
    };
    if (reason == null) continue;
    items.add(
      HomeAttentionItem(
        kind: HomeAttentionKind.deployment,
        title: deployment.name,
        reason: reason,
        route: _detailRoute(
          ResourceTargetType.deployment,
          deployment.id,
          deployment.name,
        ),
        isCritical: state != DeploymentState.restarting,
      ),
    );
  }

  void addFailed({
    required HomeAttentionKind kind,
    required ResourceTargetType type,
    required String label,
    required Iterable<(String id, String name)> failed,
  }) {
    for (final (id, name) in failed) {
      items.add(
        HomeAttentionItem(
          kind: kind,
          title: name,
          reason: '$label failed',
          route: _detailRoute(type, id, name),
        ),
      );
    }
  }

  addFailed(
    kind: HomeAttentionKind.build,
    type: ResourceTargetType.build,
    label: 'Build',
    failed: [
      for (final b in builds)
        if (!b.template && b.info.state == BuildState.failed) (b.id, b.name),
    ],
  );
  addFailed(
    kind: HomeAttentionKind.repo,
    type: ResourceTargetType.repo,
    label: 'Repo',
    failed: [
      for (final r in repos)
        if (!r.template && r.info.state == RepoState.failed) (r.id, r.name),
    ],
  );
  addFailed(
    kind: HomeAttentionKind.procedure,
    type: ResourceTargetType.procedure,
    label: 'Procedure',
    failed: [
      for (final p in procedures)
        if (!p.template && p.info.state == ProcedureState.failed)
          (p.id, p.name),
    ],
  );
  addFailed(
    kind: HomeAttentionKind.action,
    type: ResourceTargetType.action,
    label: 'Action',
    failed: [
      for (final a in actions)
        if (!a.template && a.info.state == ActionState.failed) (a.id, a.name),
    ],
  );
  addFailed(
    kind: HomeAttentionKind.sync,
    type: ResourceTargetType.resourceSync,
    label: 'Sync',
    failed: [
      for (final s in syncs)
        if (!s.template && s.info.state == ResourceSyncState.failed)
          (s.id, s.name),
    ],
  );

  for (final alert in alerts) {
    if (alert.resolved || alert.level != SeverityLevel.critical) continue;
    items.add(
      HomeAttentionItem(
        kind: HomeAttentionKind.alert,
        title: alert.payload.primaryName ?? alert.payload.displayTitle,
        reason: 'Critical alert · ${alert.payload.displayTitle}',
        route: routeForAlert(alert),
        timestamp: alert.timestamp,
      ),
    );
  }

  final cutoff = now.subtract(homeAttentionUpdateWindow);
  for (final update in updates) {
    if (update.status != UpdateStatus.failed) continue;
    if (update.timestamp.isBefore(cutoff)) continue;
    if (dismissedUpdateIds.contains(update.id)) continue;
    if (_supersededBySuccess(update, updates)) continue;
    items.add(
      HomeAttentionItem(
        kind: HomeAttentionKind.failedUpdate,
        title: update.operation.isEmpty ? 'Update' : update.operation,
        reason: 'Failed update',
        route: routeForUpdate(update),
        isCritical: false,
        timestamp: update.timestamp,
        updateTarget: update.target,
        updateId: update.id,
      ),
    );
  }

  // Stable sort: critical first, then most recent first (untimed last).
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final ca = a.$2.isCritical ? 0 : 1;
      final cb = b.$2.isCritical ? 0 : 1;
      if (ca != cb) return ca - cb;
      final ta = a.$2.timestamp;
      final tb = b.$2.timestamp;
      if (ta != null && tb != null) {
        final c = tb.compareTo(ta);
        if (c != 0) return c;
      } else if (ta != null) {
        return 1;
      } else if (tb != null) {
        return -1;
      }
      return a.$1 - b.$1;
    });
  return HomeAttentionSnapshot([for (final e in indexed) e.$2]);
}

/// Aggregates the home attention list from providers the dashboard already
/// watches. Sources that fail (e.g. alerts without permission) are skipped.
final homeAttentionProvider = Provider<AsyncValue<HomeAttentionSnapshot>>((
  ref,
) {
  final servers = ref.watch(serversProvider);
  final stacks = ref.watch(stacksProvider);
  final deployments = ref.watch(deploymentsProvider);
  final builds = ref.watch(buildsProvider);
  final repos = ref.watch(reposProvider);
  final procedures = ref.watch(proceduresProvider);
  final actions = ref.watch(actionsProvider);
  final syncs = ref.watch(syncsProvider);
  final alerts = ref.watch(alertsProvider);
  final updates = ref.watch(updatesProvider);
  final dismissed = ref.watch(dismissedUpdatesProvider).asData?.value ?? {};

  final sources = <AsyncValue<dynamic>>[
    servers,
    stacks,
    deployments,
    builds,
    repos,
    procedures,
    actions,
    syncs,
    alerts,
    updates,
  ];
  if (sources.every((s) => !s.hasValue)) {
    final error = sources.where((s) => s.hasError).firstOrNull;
    if (error != null) {
      return AsyncValue.error(error.error!, error.stackTrace!);
    }
    return const AsyncValue.loading();
  }

  // Forget dismissed IDs that expired or vanished from the updates list.
  final updateItems = updates.asData?.value.items;
  if (updateItems != null && dismissed.isNotEmpty) {
    final cutoff = DateTime.now().subtract(homeAttentionUpdateWindow);
    final valid = {
      for (final u in updateItems)
        if (!u.timestamp.isBefore(cutoff)) u.id,
    };
    if (!valid.containsAll(dismissed)) {
      unawaited(
        Future.microtask(
          () => ref.read(dismissedUpdatesProvider.notifier).prune(valid),
        ),
      );
    }
  }

  return AsyncValue.data(
    buildHomeAttention(
      now: DateTime.now(),
      servers: servers.asData?.value ?? const [],
      stacks: stacks.asData?.value ?? const [],
      deployments: deployments.asData?.value ?? const [],
      builds: builds.asData?.value ?? const [],
      repos: repos.asData?.value ?? const [],
      procedures: procedures.asData?.value ?? const [],
      actions: actions.asData?.value ?? const [],
      syncs: syncs.asData?.value ?? const [],
      alerts: alerts.asData?.value.items ?? const [],
      updates: updates.asData?.value.items ?? const [],
      dismissedUpdateIds: dismissed,
    ),
  );
});

import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';

Map<String, String> resourceNameLookup({
  required List<Server> servers,
  required List<StackListItem> stacks,
  required List<Deployment> deployments,
  required List<BuildListItem> builds,
  required List<RepoListItem> repos,
  required List<ProcedureListItem> procedures,
  required List<ActionListItem> actions,
  required List<ResourceSyncListItem> syncs,
  required List<BuilderListItem> builders,
  required List<AlerterListItem> alerters,
}) {
  final out = <String, String>{};

  void addAll<T>({
    required String variant,
    required List<T> items,
    required String Function(T item) getId,
    required String Function(T item) getName,
  }) {
    for (final item in items) {
      final id = getId(item).trim();
      final name = getName(item).trim();
      if (id.isEmpty || name.isEmpty) continue;
      out['${variant.toLowerCase()}:$id'] = name;
    }
  }

  addAll<Server>(
    variant: 'Server',
    items: servers,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<StackListItem>(
    variant: 'Stack',
    items: stacks,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<Deployment>(
    variant: 'Deployment',
    items: deployments,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<BuildListItem>(
    variant: 'Build',
    items: builds,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<RepoListItem>(
    variant: 'Repo',
    items: repos,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<ProcedureListItem>(
    variant: 'Procedure',
    items: procedures,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<ActionListItem>(
    variant: 'Action',
    items: actions,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<ResourceSyncListItem>(
    variant: 'ResourceSync',
    items: syncs,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<BuilderListItem>(
    variant: 'Builder',
    items: builders,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );
  addAll<AlerterListItem>(
    variant: 'Alerter',
    items: alerters,
    getId: (item) => item.id,
    getName: (item) => item.name,
  );

  return out;
}

IconData resourceIcon(String variant) {
  final normalized = variant.trim().toLowerCase();
  return switch (normalized) {
    'system' => AppIcons.server,
    'server' => AppIcons.server,
    'stack' => AppIcons.stacks,
    'deployment' => AppIcons.deployments,
    'build' => AppIcons.builds,
    'repo' => AppIcons.repos,
    'procedure' => AppIcons.procedures,
    'action' => AppIcons.actions,
    'resourcesync' => AppIcons.syncs,
    'builder' => AppIcons.factory,
    'alerter' => AppIcons.notifications,
    _ => AppIcons.widgets,
  };
}

String resourceLabel(
  AlerterResourceTarget entry,
  Map<String, String> lookup,
) {
  final directName = entry.name?.trim();
  if (directName != null && directName.isNotEmpty) {
    return directName;
  }
  final lookupName = lookup[entry.key];
  if (lookupName != null && lookupName.trim().isNotEmpty) {
    return lookupName.trim();
  }
  return '${entry.variant} ${_shortId(entry.value)}';
}

String _shortId(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 10) return trimmed;
  final start = trimmed.substring(0, 6);
  final end = trimmed.substring(trimmed.length - 4);
  return '$start...$end';
}

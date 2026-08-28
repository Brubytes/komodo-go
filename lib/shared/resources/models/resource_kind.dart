import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

/// Identity of a Komodo resource family.
///
/// The first five values already key shared list filters. The remaining values
/// make all-resource selectors and name resolution feature-agnostic.
enum ResourceKind {
  servers('Server', 'Servers', AppIcons.server, AppTokens.resourceServers),
  stacks('Stack', 'Stacks', AppIcons.stacks, AppTokens.resourceStacks),
  deployments(
    'Deployment',
    'Deployments',
    AppIcons.deployments,
    AppTokens.resourceDeployments,
  ),
  builds('Build', 'Builds', AppIcons.builds, AppTokens.resourceBuilds),
  repos('Repo', 'Repos', AppIcons.repos, AppTokens.resourceRepos),
  procedures(
    'Procedure',
    'Procedures',
    AppIcons.procedures,
    AppTokens.resourceProcedures,
  ),
  actions('Action', 'Actions', AppIcons.actions, AppTokens.resourceActions),
  syncs('ResourceSync', 'Syncs', AppIcons.syncs, AppTokens.resourceSyncs),
  builders('Builder', 'Builders', AppIcons.factory, AppTokens.resourceActions),
  alerters(
    'Alerter',
    'Alerters',
    AppIcons.notifications,
    AppTokens.resourceServers,
  ),
  system('System', 'System', AppIcons.server, AppTokens.resourceServers),
  unknown('Resource', 'Resources', AppIcons.widgets, AppTokens.resourceServers);

  const ResourceKind(this.variant, this.label, this.icon, this.color);

  final String variant;
  final String label;
  final IconData icon;
  final Color color;
}

extension ResourceKindX on ResourceKind {
  String get singularLabel => switch (this) {
    ResourceKind.syncs => 'Sync',
    _ => variant,
  };

  static ResourceKind fromVariant(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', '');
    return switch (normalized) {
      'system' => ResourceKind.system,
      'server' => ResourceKind.servers,
      'stack' => ResourceKind.stacks,
      'deployment' => ResourceKind.deployments,
      'build' => ResourceKind.builds,
      'repo' => ResourceKind.repos,
      'procedure' => ResourceKind.procedures,
      'action' => ResourceKind.actions,
      'resourcesync' => ResourceKind.syncs,
      'builder' => ResourceKind.builders,
      'alerter' => ResourceKind.alerters,
      _ => ResourceKind.unknown,
    };
  }
}

import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'resources_tab_provider.g.dart';

enum ResourceType {
  servers('Servers', AppIcons.server, AppTokens.resourceServers),
  deployments(
    'Deployments',
    AppIcons.deployments,
    AppTokens.resourceDeployments,
  ),
  stacks('Stacks', AppIcons.stacks, AppTokens.resourceStacks),
  repos('Repos', AppIcons.repos, AppTokens.resourceRepos),
  syncs('Syncs', AppIcons.syncs, AppTokens.resourceSyncs),
  builds('Builds', AppIcons.builds, AppTokens.resourceBuilds),
  procedures('Procedures', AppIcons.procedures, AppTokens.resourceProcedures),
  actions('Actions', AppIcons.actions, AppTokens.resourceActions);

  const ResourceType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

@Riverpod(keepAlive: true)
class ResourcesTarget extends _$ResourcesTarget {
  @override
  ResourceType? build() => null;

  ResourceType? get target => state;

  set target(ResourceType? value) {
    state = value;
  }

  void clear() {
    state = null;
  }
}

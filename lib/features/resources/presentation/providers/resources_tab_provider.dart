import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

part 'resources_tab_provider.g.dart';

enum ResourceType {
  servers('Servers', AppIcons.server),
  deployments('Deployments', AppIcons.deployments),
  stacks('Stacks', AppIcons.stacks),
  repos('Repos', AppIcons.repos),
  builds('Builds', AppIcons.builds),
  procedures('Procedures', AppIcons.procedures);

  const ResourceType(this.label, this.icon);

  final String label;
  final IconData icon;
}

@Riverpod(keepAlive: true)
class ResourcesTarget extends _$ResourcesTarget {
  @override
  ResourceType? build() => null;

  void open(ResourceType target) {
    state = target;
  }

  void clear() {
    state = null;
  }
}

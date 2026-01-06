import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

part 'resources_tab_provider.g.dart';

enum ResourceType {
  servers('Servers', AppIcons.server, Colors.blue),
  deployments('Deployments', AppIcons.deployments, Colors.green),
  stacks('Stacks', AppIcons.stacks, Colors.purple),
  repos('Repos', AppIcons.repos, Colors.orange),
  builds('Builds', AppIcons.builds, Colors.teal),
  procedures('Procedures', AppIcons.procedures, Colors.indigo),
  actions('Actions', AppIcons.actions, Colors.cyan);

  const ResourceType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
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

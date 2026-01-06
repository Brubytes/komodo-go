import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'resources_tab_provider.g.dart';

enum ResourceType {
  servers('Servers', Icons.dns),
  deployments('Deploy', Icons.rocket_launch),
  stacks('Stacks', Icons.layers),
  repos('Repos', Icons.source),
  builds('Builds', Icons.build_circle),
  procedures('Procs', Icons.playlist_play);

  const ResourceType(this.label, this.icon);

  final String label;
  final IconData icon;
}

@Riverpod(keepAlive: true)
class ResourcesTab extends _$ResourcesTab {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (index < 0 || index >= ResourceType.values.length) return;
    if (state == index) return;
    state = index;
  }
}

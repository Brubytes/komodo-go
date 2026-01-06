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

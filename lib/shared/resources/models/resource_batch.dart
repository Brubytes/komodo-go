import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';

class ResourceBatchItem {
  const ResourceBatchItem({required this.id, required this.name});

  final String id;
  final String name;
}

enum ResourceBatchAction {
  deploy('Deploy', AppIcons.deployments),
  pull('Pull', Icons.download_outlined),
  start('Start', AppIcons.play),
  stop('Stop', Icons.stop_circle_outlined),
  restart('Restart', Icons.restart_alt),
  destroy('Destroy', Icons.delete_outline),
  run('Run', AppIcons.play),
  cancel('Cancel', Icons.cancel_outlined);

  const ResourceBatchAction(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ResourceBatchResult {
  const ResourceBatchResult({
    required this.item,
    required this.success,
    this.updateId,
    this.error,
  });

  final ResourceBatchItem item;
  final bool success;
  final String? updateId;
  final String? error;
}

extension ResourceBatchActionsForKind on ResourceKind {
  List<ResourceBatchAction> get batchActions => switch (this) {
    ResourceKind.stacks => const [
      ResourceBatchAction.deploy,
      ResourceBatchAction.pull,
      ResourceBatchAction.start,
      ResourceBatchAction.stop,
      ResourceBatchAction.restart,
      ResourceBatchAction.destroy,
    ],
    ResourceKind.deployments => const [
      ResourceBatchAction.deploy,
      ResourceBatchAction.pull,
      ResourceBatchAction.start,
      ResourceBatchAction.stop,
      ResourceBatchAction.restart,
      ResourceBatchAction.destroy,
    ],
    ResourceKind.builds ||
    ResourceKind.actions ||
    ResourceKind.procedures => const [
      ResourceBatchAction.run,
      ResourceBatchAction.cancel,
    ],
    ResourceKind.repos => const [
      ResourceBatchAction.pull,
      ResourceBatchAction.run,
      ResourceBatchAction.cancel,
    ],
    _ => const [],
  };
}

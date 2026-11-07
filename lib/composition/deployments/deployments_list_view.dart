import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_tag_options_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/async/refresh_helpers.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/layout/list_detail_layout.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_filters_provider.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/deployments/presentation/widgets/deployment_card.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_batch.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';
import 'package:komodo_go/shared/resources/resource_sorting.dart';

/// View displaying the list of all deployments.
class DeploymentsListView extends ConsumerWidget {
  const DeploymentsListView({this.selectedId, super.key});

  /// Id of the item open in the detail pane, highlighted in the list.
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The server-name lookup feeds search, the server filter and the cards.
    final servers = ref.watch(serversProvider).value;
    return ResourceListView<Deployment>(
      config: _deploymentsListConfig(_serverNames(servers), servers),
      selectedId: selectedId,
    );
  }
}

Map<String, String> _serverNames(List<Server>? servers) => {
  for (final server in servers ?? const <Server>[]) server.id: server.name,
};

ResourceListConfig<Deployment> _deploymentsListConfig(
  Map<String, String> serverNames,
  List<Server>? servers,
) {
  return ResourceListConfig<Deployment>(
    kind: ResourceKind.deployments,
    title: 'Deployments',
    resourceName: 'deployments',
    icon: AppIcons.deployments,
    markColor: AppTokens.resourceDeployments,
    searchFieldKey: const ValueKey('deployments_search'),
    skeletonTitle: 'Deployment name',
    skeletonSubtitle: 'registry/image:latest',
    skeletonChipLeft: 'Server',
    derivationKey: servers,
    watchList: (ref) => ref.watch(deploymentsProvider),
    watchTagOptions: (ref) => ref.watch(resourceTagOptionsProvider),
    refreshList: (ref) => refreshProviders(ref, [deploymentsProvider.future]),
    invalidateList: (ref) => ref.invalidate(deploymentsProvider),
    watchActionsState: (ref) => ref.watch(deploymentActionsProvider),
    isTemplate: (item) => item.template,
    tagsOf: (item) => item.tags,
    searchFieldsOf: (item) => [
      item.name,
      item.imageLabel,
      serverNames[item.info?.serverId] ?? '',
    ],
    nameOf: (item) => item.name,
    idOf: (item) => item.id,
    severityOf: _severityOf,
    stateLabelOf: _stateLabel,
    serverNameOf: (item) => _serverNameOf(item, serverNames),
    batchItemOf: (item) => ResourceBatchItem(id: item.id, name: item.name),
    onCreate: (context) => context.openDetail('${AppRoutes.deployments}/new'),
    extraFilters: [
      ResourceToggleFilter<Deployment>(
        label: 'Pending updates',
        activeLabel: 'Pending updates',
        icon: AppIcons.updateAvailable,
        watchEnabled: (ref) =>
            ref.watch(deploymentsPendingUpdateFilterProvider),
        setEnabled: (ref, {required enabled}) =>
            ref.read(deploymentsPendingUpdateFilterProvider.notifier).enabled =
                enabled,
        matches: (item) => item.info?.updateAvailable ?? false,
      ),
    ],
    cardBuilder: (context, ref, item, displayTags) => DeploymentCard(
      deployment: item,
      serverName: serverNames[item.info?.serverId],
      displayTags: displayTags,
      onTap: () => context.openDetail(
        '${AppRoutes.deployments}/${item.id}?name=${Uri.encodeComponent(item.name)}',
      ),
      onAction: (action) =>
          _handleDeploymentAction(context, ref, item.id, item.name, action),
    ),
  );
}

Future<void> _handleDeploymentAction(
  BuildContext context,
  WidgetRef ref,
  String deploymentId,
  String deploymentName,
  DeploymentAction action,
) async {
  if (action == DeploymentAction.destroy || action == DeploymentAction.stop) {
    final destroy = action == DeploymentAction.destroy;
    final confirmed = await confirmDestructive(
      context,
      title: destroy ? 'Destroy $deploymentName?' : 'Stop $deploymentName?',
      message: destroy
          ? 'This will stop and remove the container of "$deploymentName".'
          : 'This will stop the container of "$deploymentName".',
      confirmLabel: destroy ? 'Destroy' : 'Stop',
    );
    if (!confirmed) return;
    if (!context.mounted) return;
  }

  final actions = ref.read(deploymentActionsProvider.notifier);
  if (action == DeploymentAction.checkUpdates) {
    final available = await actions.checkForUpdate(deploymentId);
    if (!context.mounted) return;
    ref.invalidate(deploymentsProvider);
    AppSnackBar.show(
      context,
      available == null
          ? 'Image check failed. Please try again.'
          : available
          ? 'A newer image is available.'
          : 'The deployed image is up to date.',
      tone: available == null
          ? AppSnackBarTone.error
          : available
          ? AppSnackBarTone.warning
          : AppSnackBarTone.success,
    );
    return;
  }
  final success = await switch (action) {
    DeploymentAction.checkUpdates => Future<bool>.value(false),
    DeploymentAction.deploy => actions.deploy(deploymentId),
    DeploymentAction.pullImages => actions.pullImages(deploymentId),
    DeploymentAction.start => actions.start(deploymentId),
    DeploymentAction.stop => actions.stop(deploymentId),
    DeploymentAction.restart => actions.restart(deploymentId),
    DeploymentAction.pause => actions.pause(deploymentId),
    DeploymentAction.unpause => actions.unpause(deploymentId),
    DeploymentAction.destroy => actions.destroy(deploymentId),
  };

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success
          ? 'Action submitted. Check updates for the result.'
          : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}

int _severityOf(Deployment deployment) {
  final state = deployment.info?.state ?? DeploymentState.unknown;
  return switch (state) {
    DeploymentState.dead => ResourceSeverity.attention,
    DeploymentState.restarting ||
    DeploymentState.deploying ||
    DeploymentState.removing => ResourceSeverity.warning,
    DeploymentState.running =>
      (deployment.info?.updateAvailable ?? false)
          ? ResourceSeverity.warning
          : ResourceSeverity.healthy,
    DeploymentState.paused ||
    DeploymentState.created ||
    DeploymentState.exited ||
    DeploymentState.notDeployed ||
    DeploymentState.unknown => ResourceSeverity.inactive,
  };
}

String _stateLabel(Deployment deployment) =>
    resourceStateLabel(deployment.info?.state ?? DeploymentState.unknown);

String? _serverNameOf(Deployment deployment, Map<String, String> serverNames) {
  final name =
      serverNames[deployment.info?.serverId] ??
      deployment.info?.serverName ??
      '';
  return name.trim().isEmpty ? null : name.trim();
}

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
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_filters_provider.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';
import 'package:komodo_go/shared/resources/models/resource_batch.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';
import 'package:komodo_go/shared/resources/resource_sorting.dart';

/// View displaying the list of all stacks.
class StacksListView extends ConsumerWidget {
  const StacksListView({this.selectedId, super.key});

  /// Id of the item open in the detail pane, highlighted in the list.
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The server-name lookup feeds search, the server filter and the cards.
    final servers = ref.watch(serversProvider).value;
    return ResourceListView<StackListItem>(
      config: _stacksListConfig(_serverNames(servers), servers),
      selectedId: selectedId,
    );
  }
}

Map<String, String> _serverNames(List<Server>? servers) => {
  for (final server in servers ?? const <Server>[]) server.id: server.name,
};

ResourceListConfig<StackListItem> _stacksListConfig(
  Map<String, String> serverNames,
  List<Server>? servers,
) {
  return ResourceListConfig<StackListItem>(
    kind: ResourceKind.stacks,
    title: 'Stacks',
    resourceName: 'stacks',
    icon: AppIcons.stacks,
    markColor: AppTokens.resourceStacks,
    searchFieldKey: const ValueKey('stacks_search'),
    skeletonTitle: 'Stack name',
    skeletonSubtitle: 'owner/repository · main',
    skeletonChipLeft: 'Server',
    skeletonChipRight: '3 services',
    derivationKey: servers,
    watchList: (ref) => ref.watch(stacksProvider),
    watchTagOptions: (ref) => ref.watch(resourceTagOptionsProvider),
    refreshList: (ref) => refreshProviders(ref, [stacksProvider.future]),
    invalidateList: (ref) => ref.invalidate(stacksProvider),
    watchActionsState: (ref) => ref.watch(stackActionsProvider),
    isTemplate: (item) => item.template,
    tagsOf: (item) => item.tags,
    searchFieldsOf: (item) => [
      item.name,
      item.info.repo,
      item.info.branch,
      item.info.linkedRepo,
      serverNames[item.info.serverId] ?? '',
    ],
    nameOf: (item) => item.name,
    idOf: (item) => item.id,
    severityOf: _severityOf,
    stateLabelOf: _stateLabel,
    serverNameOf: (item) => _serverNameOf(item, serverNames),
    batchItemOf: (item) => ResourceBatchItem(id: item.id, name: item.name),
    onCreate: (context) => context.openDetail('${AppRoutes.stacks}/new'),
    extraFilters: [
      ResourceToggleFilter<StackListItem>(
        label: 'Pending updates',
        activeLabel: 'Pending updates',
        icon: AppIcons.updateAvailable,
        watchEnabled: (ref) => ref.watch(stacksPendingUpdateFilterProvider),
        setEnabled: (ref, {required enabled}) =>
            ref.read(stacksPendingUpdateFilterProvider.notifier).enabled =
                enabled,
        matches: (item) => item.hasPendingUpdate,
      ),
    ],
    cardBuilder: (context, ref, item, displayTags) => StackCard(
      stack: item,
      serverName: serverNames[item.info.serverId],
      displayTags: displayTags,
      onTap: () => context.openDetail(
        '${AppRoutes.stacks}/${item.id}?name=${Uri.encodeComponent(item.name)}',
      ),
      onAction: (action) =>
          _handleStackAction(context, ref, item.id, item.name, action),
    ),
  );
}

Future<void> _handleStackAction(
  BuildContext context,
  WidgetRef ref,
  String stackId,
  String stackName,
  StackAction action,
) async {
  final actions = ref.read(stackActionsProvider.notifier);
  if (action == StackAction.destroy || action == StackAction.stop) {
    final destroy = action == StackAction.destroy;
    final confirmed = await confirmDestructive(
      context,
      title: destroy ? 'Destroy $stackName?' : 'Stop $stackName?',
      message: destroy
          ? 'This will run docker compose down and remove the stack '
                'containers of "$stackName".'
          : 'This will stop all containers of "$stackName".',
      confirmLabel: destroy ? 'Destroy' : 'Stop',
    );
    if (!confirmed) return;
    if (!context.mounted) return;
  }

  if (action == StackAction.checkUpdates) {
    final services = await actions.checkForUpdates(stackId);
    if (!context.mounted) return;
    ref.invalidate(stacksProvider);
    final count = services?.where((service) => service.updateAvailable).length;
    AppSnackBar.show(
      context,
      count == null
          ? 'Image check failed. Please try again.'
          : count == 0
          ? 'All service images are up to date.'
          : '$count service image${count == 1 ? '' : 's'} can be updated.',
      tone: count == null
          ? AppSnackBarTone.error
          : count == 0
          ? AppSnackBarTone.success
          : AppSnackBarTone.warning,
    );
    return;
  }

  final success = await switch (action) {
    StackAction.checkUpdates => Future<bool>.value(false),
    StackAction.deployIfChanged => actions.deployIfChanged(stackId),
    StackAction.redeploy => actions.deploy(stackId),
    StackAction.pullImages => actions.pullImages(stackId),
    StackAction.restart => actions.restart(stackId),
    StackAction.pause => actions.pause(stackId),
    StackAction.start => actions.start(stackId),
    StackAction.stop => actions.stop(stackId),
    StackAction.destroy => actions.destroy(stackId),
  };
  if (!context.mounted) return;
  final actionError = ref.read(stackActionsProvider).asError?.error;
  final actionErrorMessage = actionError is String
      ? actionError.trim()
      : actionError?.toString().trim();
  final hasActionError =
      actionErrorMessage != null && actionErrorMessage.isNotEmpty;

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success
          ? 'Action submitted. Check updates for the result.'
          : hasActionError
          ? 'Action failed: $actionErrorMessage'
          : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}

int _severityOf(StackListItem stack) {
  final info = stack.info;
  final base = switch (info.state) {
    StackState.dead || StackState.unhealthy => ResourceSeverity.attention,
    StackState.restarting ||
    StackState.deploying ||
    StackState.removing => ResourceSeverity.warning,
    StackState.running => ResourceSeverity.healthy,
    StackState.paused ||
    StackState.stopped ||
    StackState.created ||
    StackState.down ||
    StackState.unknown => ResourceSeverity.inactive,
  };
  if (base == ResourceSeverity.attention) return base;
  if (info.state == StackState.running &&
      (stack.hasPendingUpdate ||
          info.projectMissing ||
          info.missingFiles.isNotEmpty)) {
    return ResourceSeverity.warning;
  }
  return base;
}

String _stateLabel(StackListItem stack) => resourceStateLabel(stack.info.state);

String? _serverNameOf(StackListItem stack, Map<String, String> serverNames) {
  final name = serverNames[stack.info.serverId] ?? stack.info.serverName;
  return name.trim().isEmpty ? null : name.trim();
}

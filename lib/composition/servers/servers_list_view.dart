import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_tag_options_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/async/refresh_helpers.dart';
import 'package:komodo_go/core/widgets/layout/list_detail_layout.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/servers/presentation/widgets/server_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';
import 'package:komodo_go/shared/resources/resource_sorting.dart';

/// View displaying the list of all servers.
class ServersListView extends StatelessWidget {
  const ServersListView({this.selectedId, super.key});

  /// Id of the item open in the detail pane, highlighted in the list.
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return ResourceListView<Server>(
      config: _serversListConfig,
      selectedId: selectedId,
    );
  }
}

final _serversListConfig = ResourceListConfig<Server>(
  kind: ResourceKind.servers,
  title: 'Servers',
  resourceName: 'servers',
  icon: AppIcons.server,
  markColor: AppTokens.resourceServers,
  searchFieldKey: const ValueKey('servers_search'),
  skeletonTitle: 'Server name',
  skeletonSubtitle: '192.168.0.10:8120',
  skeletonChipLeft: 'Region',
  skeletonChipRight: 'v1.0.0',
  emptyStateHint: 'Add servers in the Komodo web interface.',
  watchList: (ref) => ref.watch(serversProvider),
  watchTagOptions: (ref) => ref.watch(resourceTagOptionsProvider),
  refreshList: (ref) => refreshProviders(ref, [serversProvider.future]),
  invalidateList: (ref) => ref.invalidate(serversProvider),
  // Server config edits show their own progress; the list stays interactive.
  watchActionsState: (ref) => const AsyncValue<void>.data(null),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [
    item.name,
    item.address,
    item.description ?? '',
    item.info?.region ?? item.config?.region ?? '',
    item.info?.version ?? '',
    item.state.name,
  ],
  nameOf: (item) => item.name,
  idOf: (item) => item.id,
  severityOf: _severityOf,
  stateLabelOf: (item) => resourceStateLabel(item.state),
  onCreate: (context) => context.openDetail('${AppRoutes.servers}/new'),
  cardBuilder: (context, ref, item, displayTags) => ServerCard(
    server: item,
    displayTags: displayTags,
    onTap: () => context.openDetail(
      '${AppRoutes.servers}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
  ),
);

int _severityOf(Server server) => switch (server.state) {
  ServerState.notOk => ResourceSeverity.attention,
  ServerState.ok => ResourceSeverity.healthy,
  ServerState.disabled || ServerState.unknown => ResourceSeverity.inactive,
};

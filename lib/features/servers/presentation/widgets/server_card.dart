import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';

/// Card widget displaying server information.
class ServerCard extends StatelessWidget {
  const ServerCard({
    required this.server,
    required this.displayTags,
    this.onTap,
    super.key,
  });

  final Server server;
  final List<String> displayTags;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = server.info?.state ?? ServerState.unknown;
    final region = (server.info?.region ?? server.config?.region ?? '').trim();
    final version = (server.info?.version ?? '').trim();

    return ResourceCard(
      key: ValueKey('server_card_${server.id}'),
      title: server.name,
      subtitle: server.address,
      status: serverStatusSpec(state),
      meta: [
        if (region.isNotEmpty)
          ResourceIconLabel(icon: AppIcons.network, label: region),
        if (version.isNotEmpty)
          ResourceIconLabel(icon: AppIcons.package, label: version),
      ],
      pills: [
        if (server.template) const TextPill(label: 'Template'),
        ...resourceTagPills(displayTags),
      ],
      onTap: onTap,
    );
  }
}

/// Status pill/accent for a server.
ResourceStatusSpec serverStatusSpec(ServerState state) {
  final (label, tone, icon) = switch (state) {
    ServerState.ok => ('Ok', PillTone.success, AppIcons.ok),
    ServerState.notOk => ('Unreachable', PillTone.alert, AppIcons.error),
    ServerState.disabled => ('Disabled', PillTone.neutral, AppIcons.paused),
    ServerState.unknown => ('Unknown', PillTone.neutral, AppIcons.unknown),
  };
  return ResourceStatusSpec(label: label, icon: icon, tone: tone);
}

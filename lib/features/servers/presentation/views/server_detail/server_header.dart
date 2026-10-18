import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/utils/byte_format.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';

/// App bar status line for a server: state plus periphery version.
MainAppBarStatus? serverAppBarStatus({
  required Server? server,
  required Server? listServer,
}) {
  final source = listServer ?? server;
  if (source?.info == null) return null;
  final state = source!.state;
  final version = _serverVersion(server: server, listServer: listServer);
  final label = switch (state) {
    ServerState.ok => 'Online',
    ServerState.notOk => 'Unreachable',
    ServerState.disabled => 'Disabled',
    ServerState.unknown => 'Unknown',
  };
  return MainAppBarStatus(
    label: version == null ? label : '$label · v$version',
    tone: switch (state) {
      ServerState.ok => PillTone.success,
      ServerState.notOk => PillTone.alert,
      ServerState.disabled || ServerState.unknown => PillTone.neutral,
    },
  );
}

String? _serverVersion({
  required Server? server,
  required Server? listServer,
}) {
  final version = (listServer?.info?.version.isNotEmpty ?? false)
      ? listServer!.info!.version
      : server?.info?.version;
  if (version == null || version.isEmpty) return null;
  return version.startsWith('v') ? version.substring(1) : version;
}

class ServerHeader extends StatelessWidget {
  const ServerHeader({
    required this.server,
    required this.listServer,
    required this.stats,
    required this.systemInformation,
    required this.ingressBytesPerSecond,
    required this.egressBytesPerSecond,
    super.key,
  });

  final Server? server;
  final Server? listServer;
  final SystemStats? stats;
  final SystemInformation? systemInformation;
  final double? ingressBytesPerSecond;
  final double? egressBytesPerSecond;

  @override
  Widget build(BuildContext context) {
    final server = this.server;
    final listServer = this.listServer;
    final stats = this.stats;

    final state = (listServer ?? server)?.state;
    final cores = systemInformation?.coreCount;
    final load = stats?.loadAverage?.one;

    final address = (listServer?.address.isNotEmpty ?? false)
        ? listServer!.address
        : server?.address;

    final loadProgress = (load != null && (cores ?? 0) > 0)
        ? (load / cores!).clamp(0.0, 1.0)
        : null;
    final memPercent = stats?.memPercent;
    final diskPercent = stats?.diskPercent;
    final memHigh = (memPercent ?? 0) > 90;
    final diskHigh = (diskPercent ?? 0) > 90;

    final tags = server?.tags ?? const <String>[];

    return DetailResourceHeader(
      banner: _banner(state: state, memHigh: memHigh, diskHigh: diskHigh),
      facts: [
        if (address?.isNotEmpty ?? false)
          DetailFact(
            icon: AppIcons.network,
            label: 'Address',
            value: address!,
            fullValue: address,
          ),
        if (cores != null)
          DetailFact(
            icon: AppIcons.cpu,
            label: 'Cores',
            value: cores.toString(),
          ),
        if (ingressBytesPerSecond != null && egressBytesPerSecond != null)
          DetailFact(
            icon: AppIcons.wifi,
            label: 'Net (in/out)',
            value:
                '${formatBytesPerSecond(ingressBytesPerSecond!)} / '
                '${formatBytesPerSecond(egressBytesPerSecond!)}',
          ),
      ],
      stats: [
        if (load != null)
          DetailStat(
            label: 'Load (1m)',
            value: load.toStringAsFixed(2),
            progress: loadProgress,
          ),
        if (memPercent != null)
          DetailStat(
            label: 'Memory',
            value: '${memPercent.round()}%',
            progress: (memPercent / 100).clamp(0.0, 1.0),
            tone: memHigh ? PillTone.warning : null,
          ),
        if (diskPercent != null)
          DetailStat(
            label: 'Disk',
            value: '${diskPercent.round()}%',
            progress: (diskPercent / 100).clamp(0.0, 1.0),
            tone: diskHigh ? PillTone.warning : null,
          ),
      ],
      tags: tags,
      description: server?.description,
    );
  }

  Widget? _banner({
    required ServerState? state,
    required bool memHigh,
    required bool diskHigh,
  }) {
    if (state == ServerState.notOk) {
      return const DetailAttentionBanner(
        icon: AppIcons.error,
        message: 'Server is unreachable',
        tone: PillTone.alert,
      );
    }
    if (diskHigh) {
      return const DetailAttentionBanner(
        icon: AppIcons.warning,
        message: 'Disk usage is above 90%',
      );
    }
    if (memHigh) {
      return const DetailAttentionBanner(
        icon: AppIcons.warning,
        message: 'Memory usage is above 90%',
      );
    }
    return null;
  }
}

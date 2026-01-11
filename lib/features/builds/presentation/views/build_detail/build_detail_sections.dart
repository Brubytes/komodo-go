import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

class BuildHeroPanel extends StatelessWidget {
  const BuildHeroPanel({
    required this.buildResource,
    required this.listItem,
    required this.builderLabel,
    super.key,
  });

  final KomodoBuild buildResource;
  final BuildListItem? listItem;
  final String? builderLabel;

  @override
  Widget build(BuildContext context) {
    return DetailHeroPanel(
      header: BuildHeader(buildResource: buildResource),
      metrics: [
        if (listItem != null)
          DetailMetricTileData(
            label: 'Status',
            value: listItem!.info.state.displayName,
            icon: listItem!.info.state == BuildState.ok
                ? AppIcons.ok
                : (listItem!.info.state == BuildState.failed
                      ? AppIcons.error
                      : AppIcons.loading),
            tone: switch (listItem!.info.state) {
              BuildState.ok => DetailMetricTone.success,
              BuildState.failed => DetailMetricTone.alert,
              BuildState.building => DetailMetricTone.neutral,
              BuildState.unknown => DetailMetricTone.neutral,
            },
          ),
        if ((builderLabel ?? '').trim().isNotEmpty)
          DetailMetricTileData(
            label: 'Builder',
            value: builderLabel!,
            icon: AppIcons.factory,
            tone: DetailMetricTone.neutral,
          ),
        DetailMetricTileData(
          label: 'Version',
          value: buildResource.config.version.label,
          icon: AppIcons.tag,
          tone: DetailMetricTone.neutral,
        ),
        if (buildResource.info.lastBuiltAt > 0)
          DetailMetricTileData(
            label: 'Last Built',
            value: _formatTimestamp(buildResource.info.lastBuiltAt),
            icon: AppIcons.clock,
            tone: DetailMetricTone.neutral,
          ),
        if (buildResource.info.latestHash != null &&
            buildResource.info.builtHash != null)
          DetailMetricTileData(
            label: 'Source',
            value: buildResource.info.latestHash == buildResource.info.builtHash
                ? 'Up to date'
                : 'Out of date',
            icon: buildResource.info.latestHash == buildResource.info.builtHash
                ? AppIcons.ok
                : AppIcons.warning,
            tone: buildResource.info.latestHash == buildResource.info.builtHash
                ? DetailMetricTone.success
                : DetailMetricTone.tertiary,
          ),
      ],
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class BuildHeader extends StatelessWidget {
  const BuildHeader({required this.buildResource, super.key});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          buildResource.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (buildResource.description.isNotEmpty) ...[
          const Gap(4),
          Text(
            buildResource.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

// Configuration Content
class BuildConfigContent extends StatelessWidget {
  const BuildConfigContent({
    required this.buildResource,
    required this.builderLabel,
    super.key,
  });

  final KomodoBuild buildResource;
  final String? builderLabel;

  @override
  Widget build(BuildContext context) {
    final config = buildResource.config;

    final builder = (builderLabel ?? '').trim();
    final extraArgs = config.extraArgs
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill.onOff(
              isOn: config.webhookEnabled,
              onLabel: 'Webhook on',
              offLabel: 'Webhook off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.autoIncrementVersion,
              onLabel: 'Auto version',
              offLabel: 'Manual version',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.useBuildx,
              onLabel: 'Buildx on',
              offLabel: 'Buildx off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.filesOnHost,
              onLabel: 'Files on host',
              offLabel: 'Files in builder',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.package,
            ),
            StatusPill.onOff(
              isOn: config.skipSecretInterp,
              onLabel: 'Skip secret interp',
              offLabel: 'Secret interp on',
              onIcon: AppIcons.warning,
              offIcon: AppIcons.ok,
            ),
          ],
        ),
        const Gap(14),
        DetailSubCard(
          title: 'Builder & Version',
          icon: AppIcons.factory,
          child: Column(
            children: [
              if (builder.isNotEmpty)
                DetailKeyValueRow(label: 'Builder', value: builder),
              DetailKeyValueRow(
                label: 'Version',
                value: config.version.label,
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        if (config.imageName.isNotEmpty ||
            config.imageTag.isNotEmpty ||
            extraArgs.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Image',
            icon: AppIcons.builds,
            child: Column(
              children: [
                if (config.imageName.isNotEmpty)
                  DetailKeyValueRow(label: 'Name', value: config.imageName),
                if (config.imageTag.isNotEmpty)
                  DetailKeyValueRow(label: 'Tag', value: config.imageTag),
                if (extraArgs.isNotEmpty) ...[
                  const Gap(6),
                  DetailCodeBlock(code: extraArgs.join('\n'), maxHeight: 200),
                ],
              ],
            ),
          ),
        ],
        if (config.buildPath.isNotEmpty ||
            config.dockerfilePath.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Paths',
            icon: AppIcons.package,
            child: Column(
              children: [
                if (config.buildPath.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Build path',
                    value: config.buildPath,
                  ),
                if (config.dockerfilePath.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Dockerfile',
                    value: config.dockerfilePath,
                    bottomPadding: 0,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class BuildSourceContent extends StatelessWidget {
  const BuildSourceContent({required this.buildResource, super.key});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    final config = buildResource.config;

    String? repoLabel() {
      final repo = config.repo.trim();
      final branch = config.branch.trim();
      if (repo.isEmpty) return null;
      return branch.isEmpty ? repo : '$repo · $branch';
    }

    final linkedRepo = config.linkedRepo.trim();
    final commit = config.commit.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Repository',
          icon: AppIcons.repos,
          child: Column(
            children: [
              DetailKeyValueRow(label: 'Repo', value: repoLabel() ?? '—'),
              if (linkedRepo.isNotEmpty)
                DetailKeyValueRow(label: 'Linked repo', value: linkedRepo),
              DetailKeyValueRow(
                label: 'Commit',
                value: commit.isNotEmpty ? commit : '—',
                bottomPadding: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Hashes Content
class BuildHashesContent extends StatelessWidget {
  const BuildHashesContent({required this.buildResource, super.key});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    final info = buildResource.info;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.latestHash != null)
          DetailKeyValueRow(label: 'Latest Hash', value: info.latestHash!),
        if (info.builtHash != null)
          DetailKeyValueRow(label: 'Built Hash', value: info.builtHash!),
        if (info.latestMessage != null && info.latestMessage!.isNotEmpty)
          DetailKeyValueRow(
            label: 'Latest Message',
            value: info.latestMessage!,
          ),
        if (info.builtMessage != null && info.builtMessage!.isNotEmpty)
          DetailKeyValueRow(label: 'Built Message', value: info.builtMessage!),
      ],
    );
  }
}

// Logs Content
class BuildLogsContent extends StatelessWidget {
  const BuildLogsContent({required this.buildResource, super.key});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    final info = buildResource.info;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.remoteError != null &&
            info.remoteError!.trim().isNotEmpty) ...[
          Text(
            'Remote Error',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(8),
          SizedBox(
            width: double.infinity,
            child: AppCardSurface(
              padding: const EdgeInsets.all(12),
              radius: 12,
              enableShadow: false,
              child: SelectableText(
                info.remoteError!.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
        if (info.remoteError != null &&
            info.remoteError!.trim().isNotEmpty &&
            ((info.remoteContents != null &&
                    info.remoteContents!.trim().isNotEmpty) ||
                (info.builtContents != null &&
                    info.builtContents!.trim().isNotEmpty)))
          const Gap(16),
        if (info.remoteContents != null &&
            info.remoteContents!.trim().isNotEmpty) ...[
          Text(
            'Remote Contents',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(8),
          DetailCodeBlock(code: info.remoteContents!.trim()),
        ],
        if (info.remoteContents != null &&
            info.remoteContents!.trim().isNotEmpty &&
            info.builtContents != null &&
            info.builtContents!.trim().isNotEmpty)
          const Gap(16),
        if (info.builtContents != null &&
            info.builtContents!.trim().isNotEmpty) ...[
          Text(
            'Built Contents',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(8),
          DetailCodeBlock(code: info.builtContents!.trim()),
        ],
      ],
    );
  }
}

// Helper Surfaces
class BuildMessageSurface extends StatelessWidget {
  const BuildMessageSurface({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text(message)),
      ),
    );
  }
}

class BuildLoadingSurface extends StatelessWidget {
  const BuildLoadingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return const DetailSurface(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class BuildErrorSurface extends StatelessWidget {
  const BuildErrorSurface({required this.error, super.key});

  final String error;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $error'),
      ),
    );
  }
}

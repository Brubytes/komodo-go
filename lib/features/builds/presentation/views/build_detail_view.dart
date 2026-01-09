import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/builds/presentation/widgets/build_card.dart';

/// View displaying detailed build information.
class BuildDetailView extends ConsumerWidget {
  const BuildDetailView({
    required this.buildId,
    required this.buildName,
    super.key,
  });

  final String buildId;
  final String buildName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildAsync = ref.watch(buildDetailProvider(buildId));
    final actionsState = ref.watch(buildActionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: MainAppBar(
        title: buildName,
        icon: AppIcons.builds,
        markColor: scheme.primary,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          PopupMenuButton<BuildAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) =>
                _handleAction(context, ref, buildId, action),
            itemBuilder: (context) {
              final scheme = Theme.of(context).colorScheme;
              return [
                komodoPopupMenuItem(
                  value: BuildAction.run,
                  icon: AppIcons.play,
                  label: 'Run build',
                  iconColor: scheme.secondary,
                ),
                komodoPopupMenuItem(
                  value: BuildAction.cancel,
                  icon: AppIcons.stop,
                  label: 'Cancel',
                  destructive: true,
                ),
              ];
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(buildDetailProvider(buildId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                buildAsync.when(
                  data: (build) => build != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BuildHeroPanel(buildResource: build),
                            const Gap(16),
                            DetailSection(
                              title: 'Build Configuration',
                              icon: AppIcons.settings,
                              child: _BuildConfigContent(buildResource: build),
                            ),
                            if (build.info.latestHash != null ||
                                build.info.builtHash != null)
                              const Gap(16),
                            if (build.info.latestHash != null ||
                                build.info.builtHash != null)
                              DetailSection(
                                title: 'Commit Hashes',
                                icon: AppIcons.repos,
                                child: _BuildHashesContent(buildResource: build),
                              ),
                            if ((build.info.remoteError != null &&
                                    build.info.remoteError!
                                        .trim()
                                        .isNotEmpty) ||
                                (build.info.builtContents != null &&
                                    build.info.builtContents!
                                        .trim()
                                        .isNotEmpty))
                              const Gap(16),
                            if ((build.info.remoteError != null &&
                                    build.info.remoteError!
                                        .trim()
                                        .isNotEmpty) ||
                                (build.info.builtContents != null &&
                                    build.info.builtContents!
                                        .trim()
                                        .isNotEmpty))
                              DetailSection(
                                title: 'Logs',
                                icon: AppIcons.package,
                                child: _BuildLogsContent(buildResource: build),
                              ),
                          ],
                        )
                      : const _MessageSurface(message: 'Build not found'),
                  loading: () => const _LoadingSurface(),
                  error: (error, _) => _ErrorSurface(error: error.toString()),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.25),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String buildId,
    BuildAction action,
  ) async {
    final actions = ref.read(buildActionsProvider.notifier);
    final success = await switch (action) {
      BuildAction.run => actions.run(buildId),
      BuildAction.cancel => actions.cancel(buildId),
    };

    if (success) {
      ref.invalidate(buildDetailProvider(buildId));
    }

    if (context.mounted) {
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Action completed successfully'
                : 'Action failed. Please try again.',
          ),
          backgroundColor:
              success ? scheme.secondaryContainer : scheme.errorContainer,
        ),
      );
    }
  }
}

// Hero Panel
class _BuildHeroPanel extends StatelessWidget {
  const _BuildHeroPanel({required this.buildResource});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    return DetailHeroPanel(
      header: _BuildHeader(buildResource: buildResource),
      metrics: [
        if (buildResource.config.builderId.isNotEmpty)
          DetailMetricTileData(
            label: 'Builder',
            value: buildResource.config.builderId,
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

class _BuildHeader extends StatelessWidget {
  const _BuildHeader({required this.buildResource});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          buildResource.name,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
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
class _BuildConfigContent extends StatelessWidget {
  const _BuildConfigContent({required this.buildResource});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    final config = buildResource.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.repo.isNotEmpty)
          DetailKeyValueRow(
            label: 'Repository',
            value: config.branch.isNotEmpty
                ? '${config.repo} (${config.branch})'
                : config.repo,
          ),
        if (config.imageName.isNotEmpty)
          DetailKeyValueRow(label: 'Image Name', value: config.imageName),
        if (config.imageTag.isNotEmpty)
          DetailKeyValueRow(label: 'Image Tag', value: config.imageTag),
        DetailKeyValueRow(
          label: 'Webhook',
          value: config.webhookEnabled ? 'Enabled' : 'Disabled',
        ),
      ],
    );
  }
}

// Hashes Content
class _BuildHashesContent extends StatelessWidget {
  const _BuildHashesContent({required this.buildResource});

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
          DetailKeyValueRow(label: 'Latest Message', value: info.latestMessage!),
        if (info.builtMessage != null && info.builtMessage!.isNotEmpty)
          DetailKeyValueRow(label: 'Built Message', value: info.builtMessage!),
      ],
    );
  }
}

// Logs Content
class _BuildLogsContent extends StatelessWidget {
  const _BuildLogsContent({required this.buildResource});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    final info = buildResource.info;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.remoteError != null && info.remoteError!.trim().isNotEmpty) ...[
          Text(
            'Remote Error',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              info.remoteError!.trim(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
        if (info.remoteError != null &&
            info.remoteError!.trim().isNotEmpty &&
            info.builtContents != null &&
            info.builtContents!.trim().isNotEmpty)
          const Gap(16),
        if (info.builtContents != null &&
            info.builtContents!.trim().isNotEmpty) ...[
          Text(
            'Built Contents',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              info.builtContents!.trim(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ],
    );
  }
}

// Helper Surfaces
class _MessageSurface extends StatelessWidget {
  const _MessageSurface({required this.message});

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

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface();

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

class _ErrorSurface extends StatelessWidget {
  const _ErrorSurface({required this.error});

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

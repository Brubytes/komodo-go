import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/target_display_name_provider.dart';
import 'package:komodo_go/features/notifications/presentation/utils/alert_navigation_utils.dart';

/// Detail screen for one alert, shown next to the alert list on wide windows.
///
/// The alert is looked up in [alertsProvider]; after a refresh it may be gone,
/// which shows an empty state.
class AlertDetailView extends ConsumerWidget {
  const AlertDetailView({required this.alertId, super.key});

  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);
    final alert = alertsAsync.asData?.value.items
        .where((a) => a.id == alertId)
        .firstOrNull;

    return Scaffold(
      appBar: MainAppBar(
        title: 'Alert details',
        icon: AppIcons.notifications,
        markColor: AppTokens.resourceStacks,
        markUseGradient: true,
        centerTitle: true,
        status: alert == null ? null : _status(alert),
      ),
      body: alert != null
          ? _AlertDetailContent(alert: alert)
          : alertsAsync.isLoading && !alertsAsync.hasValue
          ? const AppSkeletonList(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: const [
                Gap(72),
                EmptyStateView(
                  icon: AppIcons.notifications,
                  title: 'Alert not found',
                  message: 'It may have been removed since the list refreshed.',
                ),
              ],
            ),
    );
  }
}

class _AlertDetailContent extends ConsumerWidget {
  const _AlertDetailContent({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = alert.target;
    final resolvedName = target == null
        ? null
        : ref.watch(targetDisplayNameProvider(target)).asData?.value;
    final targetName =
        resolvedName ?? target?.displayName ?? alert.payload.primaryName;
    final route = routeForAlert(alert);
    final details = _payloadDetails(alert.payload);

    return ListView(
      key: const ValueKey('alert_detail_content'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        DetailResourceHeader(
          banner: !alert.resolved && alert.level == SeverityLevel.critical
              ? const DetailAttentionBanner(
                  icon: AppIcons.error,
                  message: 'This alert is critical and unresolved',
                  tone: PillTone.alert,
                )
              : null,
          facts: [
            DetailFact(
              icon: _targetIcon(target?.type),
              label: 'Target',
              value: targetName == null || targetName.isEmpty
                  ? 'System'
                  : targetName,
            ),
            DetailFact(
              icon: AppIcons.clock,
              label: 'Raised',
              value: _formatDateTime(alert.timestamp),
            ),
            if (alert.resolved && alert.resolvedTs != null)
              DetailFact(
                icon: AppIcons.ok,
                label: 'Resolved',
                value: _formatDateTime(_toDateTime(alert.resolvedTs!)),
              ),
          ],
        ),
        if (route != null) ...[
          const Gap(AppSpacing.lg),
          FilledButton.icon(
            key: const ValueKey('alert_open_target'),
            onPressed: () => context.go(route),
            icon: const Icon(AppIcons.chevron),
            label: Text(
              targetName == null || targetName.isEmpty
                  ? 'Open resource'
                  : 'Open $targetName',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const Gap(AppSpacing.lg),
        DetailSubCard(
          title: 'Summary',
          icon: AppIcons.info,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Alert',
                value: alert.payload.displayTitle,
              ),
              DetailKeyValueRow(label: 'Severity', value: _levelLabel(alert)),
              DetailKeyValueRow(
                label: 'State',
                value: alert.resolved ? 'Resolved' : 'Unresolved',
              ),
              if (target != null)
                DetailKeyValueRow(
                  label: 'Target type',
                  value: _humanize(target.type.name),
                ),
              DetailKeyValueRow(
                label: 'Alert ID',
                value: alert.id,
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        if (details.isNotEmpty) ...[
          const Gap(AppSpacing.lg),
          DetailSubCard(
            title: 'Details',
            icon: AppIcons.notepadText,
            child: Column(
              children: [
                for (var i = 0; i < details.length; i++)
                  DetailKeyValueRow(
                    label: details[i].$1,
                    value: details[i].$2,
                    bottomPadding: i == details.length - 1 ? 0 : 8,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Scalar payload fields as label/value pairs; nested data is skipped.
List<(String, String)> _payloadDetails(AlertPayload payload) {
  return [
    for (final entry in payload.data.entries)
      if (entry.value is String || entry.value is num || entry.value is bool)
        if ('${entry.value}'.trim().isNotEmpty)
          (_humanize(entry.key), '${entry.value}'.trim()),
  ];
}

MainAppBarStatus _status(Alert alert) {
  if (alert.resolved) {
    return const MainAppBarStatus(label: 'Resolved', tone: PillTone.success);
  }
  return MainAppBarStatus(
    label: _levelLabel(alert),
    tone: switch (alert.level) {
      SeverityLevel.critical => PillTone.alert,
      SeverityLevel.warning => PillTone.warning,
      SeverityLevel.ok => PillTone.success,
      SeverityLevel.unknown => PillTone.neutral,
    },
  );
}

String _levelLabel(Alert alert) => switch (alert.level) {
  SeverityLevel.ok => 'OK',
  SeverityLevel.warning => 'Warning',
  SeverityLevel.critical => 'Critical',
  SeverityLevel.unknown => 'Unknown',
};

String _humanize(String value) {
  final spaced = value
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp('(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ')
      .trim();
  if (spaced.isEmpty) return value;
  return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
}

IconData _targetIcon(ResourceTargetType? type) {
  return switch (type) {
    ResourceTargetType.server => AppIcons.server,
    ResourceTargetType.stack => AppIcons.stacks,
    ResourceTargetType.deployment => AppIcons.deployments,
    ResourceTargetType.build => AppIcons.builds,
    ResourceTargetType.repo => AppIcons.repos,
    ResourceTargetType.procedure => AppIcons.procedures,
    ResourceTargetType.action => AppIcons.actions,
    ResourceTargetType.resourceSync => AppIcons.syncs,
    ResourceTargetType.builder => AppIcons.factory,
    ResourceTargetType.alerter => AppIcons.notifications,
    ResourceTargetType.system ||
    ResourceTargetType.unknown ||
    null => AppIcons.widgets,
  };
}

DateTime _toDateTime(int unix) => DateTime.fromMillisecondsSinceEpoch(
  unix >= 1000000000000 ? unix : unix * 1000,
  isUtc: true,
);

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)} ${two(local.hour)}:${two(local.minute)}:'
      '${two(local.second)}';
}

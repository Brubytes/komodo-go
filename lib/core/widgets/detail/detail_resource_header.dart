import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/status_colors.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pill_list.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

/// One descriptive fact in a [DetailResourceHeader] (server, branch, path…).
///
/// Facts that link to another resource pass [onTap] and get a chevron.
/// Other facts show [fullValue] (or [value]) in a dialog when tapped, so
/// truncated values stay readable.
class DetailFact {
  const DetailFact({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.fullValue,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? fullValue;

  /// Colors the value; leave null for plain text.
  final PillTone? tone;
}

/// One number in the [DetailResourceHeader] stat strip.
class DetailStat {
  const DetailStat({
    required this.label,
    required this.value,
    this.progress,
    this.tone,
  });

  final String label;
  final String value;

  /// 0..1; renders a thin meter under the label when set.
  final double? progress;

  /// Colors the value (and meter); leave null for plain text.
  final PillTone? tone;
}

/// Attention banner shown above the facts when something needs action.
///
/// Only build one when the user can or should act; healthy states belong in
/// the app bar status line, not here.
class DetailAttentionBanner extends StatelessWidget {
  const DetailAttentionBanner({
    required this.icon,
    required this.message,
    this.tone = PillTone.warning,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final PillTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (Color bg, Color fg) = switch (tone) {
      // Dark errorContainer is a saturated red block; a muted tint matches
      // the warning banner's weight instead.
      PillTone.alert when scheme.brightness == Brightness.dark => (
        Color.alphaBlend(scheme.error.withValues(alpha: 0.18), scheme.surface),
        scheme.error,
      ),
      PillTone.alert => (scheme.errorContainer, scheme.onErrorContainer),
      PillTone.success => (
        scheme.statusSuccessContainer,
        scheme.statusSuccess,
      ),
      PillTone.neutral => (
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
      ),
      PillTone.warning => (
        scheme.statusWarningContainer,
        scheme.statusWarning,
      ),
    };

    final hasAction = actionLabel != null && onAction != null;
    final messageRow = Row(
      children: [
        Icon(icon, size: 18, color: fg),
        const Gap(10),
        Expanded(
          child: Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    final button = hasAction
        ? FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: fg,
              foregroundColor: bg,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(actionLabel!),
          )
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (button == null) return messageRow;
          // Stack the button under the message when large text leaves too
          // little room for both on one line.
          final scale = MediaQuery.textScalerOf(context).scale(1);
          if (constraints.maxWidth / scale < 220) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [messageRow, const Gap(6), button],
            );
          }
          return Row(
            children: [
              Expanded(child: messageRow),
              const Gap(8),
              button,
            ],
          );
        },
      ),
    );
  }
}

/// Compact header for resource detail pages.
///
/// Layout, top to bottom: optional [banner], a card with [facts] as rows and
/// an optional [stats] strip, then tags/[description]. Status and recency go
/// in the app bar (`MainAppBar.status`), never in here. Don't repeat config
/// toggles as facts; they already live in the Config tab.
class DetailResourceHeader extends StatelessWidget {
  const DetailResourceHeader({
    this.banner,
    this.facts = const [],
    this.stats = const [],
    this.tags = const [],
    this.leadingPills = const [],
    this.description,
    super.key,
  });

  final Widget? banner;
  final List<DetailFact> facts;
  final List<DetailStat> stats;
  final List<String> tags;

  /// Status pills shown before the tags (e.g. "Project missing").
  final List<Widget> leadingPills;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trimmedDescription = description?.trim() ?? '';
    final hasPills = tags.isNotEmpty || leadingPills.isNotEmpty;
    final hasCard = facts.isNotEmpty || stats.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null) ...[banner!, const Gap(10)],
        if (hasCard)
          AppCardSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < facts.length; i++) ...[
                  if (i > 0) const _HeaderDivider(),
                  _FactRow(fact: facts[i]),
                ],
                if (stats.isNotEmpty) ...[
                  if (facts.isNotEmpty) const _HeaderDivider(indent: 0),
                  _StatStrip(stats: stats),
                ],
              ],
            ),
          ),
        if (hasPills) ...[
          const Gap(10),
          DetailPillList(
            items: tags,
            showEmptyLabel: false,
            leading: leadingPills,
          ),
        ],
        if (trimmedDescription.isNotEmpty) ...[
          const Gap(10),
          Text(
            trimmedDescription,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  const _HeaderDivider({this.indent = 44});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(
        alpha: 0.35,
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});

  final DetailFact fact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fullValue = (fact.fullValue ?? fact.value).trim();
    final onTap =
        fact.onTap ??
        (fullValue.isEmpty
            ? null
            : () => _showFullValueDialog(context, fact.label, fullValue));

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Icon(fact.icon, size: 18, color: scheme.primary),
                const Gap(12),
                // Cap the label instead of making it Flexible: two flex
                // children split the row evenly and the value would stop
                // short of the trailing edge.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.45,
                  ),
                  child: Text(
                    fact.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: Text(
                    fact.value,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: fact.tone == null
                          ? scheme.onSurface
                          : pillToneForeground(scheme, fact.tone!),
                    ),
                  ),
                ),
                if (fact.onTap != null) ...[
                  const Gap(4),
                  Icon(
                    AppIcons.chevron,
                    size: 16,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullValueDialog(BuildContext context, String title, String value) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SelectableText(value),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});

  final List<DetailStat> stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.35);

    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, color: dividerColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: _StatCell(
                  stat: stats[i],
                  scheme: scheme,
                  textTheme: textTheme,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.stat,
    required this.scheme,
    required this.textTheme,
  });

  final DetailStat stat;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final accent = stat.tone == null
        ? scheme.primary
        : pillToneForeground(scheme, stat.tone!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: stat.tone == null ? scheme.onSurface : accent,
          ),
        ),
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (stat.progress != null) ...[
          const Gap(6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: stat.progress!.clamp(0, 1),
              minHeight: 4,
              backgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/theme/status_colors.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';

/// Display form of an image reference: registry-less `owner/name:tag`.
///
/// - Strips the registry host (anything with a `.`/`:` or `localhost` before
///   the first `/`) and a leading `library/`.
/// - The name is never empty; falls back to the raw reference.
/// - Long hash/digest tags are shortened: `sha256:<12>` digests keep their
///   `@sha256:` form, other tags longer than 20 chars keep 12 chars + `…`.
String formatContainerImage(String image) {
  final raw = image.trim();
  var ref = raw;
  String? digest;
  final at = ref.indexOf('@');
  if (at >= 0) {
    digest = ref.substring(at + 1);
    ref = ref.substring(0, at);
  }
  String? tag;
  final slash = ref.lastIndexOf('/');
  final colon = ref.indexOf(':', slash + 1);
  if (colon >= 0) {
    tag = ref.substring(colon + 1);
    ref = ref.substring(0, colon);
  }
  // `name:sha256:abc` is really a digest.
  if (digest == null && tag != null && tag.startsWith('sha256:')) {
    digest = tag;
    tag = null;
  }

  final parts = ref.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.length > 1) {
    final first = parts.first;
    if (first.contains('.') || first.contains(':') || first == 'localhost') {
      parts.removeAt(0);
    }
  }
  if (parts.length > 1 && parts.first == 'library') parts.removeAt(0);
  var name = parts.join('/');
  if (name.isEmpty) name = raw;

  if (digest != null && digest.isNotEmpty) {
    final colonAt = digest.indexOf(':');
    final algo = colonAt >= 0 ? digest.substring(0, colonAt + 1) : '';
    final hash = colonAt >= 0 ? digest.substring(colonAt + 1) : digest;
    final short = hash.length > 12 ? hash.substring(0, 12) : hash;
    return '$name@$algo$short';
  }
  if (tag == null || tag.isEmpty) return name;
  final shortTag = tag.length > 20 ? '${tag.substring(0, 12)}…' : tag;
  return '$name:$shortTag';
}

/// Short label for a port: `3086→80/tcp`, or `80/tcp` when not published.
String formatContainerPort(ContainerPort port) {
  final type = port.type == PortType.unknown ? '' : '/${port.type.name}';
  final public = port.publicPort;
  return public == null
      ? '${port.privatePort}$type'
      : '$public→${port.privatePort}$type';
}

/// Tonal info chip (icon + single-line ellipsized text).
///
/// Never wider than the space its parent offers, so long values cannot
/// overflow the card.
class ContainerInfoChip extends StatelessWidget {
  const ContainerInfoChip({
    required this.label,
    this.icon,
    this.tooltip,
    super.key,
  });

  final String label;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const Gap(6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }
}

/// Status pill with the actions menu integrated (`RUNNING ⋮`).
class ContainerStatusPill extends StatelessWidget {
  const ContainerStatusPill({
    required this.status,
    required this.menu,
    this.menuKey,
    super.key,
  });

  final ResourceStatusSpec status;
  final List<DetailActionGroup> menu;
  final Key? menuKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = switch (status.tone) {
      PillTone.success => (scheme.statusSuccessContainer, scheme.statusSuccess),
      PillTone.warning => (scheme.statusWarningContainer, scheme.statusWarning),
      PillTone.alert => (scheme.errorContainer, scheme.onErrorContainer),
      PillTone.neutral => (
        isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
        scheme.onSurface,
      ),
    };
    final hasMenu = menu.any((g) => g.items.isNotEmpty);
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 10,
          right: hasMenu ? 6 : 10,
          top: 6,
          bottom: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            if (hasMenu) ...[
              const Gap(4),
              Icon(AppIcons.moreVertical, size: 16, color: fg),
            ],
          ],
        ),
      ),
    );
    if (!hasMenu) return pill;
    return DetailActionMenuButton(
      key: menuKey,
      groups: menu,
      tooltip: 'Actions',
      child: pill,
    );
  }
}

/// Rounded leading tile with the container icon on a tinted surface.
class ContainerIconTile extends StatelessWidget {
  const ContainerIconTile({required this.tone, super.key});

  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tone == PillTone.neutral
        ? scheme.onSurfaceVariant
        : pillToneForeground(scheme, tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(AppIcons.containers, color: color),
      ),
    );
  }
}

/// Compact 2x2 grid: CPU / Memory meters and Net / Block I/O values.
class ContainerMetricsGrid extends StatelessWidget {
  const ContainerMetricsGrid({required this.stats, super.key});

  final ContainerStats stats;

  /// Whether [stats] has anything worth showing.
  static bool hasData(ContainerStats s) =>
      s.cpuPercentValue != null ||
      s.memPercentValue != null ||
      s.netIo.trim().isNotEmpty ||
      s.blockIo.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cpu = stats.cpuPercentValue;
    final mem = stats.memPercentValue;
    final memText = stats.memUsage.replaceAll(' / ', '/').trim();
    final memValue = [
      if (memText.isNotEmpty) memText,
      if (mem != null) '${mem.toStringAsFixed(0)}%',
    ].join(' · ');

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Meter(
                label: 'CPU',
                value: cpu == null ? '-' : '${cpu.toStringAsFixed(1)}%',
                percent: cpu,
              ),
            ),
            const Gap(AppSpacing.lg),
            Expanded(
              child: _Meter(
                label: 'MEM',
                value: memValue.isEmpty ? '-' : memValue,
                percent: mem,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _IoStat(
                icon: AppIcons.network,
                first: '↓',
                second: '↑',
                raw: stats.netIo,
              ),
            ),
            const Gap(AppSpacing.lg),
            Expanded(
              child: _IoStat(
                icon: AppIcons.logs,
                first: 'R',
                second: 'W',
                raw: stats.blockIo,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, this.percent});

  final String label;
  final String value;
  final double? percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final p = percent;
    final color = p == null
        ? scheme.primary
        : p >= 95
        ? scheme.error
        : p >= 80
        ? pillToneForeground(scheme, PillTone.warning)
        : scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const Gap(6),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Gap(4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: p == null ? 0 : (p / 100).clamp(0.0, 1.0),
            minHeight: 4,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _IoStat extends StatelessWidget {
  const _IoStat({
    required this.icon,
    required this.first,
    required this.second,
    required this.raw,
  });

  final IconData icon;
  final String first;
  final String second;
  final String raw;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final parts = raw.split('/').map((s) => s.trim()).toList();
    final a = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : '-';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : '-';
    return Row(
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const Gap(6),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$first $a  $second $b', maxLines: 1, style: style),
            ),
          ),
        ),
      ],
    );
  }
}

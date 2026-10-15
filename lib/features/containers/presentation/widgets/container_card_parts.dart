import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';

/// Splits a Docker image reference into a short repo path and tag.
///
/// Strips the registry host (`docker.io/`, `lscr.io/`, `ghcr.io/`, ...) and a
/// leading `library/`. The tag (or digest) is returned separately so it can
/// stay visible when the repo path is ellipsized.
({String repo, String? tag}) splitContainerImage(String image) {
  var ref = image.trim();
  String? tag;
  final at = ref.indexOf('@');
  if (at >= 0) {
    final digest = ref.substring(at + 1);
    tag = digest.length > 19 ? digest.substring(0, 19) : digest;
    ref = ref.substring(0, at);
  }
  final slash = ref.lastIndexOf('/');
  final colon = ref.lastIndexOf(':');
  if (colon > slash) {
    tag ??= ref.substring(colon + 1);
    ref = ref.substring(0, colon);
  }
  final parts = ref.split('/');
  if (parts.length > 1) {
    final first = parts.first;
    if (first.contains('.') || first.contains(':') || first == 'localhost') {
      parts.removeAt(0);
    }
  }
  if (parts.length > 1 && parts.first == 'library') parts.removeAt(0);
  return (repo: parts.join('/'), tag: tag);
}

/// Display form of an image: registry-less `owner/name:tag`.
String formatContainerImage(String image) {
  final (:repo, :tag) = splitContainerImage(image);
  return tag == null ? repo : '$repo:$tag';
}

/// Short label for a port: `3086→80/tcp`, or `80/tcp` when not published.
String formatContainerPort(ContainerPort port) {
  final type = port.type == PortType.unknown ? '' : '/${port.type.name}';
  final public = port.publicPort;
  return public == null
      ? '${port.privatePort}$type'
      : '$public→${port.privatePort}$type';
}

/// Image line with the repo path ellipsized and the tag always visible.
class ContainerImageLine extends StatelessWidget {
  const ContainerImageLine({required this.image, super.key});

  final String image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final (:repo, :tag) = splitContainerImage(image);
    return Tooltip(
      message: image,
      child: Row(
        children: [
          Icon(AppIcons.package, size: 14, color: scheme.onSurfaceVariant),
          const Gap(6),
          Flexible(
            child: Text(
              repo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (tag != null)
            Text(
              ':$tag',
              maxLines: 1,
              style: style?.copyWith(color: scheme.primary),
            ),
        ],
      ),
    );
  }
}

/// Up to [max] port chips plus a `+N` overflow chip.
class ContainerPortChips extends StatelessWidget {
  const ContainerPortChips({required this.ports, this.max = 3, super.key});

  final List<ContainerPort> ports;
  final int max;

  @override
  Widget build(BuildContext context) {
    final list = ports.map(formatContainerPort).toSet().toList();
    final shown = list.take(max).toList();
    final extra = list.length - shown.length;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final l in shown) _MiniChip(label: l),
        if (extra > 0) _MiniChip(label: '+$extra'),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
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

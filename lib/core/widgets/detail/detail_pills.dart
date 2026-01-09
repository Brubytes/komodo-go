import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

enum PillTone { success, neutral, warning, alert }

class TextPill extends StatelessWidget {
  const TextPill({
    required this.label,
    super.key,
    this.tone = PillTone.neutral,
  });

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color bg, Color fg) = switch (tone) {
      PillTone.success => (
        scheme.secondaryContainer.withValues(alpha: isDark ? 0.22 : 0.60),
        scheme.onSecondaryContainer,
      ),
      PillTone.warning => (
        scheme.tertiaryContainer.withValues(alpha: isDark ? 0.22 : 0.60),
        scheme.onTertiaryContainer,
      ),
      PillTone.alert => (
        scheme.errorContainer.withValues(alpha: isDark ? 0.22 : 0.60),
        scheme.onErrorContainer,
      ),
      PillTone.neutral => (scheme.surfaceContainerHigh, scheme.onSurface),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.icon,
    required this.tone,
    super.key,
  });

  factory StatusPill.onOff({
    required bool isOn,
    required String onLabel,
    required String offLabel,
    PillTone onTone = PillTone.success,
    PillTone offTone = PillTone.neutral,
    IconData onIcon = Icons.check_circle,
    IconData offIcon = Icons.cancel,
  }) {
    return StatusPill(
      label: isOn ? onLabel : offLabel,
      tone: isOn ? onTone : offTone,
      icon: isOn ? onIcon : offIcon,
    );
  }

  final String label;
  final IconData icon;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color bg, Color fg, Color iconColor) = switch (tone) {
      PillTone.success => (
        scheme.secondaryContainer.withValues(alpha: isDark ? 0.22 : 0.60),
        scheme.onSecondaryContainer,
        scheme.secondary,
      ),
      PillTone.warning => (
        scheme.tertiaryContainer.withValues(alpha: isDark ? 0.22 : 0.60),
        scheme.onTertiaryContainer,
        scheme.tertiary,
      ),
      PillTone.alert => (
        scheme.errorContainer.withValues(alpha: isDark ? 0.22 : 0.60),
        scheme.onErrorContainer,
        scheme.error,
      ),
      PillTone.neutral => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        scheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const Gap(6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ValuePill extends StatelessWidget {
  const ValuePill({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(6),
          Text(
            value,
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

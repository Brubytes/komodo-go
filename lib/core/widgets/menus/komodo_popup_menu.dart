import 'package:flutter/material.dart';

class KomodoPopupMenuItemRow extends StatelessWidget {
  const KomodoPopupMenuItemRow({
    required this.icon,
    required this.label,
    this.iconColor,
    this.isDestructive = false,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final bool isDestructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final accent = isDestructive ? scheme.error : (iconColor ?? scheme.primary);
    final onLabel = isDestructive ? scheme.error : scheme.onSurface;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: onLabel,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          DefaultTextStyle.merge(
            style: TextStyle(color: scheme.onSurfaceVariant),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}

PopupMenuItem<T> komodoPopupMenuItem<T>({
  required T value,
  required IconData icon,
  required String label,
  Color? iconColor,
  bool destructive = false,
}) {
  return PopupMenuItem<T>(
    value: value,
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: KomodoPopupMenuItemRow(
      icon: icon,
      label: label,
      iconColor: iconColor,
      isDestructive: destructive,
    ),
  );
}

PopupMenuDivider komodoPopupMenuDivider() => const PopupMenuDivider(height: 12);

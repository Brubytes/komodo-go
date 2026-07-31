import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

class DetailLogAutoRefreshControl extends StatelessWidget {
  const DetailLogAutoRefreshControl({
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  static const message =
      'When enabled, logs refresh every 2.5 seconds while this tab is visible. Pull down to refresh once.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Auto refresh logs', style: textTheme.titleSmall),
        const Gap(4),
        Text(
          message,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const Gap(10),
        Row(
          children: [
            Tooltip(
              message: message,
              child: Icon(
                AppIcons.refresh,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            Expanded(
              child: Text(
                enabled ? 'Enabled' : 'Disabled',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Switch.adaptive(value: enabled, onChanged: onChanged),
          ],
        ),
      ],
    );
  }
}

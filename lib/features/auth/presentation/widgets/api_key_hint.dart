import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';

/// Short "where to get the API key/secret" hint shown on connection forms.
class ApiKeyHint extends StatelessWidget {
  const ApiKeyHint({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get your API key',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '1. Open the Komodo web UI and go to user settings.',
            style: style,
          ),
          Text('2. Generate an API key and secret.', style: style),
          Text(
            '3. Paste them below. You can paste "key:secret" into the key '
            'field to fill both.',
            style: style,
          ),
        ],
      ),
    );
  }
}

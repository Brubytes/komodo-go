import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.title,
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNetworkIssue = _isNetworkMessage(message);
    final helperText = isNetworkIssue
        ? 'Check your internet connection and server address in Settings > Connections.'
        : null;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(48),
        Icon(
          isNetworkIssue ? AppIcons.disconnect : AppIcons.formError,
          size: 64,
          color: scheme.error,
        ),
        const Gap(16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        if (helperText != null) ...[
          const Gap(8),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const Gap(24),
        FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }

  bool _isNetworkMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('network') ||
        normalized.contains('connect') ||
        normalized.contains('offline') ||
        normalized.contains('unreachable') ||
        normalized.contains('socket');
  }
}

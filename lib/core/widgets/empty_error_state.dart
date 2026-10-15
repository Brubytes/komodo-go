import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

/// Converts any error object to a short, user-facing message.
///
/// Uses [FailureX.displayMessage] for [Failure]/[FailureException], the
/// message of an [ApiException], and otherwise strips noisy type prefixes.
String friendlyErrorMessage(Object error) {
  if (error is Failure) return error.displayMessage;
  if (error is FailureException) return error.failure.displayMessage;
  if (error is ApiException) return error.message;
  var text = error.toString().trim();
  for (final prefix in const ['Exception: ', 'Bad state: ', 'Error: ']) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length).trim();
    }
  }
  return text.isEmpty ? 'Something went wrong.' : text;
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.title,
    required this.message,
    required this.onRetry,
    super.key,
  });

  /// Builds the view from a raw [error], showing a friendly message.
  ErrorStateView.fromError({
    required this.title,
    required Object error,
    required this.onRetry,
    super.key,
  }) : message = friendlyErrorMessage(error);

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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
        ),
      ),
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

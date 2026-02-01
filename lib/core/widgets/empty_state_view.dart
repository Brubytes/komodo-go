import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// A reusable widget for displaying empty states when there's no data.
///
/// Use this for "No items", "No data", "Not configured" scenarios.
/// For error states with retry functionality, use `ErrorStateView` instead.
///
/// The widget can be displayed in three modes:
/// - `EmptyStateView()` - For full-page empty states (default, centered)
/// - `EmptyStateView.inline()` - For inline/nested empty states (smaller)
/// - `EmptyStateView.sliver()` - For use in CustomScrollView/slivers
class EmptyStateView extends StatelessWidget {
  /// Creates a centered empty state view, ideal for full-page scenarios.
  const EmptyStateView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.actionLabel,
    super.key,
  }) : _mode = _EmptyStateMode.centered;

  /// Creates an inline empty state view, ideal for nested/card scenarios.
  ///
  /// This variant is smaller and doesn't have outer padding, making it
  /// suitable for use inside cards or content areas.
  const EmptyStateView.inline({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.actionLabel,
    super.key,
  }) : _mode = _EmptyStateMode.inline;

  /// Creates a sliver empty state view for use in CustomScrollView.
  const EmptyStateView.sliver({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.actionLabel,
    super.key,
  }) : _mode = _EmptyStateMode.sliver;

  /// The icon to display. Should be a relevant icon from `AppIcons`.
  final IconData icon;

  /// The title text, e.g., "No stages configured" or "No items found".
  final String title;

  /// Optional descriptive message explaining the empty state.
  final String? message;

  /// Optional callback for an action button.
  final VoidCallback? action;

  /// Label for the action button. Required if [action] is provided.
  final String? actionLabel;

  final _EmptyStateMode _mode;

  @override
  Widget build(BuildContext context) {
    final content = _EmptyStateContent(
      icon: icon,
      title: title,
      message: message,
      action: action,
      actionLabel: actionLabel,
      isInline: _mode == _EmptyStateMode.inline,
    );

    return switch (_mode) {
      _EmptyStateMode.centered => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: content,
        ),
      ),
      _EmptyStateMode.inline => content,
      _EmptyStateMode.sliver => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: content,
          ),
        ),
      ),
    };
  }
}

enum _EmptyStateMode { centered, inline, sliver }

class _EmptyStateContent extends StatelessWidget {
  const _EmptyStateContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.actionLabel,
    required this.isInline,
  });

  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? action;
  final String? actionLabel;
  final bool isInline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final iconSize = isInline ? 48.0 : 64.0;
    final iconGap = isInline ? 12.0 : 16.0;
    const textGap = 8.0;
    const actionGap = 16.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: scheme.primary.withValues(alpha: 0.5),
        ),
        Gap(iconGap),
        Text(
          title,
          style: isInline ? textTheme.titleSmall : textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          const Gap(textGap),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
        if (action != null && actionLabel != null) ...[
          const Gap(actionGap),
          FilledButton.tonal(onPressed: action, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

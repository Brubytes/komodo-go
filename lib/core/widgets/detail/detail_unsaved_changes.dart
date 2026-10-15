import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';

/// Sticky bar shown while a detail screen has unsaved edits.
///
/// Shows "N changes" (or [message]), a Discard button (confirmed through
/// [confirmDestructive]) and a Save button with a saving state.
class DetailUnsavedChangesBar extends StatelessWidget {
  const DetailUnsavedChangesBar({
    required this.onDiscard,
    required this.onSave,
    super.key,
    this.changeCount,
    this.message = 'Unsaved changes',
    this.saving = false,
    this.saveEnabled = true,
    this.confirmDiscard = true,
  });

  final VoidCallback onDiscard;
  final VoidCallback onSave;

  /// When > 0 the label reads "N changes" / "1 change".
  final int? changeCount;
  final String message;
  final bool saving;
  final bool saveEnabled;

  /// Ask for confirmation before invoking [onDiscard].
  final bool confirmDiscard;

  String get _label {
    final count = changeCount;
    if (count == null || count <= 0) return message;
    return count == 1 ? '1 change' : '$count changes';
  }

  Future<void> _handleDiscard(BuildContext context) async {
    if (saving) return;
    if (confirmDiscard) {
      final ok = await confirmDestructive(
        context,
        title: 'Discard changes?',
        message: 'Your unsaved edits will be lost.',
        confirmLabel: 'Discard',
      );
      if (!ok) return;
    }
    onDiscard();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      key: const ValueKey('detail_unsaved_changes_bar'),
      color: scheme.inverseSurface,
      elevation: 6,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _label,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onInverseSurface,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: scheme.onInverseSurface,
              ),
              onPressed: saving ? null : () => _handleDiscard(context),
              child: const Text('Discard'),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.secondary,
                foregroundColor: scheme.onSecondary,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: (saveEnabled && !saving) ? onSave : null,
              child: saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onSecondary,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks "Discard changes?" when the user navigates back while [dirty].
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    required this.dirty,
    required this.child,
    super.key,
    this.title = 'Discard changes?',
    this.message = 'You have unsaved changes that will be lost.',
    this.onDiscarded,
  });

  final bool dirty;
  final Widget child;
  final String title;
  final String message;

  /// Called after the user confirmed discarding, right before popping.
  final VoidCallback? onDiscarded;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final ok = await confirmDestructive(
          context,
          title: title,
          message: message,
          confirmLabel: 'Discard',
        );
        if (!ok) return;
        onDiscarded?.call();
        navigator.pop(result);
      },
      child: child,
    );
  }
}

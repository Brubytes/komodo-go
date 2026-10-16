import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';

/// Opens a modal bottom sheet configured for editors: scroll controlled,
/// safe-area aware, with a drag handle.
Future<T?> showEditorSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: useRootNavigator,
    showDragHandle: true,
    builder: builder,
  );
}

/// Shared layout for modal bottom-sheet editors.
///
/// Title row with Cancel (left) and Save (right), a scrollable body that
/// follows the keyboard, and a discard confirmation when [dirty].
class EditorSheetScaffold extends StatelessWidget {
  const EditorSheetScaffold({
    required this.title,
    required this.child,
    required this.onSave,
    super.key,
    this.saveLabel = 'Save',
    this.canSave = true,
    this.saving = false,
    this.dirty = false,
    this.onCancel,
  });

  final String title;
  final Widget child;

  /// Called when Save is pressed. Null disables the button.
  final VoidCallback? onSave;
  final String saveLabel;

  /// Save is disabled while false (e.g. form invalid).
  final bool canSave;
  final bool saving;

  /// When true, cancelling or dismissing asks to discard first.
  final bool dirty;

  /// Overrides the default cancel behaviour (pop the sheet).
  final VoidCallback? onCancel;

  Future<void> _cancel(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (dirty) {
      final ok = await confirmDestructive(
        context,
        title: 'Discard changes?',
        message: 'Your unsaved edits will be lost.',
        confirmLabel: 'Discard',
      );
      if (!ok) return;
    }
    if (onCancel != null) {
      onCancel!();
    } else {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final enabled = canSave && !saving && onSave != null;

    return PopScope<Object?>(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final ok = await confirmDestructive(
          context,
          title: 'Discard changes?',
          message: 'Your unsaved edits will be lost.',
          confirmLabel: 'Discard',
        );
        if (ok) navigator.pop(result);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: saving ? null : () => _cancel(context),
                      child: const Text('Cancel'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: enabled ? onSave : null,
                      child: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(saveLabel),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

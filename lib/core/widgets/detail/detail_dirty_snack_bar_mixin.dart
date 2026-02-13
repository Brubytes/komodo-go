import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

mixin DetailDirtySnackBarMixin<T extends StatefulWidget> on State<T> {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _dirtySnackBar;
  ScaffoldMessengerState? _dirtySnackBarMessenger;
  String? _dirtySnackBarMessage;
  bool? _dirtySnackBarSaveEnabled;

  bool get isDirtySnackBarVisible => _dirtySnackBar != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dirtySnackBarMessenger = ScaffoldMessenger.maybeOf(context);
  }

  void syncDirtySnackBar({
    required bool dirty,
    required VoidCallback onDiscard,
    required VoidCallback onSave,
    String message = 'Unsaved changes',
    bool saveEnabled = true,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!dirty) {
        hideDirtySnackBar();
      } else {
        showDirtySnackBar(
          onDiscard: onDiscard,
          onSave: onSave,
          message: message,
          saveEnabled: saveEnabled,
        );
      }
    });
  }

  void showDirtySnackBar({
    required VoidCallback onDiscard,
    required VoidCallback onSave,
    String message = 'Unsaved changes',
    bool saveEnabled = true,
  }) {
    if (_dirtySnackBar != null) {
      final needsUpdate =
          message != _dirtySnackBarMessage ||
          saveEnabled != _dirtySnackBarSaveEnabled;
      if (!needsUpdate) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _dirtySnackBar = null;
    }

    final messenger = _dirtySnackBarMessenger ?? ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final controller = messenger.showSnackBar(
      SnackBar(
        backgroundColor: scheme.inverseSurface,
        duration: const Duration(days: 1),
        dismissDirection: DismissDirection.none,
        behavior: SnackBarBehavior.floating,
        content: DefaultTextStyle(
          style: TextStyle(color: scheme.onInverseSurface),
          child: Row(
            children: [
              Expanded(child: Text(message)),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onInverseSurface,
                ),
                onPressed: onDiscard,
                child: const Text('Discard'),
              ),
              const Gap(8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.secondary,
                  foregroundColor: scheme.onSecondary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: saveEnabled ? onSave : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );

    _dirtySnackBar = controller;
    _dirtySnackBarMessage = message;
    _dirtySnackBarSaveEnabled = saveEnabled;
    unawaited(controller.closed.then((_) {
      if (!mounted) return;
      if (_dirtySnackBar == controller) {
        _dirtySnackBar = null;
        _dirtySnackBarMessage = null;
        _dirtySnackBarSaveEnabled = null;
      }
    }));
  }

  void hideDirtySnackBar() {
    if (_dirtySnackBar == null) return;
    _dirtySnackBarMessenger?.hideCurrentSnackBar();
    _dirtySnackBar = null;
    _dirtySnackBarMessage = null;
    _dirtySnackBarSaveEnabled = null;
  }

  @override
  void dispose() {
    if (_dirtySnackBar != null) {
      final messenger = _dirtySnackBarMessenger;
      if (messenger != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          messenger.removeCurrentSnackBar();
        });
      }
      _dirtySnackBar = null;
      _dirtySnackBarMessage = null;
      _dirtySnackBarSaveEnabled = null;
    }
    super.dispose();
  }

  void reShowDirtySnackBarIfStillDirty({
    required bool Function() isStillDirty,
    required VoidCallback onDiscard,
    required VoidCallback onSave,
    String message = 'Unsaved changes',
    bool saveEnabled = true,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isStillDirty()) {
        showDirtySnackBar(
          onDiscard: onDiscard,
          onSave: onSave,
          message: message,
          saveEnabled: saveEnabled,
        );
      }
    });
  }
}

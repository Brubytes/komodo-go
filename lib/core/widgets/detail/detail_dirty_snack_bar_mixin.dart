import 'dart:async';

import 'package:flutter/material.dart';
import 'package:komodo_go/core/widgets/detail/detail_unsaved_changes.dart';

mixin DetailDirtySnackBarMixin<T extends StatefulWidget> on State<T> {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _dirtySnackBar;
  ScaffoldMessengerState? _dirtySnackBarMessenger;
  String? _dirtySnackBarMessage;
  bool? _dirtySnackBarSaveEnabled;
  int? _dirtySnackBarChangeCount;
  bool? _dirtySnackBarSaving;

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
    int? changeCount,
    bool saving = false,
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
          changeCount: changeCount,
          saving: saving,
        );
      }
    });
  }

  void showDirtySnackBar({
    required VoidCallback onDiscard,
    required VoidCallback onSave,
    String message = 'Unsaved changes',
    bool saveEnabled = true,
    int? changeCount,
    bool saving = false,
  }) {
    if (_dirtySnackBar != null) {
      final needsUpdate =
          message != _dirtySnackBarMessage ||
          saveEnabled != _dirtySnackBarSaveEnabled ||
          changeCount != _dirtySnackBarChangeCount ||
          saving != _dirtySnackBarSaving;
      if (!needsUpdate) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _dirtySnackBar = null;
    }

    final messenger = _dirtySnackBarMessenger ?? ScaffoldMessenger.of(context);
    final controller = messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: const Duration(days: 1),
        dismissDirection: DismissDirection.none,
        behavior: SnackBarBehavior.floating,
        content: DetailUnsavedChangesBar(
          message: message,
          changeCount: changeCount,
          saving: saving,
          saveEnabled: saveEnabled,
          onDiscard: onDiscard,
          onSave: onSave,
        ),
      ),
    );

    _dirtySnackBar = controller;
    _dirtySnackBarMessage = message;
    _dirtySnackBarSaveEnabled = saveEnabled;
    _dirtySnackBarChangeCount = changeCount;
    _dirtySnackBarSaving = saving;
    unawaited(
      controller.closed.then((_) {
        if (!mounted) return;
        if (_dirtySnackBar == controller) {
          _dirtySnackBar = null;
          _dirtySnackBarMessage = null;
          _dirtySnackBarSaveEnabled = null;
          _dirtySnackBarChangeCount = null;
          _dirtySnackBarSaving = null;
        }
      }),
    );
  }

  void hideDirtySnackBar() {
    if (_dirtySnackBar == null) return;
    _dirtySnackBarMessenger?.hideCurrentSnackBar();
    _dirtySnackBar = null;
    _dirtySnackBarMessage = null;
    _dirtySnackBarSaveEnabled = null;
    _dirtySnackBarChangeCount = null;
    _dirtySnackBarSaving = null;
  }

  @override
  void dispose() {
    if (_dirtySnackBar != null) {
      final messenger = _dirtySnackBarMessenger;
      if (messenger != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!messenger.mounted) return;
          messenger.removeCurrentSnackBar();
        });
      }
      _dirtySnackBar = null;
      _dirtySnackBarMessage = null;
      _dirtySnackBarSaveEnabled = null;
      _dirtySnackBarChangeCount = null;
      _dirtySnackBarSaving = null;
    }
    super.dispose();
  }

  void reShowDirtySnackBarIfStillDirty({
    required bool Function() isStillDirty,
    required VoidCallback onDiscard,
    required VoidCallback onSave,
    String message = 'Unsaved changes',
    bool saveEnabled = true,
    int? changeCount,
    bool saving = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isStillDirty()) {
        showDirtySnackBar(
          onDiscard: onDiscard,
          onSave: onSave,
          message: message,
          saveEnabled: saveEnabled,
          changeCount: changeCount,
          saving: saving,
        );
      }
    });
  }
}

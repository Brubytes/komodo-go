import 'dart:async';

import 'package:flutter/material.dart';

/// Context menu builder that always includes a Paste action.
///
/// On iOS, the system may sometimes only show "Scan Text" for an empty field.
/// This ensures users can always paste credentials into input fields.
Widget alwaysPasteContextMenu(BuildContext context, EditableTextState state) {
  final items = state.contextMenuButtonItems;
  final hasPaste = items.any((i) => i.type == ContextMenuButtonType.paste);

  final buttonItems = [
    if (!hasPaste)
      ContextMenuButtonItem(
        type: ContextMenuButtonType.paste,
        onPressed: () {
          unawaited(state.pasteText(SelectionChangedCause.toolbar));
          state.hideToolbar();
        },
      ),
    ...items,
  ];

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: state.contextMenuAnchors,
    buttonItems: buttonItems,
  );
}

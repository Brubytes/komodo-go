import 'package:flutter/material.dart';

import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

/// A code editor surface with line numbers and syntax highlighting.
class DetailCodeEditor extends StatelessWidget {
  const DetailCodeEditor({
    required this.controller,
    super.key,
    this.maxHeight = 360,
    this.readOnly = false,
  });

  final CodeEditorController controller;
  final double maxHeight;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCardSurface(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: maxHeight,
        width: double.infinity,
        child: CodeEditor(
          controller: controller,
          readOnly: readOnly,
          textStyle:
              textTheme.bodySmall?.copyWith(fontFamily: 'monospace') ??
              const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

/// A code editor surface with line numbers and syntax highlighting.
class DetailCodeEditor extends StatelessWidget {
  const DetailCodeEditor({
    required this.controller,
    super.key,
    this.maxHeight = 360,
    this.readOnly = false,
    this.enableFullscreen = true,
    this.fullscreenTitle,
  });

  final CodeEditorController controller;
  final double maxHeight;
  final bool readOnly;
  final bool enableFullscreen;
  final String? fullscreenTitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCardSurface(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          SizedBox(
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
          if (enableFullscreen)
            Positioned(
              top: 2,
              right: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: IconButton(
                  tooltip: 'Open in full screen',
                  icon: const Icon(AppIcons.expand),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (context) => _DetailCodeEditorFullscreen(
                        controller: controller,
                        readOnly: readOnly,
                        title: fullscreenTitle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailCodeEditorFullscreen extends StatelessWidget {
  const _DetailCodeEditorFullscreen({
    required this.controller,
    required this.readOnly,
    this.title,
  });

  final CodeEditorController controller;
  final bool readOnly;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'File editor'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(AppIcons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppCardSurface(
            radius: 16,
            padding: const EdgeInsets.all(12),
            child: SizedBox.expand(
              child: CodeEditor(
                controller: controller,
                readOnly: readOnly,
                textStyle:
                    textTheme.bodyMedium?.copyWith(fontFamily: 'monospace') ??
                    const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

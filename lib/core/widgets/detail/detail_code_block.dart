import 'package:flutter/material.dart';

import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

enum DetailCodeLanguage { plainText, yaml, typescript }

/// A scrollable, selectable code block with lightweight syntax highlighting.
///
/// Note: Light mode uses no gradients (handled by DetailSurface).
class DetailCodeBlock extends StatelessWidget {
  const DetailCodeBlock({
    required this.code,
    super.key,
    this.language = DetailCodeLanguage.plainText,
    this.maxHeight = 360,
  });

  final String code;
  final DetailCodeLanguage language;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final span = _highlight(context, code);

    return AppCardSurface(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: SelectableText.rich(
            TextSpan(
              style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              children: [span],
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _highlight(BuildContext context, String input) {
    final languageName = switch (language) {
      DetailCodeLanguage.plainText => null,
      DetailCodeLanguage.yaml => 'yaml',
      DetailCodeLanguage.typescript => 'typescript',
    };

    if (languageName == null) return TextSpan(text: input);

    final theme = Theme.of(context).brightness == Brightness.dark
        ? AppSyntaxHighlight.darkTheme
        : AppSyntaxHighlight.lightTheme;

    return Highlighter(language: languageName, theme: theme).highlight(input);
  }
}

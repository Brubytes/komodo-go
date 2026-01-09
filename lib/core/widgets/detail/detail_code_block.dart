import 'package:flutter/material.dart';

import 'package:komodo_go/core/widgets/detail/detail_surface.dart';

enum DetailCodeLanguage { plainText, yaml }

/// A scrollable, selectable code block with lightweight syntax highlighting.
///
/// Note: Light mode uses no gradients (handled by [DetailSurface]).
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final span = switch (language) {
      DetailCodeLanguage.yaml => _highlightYaml(context, code),
      DetailCodeLanguage.plainText => TextSpan(text: code),
    };

    return DetailSurface(
      baseColor: scheme.surfaceContainerHighest,
      enableGradientInDark: false,
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

  TextSpan _highlightYaml(BuildContext context, String input) {
    final scheme = Theme.of(context).colorScheme;

    final keyStyle = TextStyle(
      color: scheme.primary,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = TextStyle(color: scheme.onSurface);
    final stringStyle = TextStyle(color: scheme.tertiary);
    final numberStyle = TextStyle(color: scheme.secondary);
    final commentStyle = TextStyle(color: scheme.onSurfaceVariant);
    final punctuationStyle = TextStyle(color: scheme.onSurfaceVariant);

    final spans = <InlineSpan>[];
    final lines = input.split('\n');

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];

      final commentStart = _yamlCommentStart(line);
      final codePart = commentStart == null
          ? line
          : line.substring(0, commentStart);
      final commentPart = commentStart == null
          ? null
          : line.substring(commentStart);

      final match = RegExp(
        r'^(\s*)([^:#\n]+?)(\s*):(\s*)(.*)$',
      ).firstMatch(codePart);

      if (match != null) {
        spans
          ..add(TextSpan(text: match.group(1)))
          ..add(TextSpan(text: match.group(2), style: keyStyle))
          ..add(TextSpan(text: match.group(3), style: punctuationStyle))
          ..add(TextSpan(text: ':', style: punctuationStyle))
          ..add(TextSpan(text: match.group(4)));

        final rest = match.group(5) ?? '';
        spans.addAll(
          _highlightYamlValue(rest, valueStyle, stringStyle, numberStyle),
        );
      } else {
        spans.addAll(
          _highlightYamlValue(codePart, valueStyle, stringStyle, numberStyle),
        );
      }

      if (commentPart != null && commentPart.isNotEmpty) {
        spans.add(TextSpan(text: commentPart, style: commentStyle));
      }

      if (lineIndex != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: spans);
  }

  List<InlineSpan> _highlightYamlValue(
    String value,
    TextStyle valueStyle,
    TextStyle stringStyle,
    TextStyle numberStyle,
  ) {
    if (value.isEmpty) return [TextSpan(text: value, style: valueStyle)];

    final spans = <InlineSpan>[];
    final tokenPattern = RegExp(
      "(\\\"[^\\\"]*\\\"|'[^']*'|\\b(true|false|null)\\b|\\b-?\\d+(\\.\\d+)?\\b)",
      caseSensitive: false,
    );

    var index = 0;
    for (final match in tokenPattern.allMatches(value)) {
      if (match.start > index) {
        spans.add(
          TextSpan(
            text: value.substring(index, match.start),
            style: valueStyle,
          ),
        );
      }

      final token = match.group(0) ?? '';
      if (token.startsWith('"') || token.startsWith("'")) {
        spans.add(TextSpan(text: token, style: stringStyle));
      } else if (RegExp(
        r'^(true|false|null)$',
        caseSensitive: false,
      ).hasMatch(token)) {
        spans.add(TextSpan(text: token, style: stringStyle));
      } else {
        spans.add(TextSpan(text: token, style: numberStyle));
      }

      index = match.end;
    }

    if (index < value.length) {
      spans.add(TextSpan(text: value.substring(index), style: valueStyle));
    }

    return spans;
  }

  int? _yamlCommentStart(String line) {
    var inSingle = false;
    var inDouble = false;

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == "'" && !inDouble) {
        inSingle = !inSingle;
      } else if (c == '"' && !inSingle) {
        inDouble = !inDouble;
      } else if (c == '#' && !inSingle && !inDouble) {
        return i;
      }
    }
    return null;
  }
}

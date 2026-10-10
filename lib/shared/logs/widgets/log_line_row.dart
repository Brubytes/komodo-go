import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/shared/logs/log_line.dart';

/// Shared text styles for log rows, resolved once per build.
class LogRowStyles {
  LogRowStyles.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    this.scheme = scheme;
    base = Theme.of(context).textTheme.bodySmall!.copyWith(
      fontFamily: 'monospace',
      height: 1.4,
      color: scheme.onSurface,
    );
    time = base.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7));
    match = TextStyle(
      backgroundColor: scheme.tertiaryContainer,
      color: scheme.onTertiaryContainer,
      fontWeight: FontWeight.w600,
    );
  }

  late final ColorScheme scheme;
  late final TextStyle base;
  late final TextStyle time;
  late final TextStyle match;

  Color? barColor(LogSeverity severity) => switch (severity) {
    LogSeverity.error => scheme.error,
    LogSeverity.warning => AppTokens.statusOrange,
    LogSeverity.normal => null,
  };
}

class LogLineRow extends StatelessWidget {
  const LogLineRow({
    required this.line,
    required this.terms,
    required this.styles,
    required this.wrap,
    super.key,
  });

  final LogLine line;
  final List<String> terms;
  final LogRowStyles styles;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final bar = styles.barColor(line.severity);
    final time = line.time;
    final message = Text.rich(
      TextSpan(children: highlightLogTerms(line.message, terms, styles.match)),
      style: styles.base,
      softWrap: wrap,
      maxLines: wrap ? null : 1,
      overflow: wrap ? null : TextOverflow.clip,
    );
    return InkWell(
      onTap: () => showLogLineSheet(context, line),
      child: Container(
        decoration: BoxDecoration(
          color: line.severity == LogSeverity.error
              ? styles.scheme.errorContainer.withValues(alpha: 0.25)
              : null,
          border: Border(
            left: BorderSide(color: bar ?? Colors.transparent, width: 3),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(9, 2, 12, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (time != null) ...[Text(time, style: styles.time), const Gap(8)],
            // Expanded gives wrapped continuation lines a hanging indent.
            Expanded(child: message),
          ],
        ),
      ),
    );
  }
}

class LogDateDividerRow extends StatelessWidget {
  const LogDateDividerRow({required this.date, super.key});

  final String date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Text(
            date,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Gap(8),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}

Future<void> showLogLineSheet(BuildContext context, LogLine line) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Log line', style: textTheme.titleLarge),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('log_line_copy'),
                  onPressed: () {
                    unawaited(Clipboard.setData(ClipboardData(text: line.raw)));
                    Navigator.pop(context);
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('Line copied')),
                    );
                  },
                  icon: const Icon(AppIcons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const Gap(16),
            SelectableText(
              line.raw,
              style: textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Splits [text] into spans, styling case-insensitive occurrences of [terms].
List<TextSpan> highlightLogTerms(
  String text,
  List<String> terms,
  TextStyle matchStyle,
) {
  final patterns = terms.where((term) => term.isNotEmpty).toList();
  if (patterns.isEmpty) return [TextSpan(text: text)];
  // Longest first so overlapping terms prefer the fuller match.
  patterns.sort((a, b) => b.length.compareTo(a.length));
  final regex = RegExp(
    patterns.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(TextSpan(text: match[0], style: matchStyle));
    cursor = match.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}

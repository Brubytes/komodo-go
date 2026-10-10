import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/shared/logs/server_log_controller.dart';

/// Monospace log output with search-term highlighting and a footer that
/// carries line count, last update and copy / expand actions.
class ServerLogViewer extends StatelessWidget {
  const ServerLogViewer({
    required this.controller,
    this.height,
    this.onExpand,
    super.key,
  });

  final ServerLogController controller;

  /// Fixed height for inline use; null fills the parent (full-screen).
  final double? height;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final output = AppCardSurface(
          radius: 16,
          padding: EdgeInsets.zero,
          child: _buildBody(context),
        );
        return Column(
          mainAxisSize: height == null ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (height == null)
              Expanded(child: output)
            else
              SizedBox(height: height, child: output),
            _Footer(controller: controller, onExpand: onExpand),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final log = controller.log;
    final error = controller.error;

    if (controller.loading && log == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _Message(
        icon: AppIcons.formError,
        text: 'Logs unavailable: $error',
        color: scheme.error,
      );
    }
    final text = log?.combined ?? '';
    if (text.isEmpty) {
      return _Message(
        icon: AppIcons.logs,
        text: controller.isSearching
            ? 'No matching log lines.'
            : 'No log output.',
        color: scheme.onSurfaceVariant,
      );
    }

    final baseStyle = textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.45,
    );
    // Inverted searches return non-matching lines, so nothing to highlight.
    final terms = controller.invert ? const <String>[] : controller.terms;
    return Stack(
      children: [
        Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: SelectableText.rich(
                TextSpan(
                  style: baseStyle,
                  children: highlightLogTerms(
                    text,
                    terms,
                    TextStyle(
                      backgroundColor: scheme.tertiaryContainer,
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (controller.loading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
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

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const Gap(8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller, this.onExpand});

  final ServerLogController controller;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final text = controller.log?.combined ?? '';
    final lineCount = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
    final updatedAt = controller.updatedAt;
    final parts = [
      '$lineCount ${lineCount == 1 ? 'line' : 'lines'}',
      if (updatedAt != null) 'updated ${_formatTime(updatedAt)}',
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Gap(4),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: const ValueKey('server_log_copy'),
            tooltip: 'Copy logs',
            visualDensity: VisualDensity.compact,
            onPressed: text.isEmpty ? null : () => _copy(context, text),
            icon: const Icon(AppIcons.copy, size: 18),
          ),
          if (onExpand != null)
            IconButton(
              key: const ValueKey('server_log_expand'),
              tooltip: 'Full screen',
              visualDensity: VisualDensity.compact,
              onPressed: onExpand,
              icon: const Icon(AppIcons.expand, size: 18),
            ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Logs copied')));
  }

  static String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

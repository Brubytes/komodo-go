import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/shared/logs/log_line.dart';
import 'package:komodo_go/shared/logs/server_log_controller.dart';
import 'package:komodo_go/shared/logs/widgets/log_line_row.dart';

export 'package:komodo_go/shared/logs/widgets/log_line_row.dart'
    show highlightLogTerms;

/// Line-by-line log output that opens at the newest line and follows new
/// output like `tail -f`. Scrolling up pauses the view; a pill then offers
/// the new lines and jumps back to the bottom.
///
/// Raw text mode swaps the rows for one plain selectable block so ranges of
/// lines can be copied; it holds new output behind the pill so a selection
/// is never reset by a refresh.
class ServerLogViewer extends StatefulWidget {
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
  State<ServerLogViewer> createState() => _ServerLogViewerState();
}

class _ServerLogViewerState extends State<ServerLogViewer> {
  /// Distance from the bottom that still counts as "following".
  static const _followTolerance = 16.0;

  // The list is reversed, so offset 0 is the newest line.
  final _scroll = ScrollController();
  final _horizontalScroll = ScrollController();
  final _rawScroll = ScrollController();

  String? _shownText;
  int _shownVersion = -1;
  List<LogEntry> _entries = const [];
  String _rawContent = '';
  var _shownRaw = false;
  var _following = true;
  var _atTop = false;

  /// New lines waiting while the view is paused; null when none, -1 when
  /// the count is unknown (the old tail no longer overlaps).
  int? _pending;

  ServerLogController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _scroll.addListener(_onScroll);
    _adopt();
  }

  @override
  void didUpdateWidget(covariant ServerLogViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _adopt();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _scroll.dispose();
    _horizontalScroll.dispose();
    _rawScroll.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final raw = _controller.rawText;
    if (raw != _shownRaw) {
      _shownRaw = raw;
      // Both views open at the newest line, so start out following again.
      _following = true;
      _atTop = false;
      if (!raw && _pending != null) _adopt();
    }
    final latest = _controller.log?.combined;
    if (latest == null || latest == _shownText) {
      setState(() {});
      return;
    }
    final queryChanged = _controller.logVersion != _shownVersion;
    if (queryChanged || (_following && !raw) || _shownText == null) {
      _adopt();
      if (queryChanged) _jumpToBottom(animate: false);
    } else {
      _pending = _countNewLines(_shownText!, latest);
    }
    setState(() {});
  }

  /// Shows the controller's latest snapshot.
  void _adopt() {
    final text = _controller.log?.combined;
    _pending = null;
    _shownVersion = _controller.logVersion;
    if (text == _shownText) return;
    _shownText = text;
    _entries = parseLogEntries(text ?? '');
    _rawContent = stripAnsi(text ?? '').replaceAll('\r', '');
  }

  void _onScroll() {
    final position = _scroll.position;
    final following = position.pixels <= _followTolerance;
    final atTop =
        position.pixels >= position.maxScrollExtent - _followTolerance;
    if (following == _following && atTop == _atTop) return;
    setState(() {
      _following = following;
      _atTop = atTop;
      if (following && _pending != null) _adopt();
    });
  }

  void _jumpToBottom({bool animate = true}) {
    if (!_scroll.hasClients) return;
    if (animate && _scroll.offset < 3000) {
      unawaited(AppMotion.animateOrJump(_scroll, 0, context));
    } else {
      _scroll.jumpTo(0);
    }
  }

  Future<void> _jumpToTop() async {
    // Lazy lists only estimate their extent, so settle over a few frames.
    for (var attempt = 0; attempt < 6; attempt++) {
      if (!_scroll.hasClients || !mounted) return;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(max);
      await WidgetsBinding.instance.endOfFrame;
      if (!_scroll.hasClients || _scroll.position.maxScrollExtent == max) {
        return;
      }
    }
  }

  void _showLatest() {
    setState(_adopt);
    if (_controller.rawText) {
      if (_rawScroll.hasClients) _rawScroll.jumpTo(0);
    } else {
      _jumpToBottom();
    }
  }

  static int? _countNewLines(String shown, String latest) {
    final lastShown = shown.substring(shown.lastIndexOf('\n') + 1);
    final latestLines = latest.split('\n');
    final index = latestLines.lastIndexOf(lastShown);
    if (index < 0) return -1;
    final count = latestLines.length - 1 - index;
    return count == 0 ? null : count;
  }

  @override
  Widget build(BuildContext context) {
    final output = AppCardSurface(
      radius: 16,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _buildBody(context),
      ),
    );
    return Column(
      mainAxisSize: widget.height == null ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.height == null)
          Expanded(child: output)
        else
          SizedBox(height: widget.height, child: output),
        _Footer(
          text: _shownText ?? '',
          updatedAt: _controller.updatedAt,
          rawText: _controller.rawText,
          onRawTextChanged: (value) => _controller.setRawText(value: value),
          onExpand: widget.onExpand,
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = _controller.error;

    if (_controller.loading && _shownText == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && _entries.isEmpty) {
      return _Message(
        icon: AppIcons.formError,
        text: 'Logs unavailable: $error',
        color: scheme.error,
      );
    }
    if (_entries.isEmpty) {
      return _Message(
        icon: AppIcons.logs,
        text: _controller.isSearching
            ? 'No matching log lines.'
            : 'No log output.',
        color: scheme.onSurfaceVariant,
      );
    }

    final styles = LogRowStyles.of(context);
    // Inverted searches return non-matching lines, so nothing to highlight.
    final terms = _controller.invert ? const <String>[] : _controller.terms;
    final wrap = _controller.wrapLines;

    if (_controller.rawText) return _buildRawBody(styles, wrap: wrap);

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final list = Scrollbar(
              controller: _scroll,
              child: ListView.builder(
                key: const ValueKey('server_log_lines'),
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[_entries.length - 1 - index];
                  return switch (entry) {
                    LogDateDivider(:final date) => LogDateDividerRow(
                      date: date,
                    ),
                    LogLineEntry(:final line) => LogLineRow(
                      line: line,
                      terms: terms,
                      styles: styles,
                      wrap: wrap,
                    ),
                  };
                },
              ),
            );
            if (wrap) return list;
            return Scrollbar(
              controller: _horizontalScroll,
              child: SingleChildScrollView(
                controller: _horizontalScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(
                    constraints.maxWidth,
                    _unwrappedWidth(context, styles),
                  ),
                  height: constraints.maxHeight,
                  child: list,
                ),
              ),
            );
          },
        ),
        if (_controller.loading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Positioned(
          top: 10,
          right: 10,
          child: AppSwitcher(
            animateSize: false,
            child: !_following && !_atTop
                ? _JumpButton(
                    key: const ValueKey('server_log_jump_top'),
                    icon: Icons.arrow_upward,
                    label: 'Top',
                    onPressed: _jumpToTop,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: AppSwitcher(
              animateSize: false,
              child: !_following
                  ? _JumpButton(
                      key: const ValueKey('server_log_jump_latest'),
                      icon: Icons.arrow_downward,
                      label: switch (_pending) {
                        null => 'Latest',
                        -1 => 'New lines',
                        1 => '1 new line',
                        final count => '$count new lines',
                      },
                      emphasized: _pending != null,
                      onPressed: _showLatest,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRawBody(LogRowStyles styles, {required bool wrap}) {
    final text = SelectableText(
      _rawContent,
      key: const ValueKey('server_log_raw_text'),
      style: styles.base,
    );
    return Stack(
      children: [
        Scrollbar(
          controller: _rawScroll,
          child: SingleChildScrollView(
            controller: _rawScroll,
            // Opens at the newest line, like the formatted view.
            reverse: true,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: wrap
                ? text
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: text,
                  ),
          ),
        ),
        if (_controller.loading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: AppSwitcher(
              animateSize: false,
              child: _pending != null
                  ? _JumpButton(
                      key: const ValueKey('server_log_jump_latest'),
                      icon: Icons.arrow_downward,
                      label: switch (_pending) {
                        -1 => 'New lines',
                        1 => '1 new line',
                        final count => '$count new lines',
                      },
                      emphasized: true,
                      onPressed: _showLatest,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  /// Width needed to show the longest line unwrapped (monospace font).
  double _unwrappedWidth(BuildContext context, LogRowStyles styles) {
    final painter = TextPainter(
      text: TextSpan(text: '0', style: styles.base),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final charWidth = painter.width;
    painter.dispose();
    var longest = 0;
    for (final entry in _entries) {
      if (entry is! LogLineEntry) continue;
      final line = entry.line;
      final length =
          line.message.length +
          (line.time == null ? 0 : 10) +
          (line.service == null ? 0 : line.service!.length + 2);
      if (length > longest) longest = length;
    }
    return longest * charWidth + 32;
  }
}

class _JumpButton extends StatelessWidget {
  const _JumpButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = emphasized
        ? scheme.primary
        : scheme.surfaceContainerHighest;
    final foreground = emphasized ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: background,
      elevation: 3,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const Gap(AppSpacing.xs),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const Gap(AppSpacing.sm),
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
  const _Footer({
    required this.text,
    required this.updatedAt,
    required this.rawText,
    required this.onRawTextChanged,
    this.onExpand,
  });

  final String text;
  final DateTime? updatedAt;
  final bool rawText;
  final ValueChanged<bool> onRawTextChanged;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final lineCount = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
    final updatedAt = this.updatedAt;
    final parts = [
      '$lineCount ${lineCount == 1 ? 'line' : 'lines'}',
      if (updatedAt != null) 'updated ${_formatTime(updatedAt)}',
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          const Gap(AppSpacing.xs),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: const ValueKey('server_log_raw_toggle'),
            tooltip: rawText ? 'Formatted view' : 'Raw text (select to copy)',
            visualDensity: VisualDensity.compact,
            isSelected: rawText,
            onPressed: () => onRawTextChanged(!rawText),
            icon: const Icon(AppIcons.notepadText, size: 18),
          ),
          IconButton(
            key: const ValueKey('server_log_copy'),
            tooltip: 'Copy logs',
            visualDensity: VisualDensity.compact,
            onPressed: text.isEmpty
                ? null
                : () => _copy(context, stripAnsi(text)),
            icon: const Icon(AppIcons.copy, size: 18),
          ),
          if (onExpand != null)
            TextButton.icon(
              key: const ValueKey('server_log_expand'),
              onPressed: onExpand,
              icon: const Icon(AppIcons.expand, size: 16),
              label: const Text('Full screen'),
            ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    AppSnackBar.show(context, 'Logs copied');
  }

  static String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

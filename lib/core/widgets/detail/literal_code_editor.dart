// Adapted from syntax_highlight 0.5.0 to preserve literal iOS code input.
// Upstream license (also bundled with syntax_highlight):
// Copyright 2023 The Serverpod authors
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
// following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
// disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
// disclaimer in the documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products
// derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

/// Width of the line number gutter in logical pixels
const _gutterWidth = 40.0;

/// Margin between the gutter and main text area in logical pixels
const _gutterMargin = 8.0;

/// A code editor widget with syntax highlighting and line numbers.
class LiteralCodeEditor extends StatefulWidget {
  /// Creates a code editor widget.
  ///
  /// The [textStyle] parameter defines the base text style for the editor content.
  /// The [controller] parameter manages the text content and syntax highlighting.
  /// Set [readOnly] to true to prevent editing of the content.
  const LiteralCodeEditor({
    required this.textStyle,
    required this.controller,
    this.readOnly = false,
    super.key,
  });

  /// The base text style for the editor content.
  final TextStyle textStyle;

  /// Controller that manages the text content and syntax highlighting.
  final CodeEditorController controller;

  /// Whether the editor content can be modified.
  ///
  /// When true, the editor becomes read-only and user input is ignored.
  final bool readOnly;

  @override
  State<LiteralCodeEditor> createState() => _LiteralCodeEditorState();
}

class _LiteralCodeEditorState extends State<LiteralCodeEditor> {
  final _lineNumberController = TextEditingController();
  double? _codeFieldWidth;
  final _codeScrollController = ScrollController();
  final _lineNumberScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateLineNumbers);

    _codeScrollController.addListener(() {
      if (_lineNumberScrollController.hasClients) {
        _lineNumberScrollController.jumpTo(
          _codeScrollController.offset.clamp(
            0.0,
            _lineNumberScrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void _updateLineNumbers() {
    _lineNumberController.text = _computeLineNumbers();
  }

  @override
  void didUpdateWidget(covariant LiteralCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateLineNumbers);
      widget.controller.addListener(_updateLineNumbers);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateLineNumbers);
    _lineNumberController.dispose();
    _codeScrollController.dispose();
    _lineNumberScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: _gutterWidth - _gutterMargin,
          padding: const EdgeInsets.only(right: 4),
          margin: const EdgeInsets.only(right: _gutterMargin),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: IgnorePointer(
            child: ScrollConfiguration(
              behavior: const _HiddenHandleScrollBehavior(),
              child: TextField(
                scrollController: _lineNumberScrollController,
                readOnly: true,
                scrollPadding: EdgeInsets.zero,
                style: widget.textStyle.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
                controller: _lineNumberController,
                textAlign: TextAlign.right,
                maxLines: null,
                expands: true,
                decoration: null,
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final codeFieldWidth = constraints.maxWidth;
              if (codeFieldWidth != _codeFieldWidth) {
                _codeFieldWidth = codeFieldWidth;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _updateLineNumbers();
                });
              }

              return Shortcuts(
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.tab): const _TabIntent(),
                  LogicalKeySet(
                    LogicalKeyboardKey.shift,
                    LogicalKeyboardKey.tab,
                  ): const _ShiftTabIntent(),
                },
                child: Actions(
                  actions: {
                    _TabIntent: _TabAction(widget.controller),
                    _ShiftTabIntent: _ShiftTabAction(widget.controller),
                  },
                  child: TextField(
                    readOnly: widget.readOnly,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartQuotesType: SmartQuotesType.disabled,
                    smartDashesType: SmartDashesType.disabled,
                    scrollPadding: EdgeInsets.zero,
                    scrollController: _codeScrollController,
                    style: widget.textStyle,
                    controller: widget.controller,
                    maxLines: null,
                    expands: true,
                    decoration: null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _computeLineNumbers() {
    if (_codeFieldWidth == null) {
      return '';
    }

    final text = widget.controller.text;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: text,
        style: widget.textStyle,
      ),
    )..layout(maxWidth: _codeFieldWidth!);

    var lineNumberText = '';
    var lineNumber = 1;
    var wroteLineNumber = false;
    final metrics = textPainter.computeLineMetrics();

    for (final metric in metrics) {
      if (!wroteLineNumber) {
        lineNumberText += '$lineNumber\n';
        lineNumber += 1;
        wroteLineNumber = true;
      } else {
        lineNumberText += '\n';
      }

      if (metric.hardBreak) {
        wroteLineNumber = false;
      }
    }

    if (lineNumberText.isEmpty) {
      lineNumberText = '1';
    }

    textPainter.dispose();
    return lineNumberText;
  }
}

/// A custom scroll behavior that hides the scrollbar.
///
/// This is used for the line number gutter to ensure it matches
/// the main text area's scrolling without showing its own scrollbar.
class _HiddenHandleScrollBehavior extends ScrollBehavior {
  const _HiddenHandleScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _TabAction extends Action<_TabIntent> {
  _TabAction(
    this._textEditingController,
  );

  final TextEditingController _textEditingController;

  @override
  Object? invoke(_TabIntent intent) {
    final selection = _textEditingController.selection;
    final text = _textEditingController.text;

    if (selection.isCollapsed) {
      // Single cursor - insert 2 spaces
      final newText =
          '${text.substring(0, selection.start)}  ${text.substring(selection.end)}';
      _textEditingController.text = newText;
      _textEditingController.selection = TextSelection.collapsed(
        offset: selection.start + 2,
      );
    } else {
      // Multi-line selection - indent each line from the beginning
      final start = selection.start;
      final end = selection.end;

      // Find the start of the first line that contains selection
      var lineStart = start;
      while (lineStart > 0 && text[lineStart - 1] != '\n') {
        lineStart--;
      }

      // Find the end of the last line that contains selection
      var lineEnd = end;
      while (lineEnd < text.length && text[lineEnd] != '\n') {
        lineEnd++;
      }

      // Get the text from the start of first line to end of last line
      final fullLineText = text.substring(lineStart, lineEnd);
      final lines = fullLineText.split('\n');
      final indentedLines = lines.map((line) => '  $line').join('\n');

      final newText =
          text.substring(0, lineStart) +
          indentedLines +
          text.substring(lineEnd);
      _textEditingController.text = newText;

      // Maintain selection but adjust for added spaces and line boundaries
      final addedSpaces = lines.length * 2;
      final startOffset = start - lineStart;
      final endOffset = end - lineStart;

      _textEditingController.selection = TextSelection(
        baseOffset: lineStart + startOffset + (start == lineStart ? 2 : 0),
        extentOffset: lineStart + endOffset + addedSpaces,
      );
    }
    return null;
  }
}

class _TabIntent extends Intent {
  const _TabIntent();
}

class _ShiftTabAction extends Action<_ShiftTabIntent> {
  _ShiftTabAction(
    this._textEditingController,
  );

  final TextEditingController _textEditingController;

  @override
  Object? invoke(_ShiftTabIntent intent) {
    final selection = _textEditingController.selection;
    final text = _textEditingController.text;

    if (selection.isCollapsed) {
      // Single cursor - insert 2 spaces
      final newText =
          '${text.substring(0, selection.start)}  ${text.substring(selection.end)}';
      _textEditingController.text = newText;
      _textEditingController.selection = TextSelection.collapsed(
        offset: selection.start + 2,
      );
    } else {
      // Multi-line selection - unindent each line by 2 spaces
      final start = selection.start;
      final end = selection.end;

      // Find the start of the first line that contains selection
      var lineStart = start;
      while (lineStart > 0 && text[lineStart - 1] != '\n') {
        lineStart--;
      }

      // Find the end of the last line that contains selection
      var lineEnd = end;
      while (lineEnd < text.length && text[lineEnd] != '\n') {
        lineEnd++;
      }

      // Get the text from the start of first line to end of last line
      final fullLineText = text.substring(lineStart, lineEnd);
      final lines = fullLineText.split('\n');
      final unindentedLines = lines
          .map((line) {
            if (line.startsWith('  ')) {
              return line.substring(2);
            }
            return line;
          })
          .join('\n');

      final newText =
          text.substring(0, lineStart) +
          unindentedLines +
          text.substring(lineEnd);
      _textEditingController.text = newText;

      // Calculate how many spaces were removed
      var removedSpaces = 0;
      for (final line in lines) {
        if (line.startsWith('  ')) {
          removedSpaces += 2;
        }
      }

      // Maintain selection but adjust for removed spaces and line boundaries
      final startOffset = start - lineStart;
      final endOffset = end - lineStart;

      _textEditingController.selection = TextSelection(
        baseOffset: lineStart + startOffset,
        extentOffset: lineStart + endOffset - removedSpaces,
      );
    }
    return null;
  }
}

class _ShiftTabIntent extends Intent {
  const _ShiftTabIntent();
}

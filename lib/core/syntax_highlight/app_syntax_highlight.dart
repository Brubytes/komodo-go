import 'package:syntax_highlight/syntax_highlight.dart';

/// App-level initialization wrapper for `syntax_highlight`.
class AppSyntaxHighlight {
  static bool _isInitialized = false;

  static late final HighlighterTheme lightTheme;
  static late final HighlighterTheme darkTheme;

  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    final results = await Future.wait<Object?>([
      Highlighter.initialize(['yaml', 'typescript']),
      HighlighterTheme.loadLightTheme(),
      HighlighterTheme.loadDarkTheme(),
    ]);
    lightTheme = results[1]! as HighlighterTheme;
    darkTheme = results[2]! as HighlighterTheme;

    _isInitialized = true;
  }
}

import 'package:syntax_highlight/syntax_highlight.dart';

/// App-level initialization wrapper for `syntax_highlight`.
class AppSyntaxHighlight {
  static bool _isInitialized = false;

  static late final HighlighterTheme lightTheme;
  static late final HighlighterTheme darkTheme;

  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    await Highlighter.initialize([
      'yaml',
      'typescript',
    ]);

    lightTheme = await HighlighterTheme.loadLightTheme();
    darkTheme = await HighlighterTheme.loadDarkTheme();

    _isInitialized = true;
  }
}

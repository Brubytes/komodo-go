import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/core/widgets/detail/detail_code_editor.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

void main() {
  setUpAll(AppSyntaxHighlight.ensureInitialized);

  testWidgets('inline and fullscreen editors preserve literal code input', (
    tester,
  ) async {
    final controller = CodeEditorController(
      text: 'services: {}',
      lightHighlighter: Highlighter(
        language: 'yaml',
        theme: AppSyntaxHighlight.lightTheme,
      ),
      darkHighlighter: Highlighter(
        language: 'yaml',
        theme: AppSyntaxHighlight.darkTheme,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DetailCodeEditor(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> checkEditor() async {
      final field = find.byWidgetPredicate(
        (w) => w is EditableText && w.controller == controller,
      );
      await tester.showKeyboard(field);
      final config = tester.testTextInput.setClientArgs!;
      expect(config['autocorrect'], false);
      expect(config['enableSuggestions'], false);
      expect(config['smartQuotesType'], '0');
      expect(config['smartDashesType'], '0');
      await tester.enterText(
        field,
        '{"services":{"qa":{"image":"nginx:alpine"}}}',
      );
      await tester.pump();
    }

    await checkEditor();
    await tester.tap(find.byTooltip('Open in full screen'));
    await tester.pumpAndSettle();
    await checkEditor();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(controller.text, '{"services":{"qa":{"image":"nginx:alpine"}}}');
    // A closed fullscreen editor must detach its controller listener.
    controller.text = 'services: {}';
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

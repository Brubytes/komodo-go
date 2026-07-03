import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/views/stack_detail/stack_detail_sections.dart';

void main() {
  setUpAll(() async {
    await AppSyntaxHighlight.ensureInitialized();
  });

  const fileA = StackRemoteFileContents(
    path: 'a/compose.yml',
    contents: 'services: {}',
  );
  const fileB = StackRemoteFileContents(
    path: 'b/compose.yml',
    contents: 'services:\n  b: {}',
  );

  Widget host(StackInfo info) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StackInfoTabContent(
            info: info,
            onSaveFile: (path, contents, {showSnackBar = true}) async => true,
          ),
        ),
      ),
    );
  }

  testWidgets('handles remote files disappearing between refreshes', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const StackInfo(remoteContents: [fileA, fileB])),
    );
    expect(find.text('a/compose.yml'), findsOneWidget);
    expect(find.text('b/compose.yml'), findsOneWidget);

    // Make fileB dirty by editing its code editor (each CodeEditor renders
    // two text fields: line numbers + content, so find B's by its contents).
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == fileB.contents,
      ),
      'services:\n  changed: {}',
    );
    await tester.pump();
    final state = tester.state<StackInfoTabContentState>(
      find.byType(StackInfoTabContent),
    );
    expect(state.isDirty, isTrue);

    // Refresh drops fileB (e.g. file_paths changed server-side). This must
    // neither throw ConcurrentModificationError nor leave phantom dirty state.
    await tester.pumpWidget(host(const StackInfo(remoteContents: [fileA])));
    expect(tester.takeException(), isNull);
    expect(find.text('b/compose.yml'), findsNothing);
    expect(state.isDirty, isFalse);
  });
}

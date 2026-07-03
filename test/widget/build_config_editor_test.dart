import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/views/build_detail/build_detail_sections.dart';

void main() {
  testWidgets('clearing a text field produces a clearing partial update', (
    tester,
  ) async {
    const initial = BuildConfig(
      builderId: 'builder-1',
      imageName: 'ghcr.io/acme/api',
      commit: 'abc123',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildConfigEditorContent(initialConfig: initial),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Clear the commit field (un-pin the commit).
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == 'abc123',
      ),
      '',
    );
    await tester.pumpAndSettle();

    final state = tester.state<BuildConfigEditorContentState>(
      find.byType(BuildConfigEditorContent),
    );
    expect(state.buildPartialConfigParams(), {'commit': ''});
  });
}

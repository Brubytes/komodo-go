import 'package:flutter/material.dart';
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';

typedef StackTagOption = TagOption;

class StackTagFilterSheet {
  const StackTagFilterSheet._();

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<StackTagOption> availableTags,
    required Set<String> selected,
  }) {
    return TagFilterSheet.show(
      context,
      availableTags: availableTags,
      selected: selected,
      resourceName: 'stacks',
    );
  }
}

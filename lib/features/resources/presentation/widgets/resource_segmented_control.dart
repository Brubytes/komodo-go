import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../providers/resources_tab_provider.dart';

class ResourceSegmentedControl extends StatelessWidget {
  const ResourceSegmentedControl({
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isCupertino =
        !kIsWeb &&
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS);

    final theme = Theme.of(context);
    final items = ResourceType.values;

    final horizontalPadding = isCupertino ? 16.0 : 12.0;

    if (isCupertino) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: selectedIndex,
              onValueChanged: (value) {
                if (value == null) return;
                onChanged(value);
              },
              children: {
                for (var i = 0; i < items.length; i++)
                  i: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text(items[i].label),
                  ),
              },
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (var i = 0; i < items.length; i++)
                ButtonSegment<int>(
                  value: i,
                  icon: Icon(items[i].icon, size: 18),
                  label: Text(items[i].label),
                ),
            ],
            selected: {selectedIndex},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              onChanged(selection.first);
            },
            style: SegmentedButton.styleFrom(
              textStyle: theme.textTheme.labelMedium,
            ),
          ),
        ),
      ),
    );
  }
}


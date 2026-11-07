import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// First-load placeholder shaped like a `DetailResourceHeader` (a few fact
/// rows) followed by a detail action bar, so the layout barely moves when
/// the real header lands. Pass `showActions: false` for headers without
/// an action bar.
class DetailHeaderSkeleton extends StatelessWidget {
  const DetailHeaderSkeleton({
    super.key,
    this.facts = 3,
    this.showActions = true,
  });

  final int facts;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailSurface(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < facts; i++) ...[
                    if (i > 0) const Gap(AppSpacing.md),
                    const Row(
                      children: [
                        Bone.icon(),
                        Gap(AppSpacing.md),
                        Expanded(child: Bone.text(words: 3)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showActions) ...[
            const Gap(AppSpacing.md),
            const Row(
              children: [
                Expanded(child: Bone.button(height: 44)),
                Gap(AppSpacing.md),
                Bone.button(width: 44, height: 44),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// First-load placeholder for a detail tab: [count] stacked skeleton
/// surfaces, so the tab keeps a plausible height until data arrives.
class DetailTabSkeleton extends StatelessWidget {
  const DetailTabSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const Gap(AppSpacing.md),
          const AppSkeletonSurface(),
        ],
      ],
    );
  }
}

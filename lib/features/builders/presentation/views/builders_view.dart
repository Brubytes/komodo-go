import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/async/action_busy_overlay.dart';
import 'package:komodo_go/core/widgets/async/async_content.dart';
import 'package:komodo_go/core/widgets/async/refresh_helpers.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/builders/presentation/views/builders/builder_tile.dart';
import 'package:komodo_go/features/builders/presentation/views/builders/builders_view_states.dart';

class BuildersView extends ConsumerStatefulWidget {
  const BuildersView({super.key});

  @override
  ConsumerState<BuildersView> createState() => _BuildersViewState();
}

class _BuildersViewState extends ConsumerState<BuildersView> {
  late final _intro = AppListIntro();

  @override
  Widget build(BuildContext context) {
    final buildersAsync = ref.watch(buildersProvider);
    final actionsState = ref.watch(builderActionsProvider);

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Builders',
        icon: AppIcons.factory,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => refreshProviders(ref, [buildersProvider.future]),
            child: AsyncContent<List<BuilderListItem>>(
              value: buildersAsync,
              fill: true,
              showProgress: false,
              errorTitle: 'Failed to load builders',
              onRetry: () => ref.invalidate(buildersProvider),
              skeletonBuilder: (_) => const _BuildersSkeletonList(),
              builder: (context, items) {
                if (items.isEmpty) {
                  return const BuildersEmptyState();
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Gap(12),
                  itemBuilder: (context, index) => _intro.wrap(
                    index,
                    BuilderTile(item: items[index]),
                    id: items[index].id,
                  ),
                );
              },
            ),
          ),
          ActionBusyOverlay(busy: actionsState.isLoading),
        ],
      ),
    );
  }
}

class _BuildersSkeletonList extends StatelessWidget {
  const _BuildersSkeletonList();

  @override
  Widget build(BuildContext context) {
    return const ResourceCardSkeletonList(
      title: 'Builder name',
      subtitle: 'Server',
      metaLeft: 'Builder type',
      metaRight: 'Instance type',
    );
  }
}

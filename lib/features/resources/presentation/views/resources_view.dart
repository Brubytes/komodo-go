import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../builds/presentation/views/builds_list_view.dart';
import '../../../deployments/presentation/views/deployments_list_view.dart';
import '../../../procedures/presentation/views/procedures_list_view.dart';
import '../../../repos/presentation/views/repos_list_view.dart';
import '../../../servers/presentation/views/servers_list_view.dart';
import '../../../stacks/presentation/views/stacks_list_view.dart';
import '../providers/resources_tab_provider.dart';
import '../widgets/resource_segmented_control.dart';

class ResourcesView extends ConsumerStatefulWidget {
  const ResourcesView({super.key});

  @override
  ConsumerState<ResourcesView> createState() => _ResourcesViewState();
}

class _ResourcesViewState extends ConsumerState<ResourcesView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: ref.read(resourcesTabProvider));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(resourcesTabProvider);

    ref.listen<int>(resourcesTabProvider, (previous, next) {
      if (!_pageController.hasClients) return;
      final current = _pageController.page?.round() ?? _pageController.initialPage;
      if (current == next) return;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ResourceSegmentedControl(
              selectedIndex: selectedIndex,
              onChanged: (index) =>
                  ref.read(resourcesTabProvider.notifier).setIndex(index),
            ),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: ResourceType.values.length,
        onPageChanged: (index) =>
            ref.read(resourcesTabProvider.notifier).setIndex(index),
        itemBuilder: (context, index) {
          final child = switch (ResourceType.values[index]) {
            ResourceType.servers => const ServersListContent(),
            ResourceType.deployments => const DeploymentsListContent(),
            ResourceType.stacks => const StacksListContent(),
            ResourceType.repos => const ReposListContent(),
            ResourceType.builds => const BuildsListContent(),
            ResourceType.procedures => const ProceduresListContent(),
          };

          return _KeepAlivePage(child: child);
        },
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/resources/presentation/providers/resources_tab_provider.dart';

class ResourcesView extends ConsumerWidget {
  const ResourcesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ResourceType?>(resourcesTargetProvider, (previous, next) {
      if (next == null) return;
      ref.read(resourcesTargetProvider.notifier).clear();
      context.push(_routeFor(next));
    });

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Resources',
        icon: AppIcons.resources,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          for (final resource in ResourceType.values)
            ListTile(
              leading: Icon(resource.icon, color: resource.color),
              title: Text(resource.label),
              trailing: Icon(AppIcons.chevron),
              onTap: () => context.push(_routeFor(resource)),
            ),
        ],
      ),
    );
  }
}

String _routeFor(ResourceType resource) => switch (resource) {
  ResourceType.servers => AppRoutes.servers,
  ResourceType.deployments => AppRoutes.deployments,
  ResourceType.stacks => AppRoutes.stacks,
  ResourceType.repos => AppRoutes.repos,
  ResourceType.syncs => AppRoutes.syncs,
  ResourceType.builds => AppRoutes.builds,
  ResourceType.procedures => AppRoutes.procedures,
  ResourceType.actions => AppRoutes.actions,
};

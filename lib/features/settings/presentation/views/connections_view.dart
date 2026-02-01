import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/demo/demo_config.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/providers/demo_mode_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/app_floating_action_button.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:komodo_go/features/auth/presentation/widgets/edit_connection_sheet.dart';
import 'package:komodo_go/features/settings/presentation/widgets/add_connection_sheet.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ConnectionsView extends ConsumerWidget {
  const ConnectionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(connectionsProvider);
    final authAsync = ref.watch(authProvider);

    return Scaffold(
      appBar: MainAppBar(
        title: 'Connections',
        icon: AppIcons.network,
        centerTitle: true,
        onTitleLongPress: () => _showDemoEnableSheet(context, ref),
        actions: [
          IconButton(
            tooltip: 'Disconnect',
            icon: const Icon(AppIcons.disconnect),
            onPressed: authAsync.isLoading
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Disconnect'),
                        content: const Text(
                          'Disconnect from the current instance?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Disconnect'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed ?? false) {
                      await ref.read(authProvider.notifier).logout();
                    }
                  },
          ),
        ],
      ),
      floatingActionButton: AppSecondaryFab.extended(
        onPressed: authAsync.isLoading
            ? null
            : () => AddConnectionSheet.show(context),
        icon: const Icon(AppIcons.add),
        label: const Text('Add'),
      ),
      body: connectionsAsync.when(
        data: (connectionsState) {
          final connections = connectionsState.connections;
          final activeId = connectionsState.activeConnectionId;

          if (connections.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No saved connections yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final connection = connections[index];
              final isActive = connection.id == activeId;

              final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

              return AppFadeSlide(
                delay: AppMotion.stagger(index),
                play: index < 10,
                child: AppCardSurface(
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: cardRadius,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        isActive ? AppIcons.ok : AppIcons.server,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(connection.name),
                      subtitle: Text(connection.baseUrl),
                      onTap: authAsync.isLoading
                          ? null
                          : () async {
                              await ref
                                  .read(authProvider.notifier)
                                  .selectConnection(connection.id);
                            },
                      trailing: PopupMenuButton<_ConnectionAction>(
                        onSelected: (action) async {
                          switch (action) {
                            case _ConnectionAction.edit:
                              await EditConnectionSheet.show(
                                context,
                                connection: connection,
                              );
                            case _ConnectionAction.delete:
                              await _deleteConnection(
                                context,
                                ref,
                                connection,
                              );
                          }
                        },
                        itemBuilder: (context) {
                          final scheme = Theme.of(context).colorScheme;
                          return [
                            komodoPopupMenuItem(
                              value: _ConnectionAction.edit,
                              icon: AppIcons.edit,
                              label: 'Edit',
                              iconColor: scheme.primary,
                            ),
                            komodoPopupMenuItem(
                              value: _ConnectionAction.delete,
                              icon: AppIcons.delete,
                              label: 'Delete',
                              destructive: true,
                            ),
                          ];
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const Gap(8),
            itemCount: connections.length,
          );
        },
        loading: () => const _ConnectionsSkeletonList(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load connections: $error'),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteConnection(
    BuildContext context,
    WidgetRef ref,
    ConnectionProfile connection,
  ) async {
    final isDemo = connection.name == demoConnectionName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete connection'),
        content: Text(
          isDemo
              ? 'Remove "${connection.name}"? This disables demo mode and the demo instance will disappear. You can re-enable it by long-pressing the Connections header.'
              : 'Remove "${connection.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      if (connection.name == demoConnectionName) {
        await ref.read(demoModeProvider.notifier).setEnabled(false);
        return;
      }
      await ref
          .read(connectionsProvider.notifier)
          .deleteConnection(connection.id);
    }
  }

  Future<void> _showDemoEnableSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!demoAvailable) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Demo mode unavailable',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              Gap(8),
              Text('Demo mode is not available in this build.'),
              Gap(12),
            ],
          ),
        ),
      );
      return;
    }

    final shouldEnable = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enable demo mode?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const Gap(8),
            const Text(
              'Enabling demo mode adds a local demo instance to your connections. '
              'You can disable it again by deleting the demo connection from this list.',
            ),
            const Gap(16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Enable demo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (shouldEnable ?? false) {
      await ref.read(demoModeProvider.notifier).setEnabled(true);
    }
  }
}

enum _ConnectionAction { edit, delete }

class _ConnectionsSkeletonList extends StatelessWidget {
  const _ConnectionsSkeletonList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const Gap(8),
        itemBuilder: (_, __) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const CircleAvatar(radius: 16),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connection name', style: textTheme.titleSmall),
                      const Gap(6),
                      Text('Base URL • User', style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const Gap(8),
                const Chip(label: Text('Active')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

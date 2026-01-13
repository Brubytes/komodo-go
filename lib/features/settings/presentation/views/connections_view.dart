import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/app_floating_action_button.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:komodo_go/features/settings/presentation/widgets/add_connection_sheet.dart';

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

              return AppCardSurface(
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
                          case _ConnectionAction.rename:
                            await _renameConnection(context, ref, connection);
                          case _ConnectionAction.delete:
                            await _deleteConnection(context, ref, connection);
                        }
                      },
                      itemBuilder: (context) {
                        final scheme = Theme.of(context).colorScheme;
                        return [
                          komodoPopupMenuItem(
                            value: _ConnectionAction.rename,
                            icon: AppIcons.edit,
                            label: 'Rename',
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
              );
            },
            separatorBuilder: (_, __) => const Gap(8),
            itemCount: connections.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load connections: $error'),
          ),
        ),
      ),
    );
  }

  Future<void> _renameConnection(
    BuildContext context,
    WidgetRef ref,
    ConnectionProfile connection,
  ) async {
    final controller = TextEditingController(text: connection.name);

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename connection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (nextName == null || nextName.isEmpty) {
      return;
    }

    await ref
        .read(connectionsProvider.notifier)
        .renameConnection(connectionId: connection.id, name: nextName);
  }

  Future<void> _deleteConnection(
    BuildContext context,
    WidgetRef ref,
    ConnectionProfile connection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete connection'),
        content: Text('Remove "${connection.name}"?'),
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
      await ref
          .read(connectionsProvider.notifier)
          .deleteConnection(connection.id);
    }
  }
}

enum _ConnectionAction { rename, delete }

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/connections/connection_profile.dart';
import '../../../../core/providers/connections_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ConnectionsView extends ConsumerWidget {
  const ConnectionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(connectionsProvider);
    final authAsync = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            tooltip: 'Disconnect',
            icon: const Icon(Icons.link_off_outlined),
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

                    if (confirmed == true) {
                      await ref.read(authProvider.notifier).logout();
                    }
                  },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: authAsync.isLoading
            ? null
            : () => _showAddConnectionDialog(context, ref),
        icon: const Icon(Icons.add),
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

              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Icon(
                    isActive ? Icons.check_circle : Icons.dns_outlined,
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
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _ConnectionAction.rename,
                        child: Text('Rename'),
                      ),
                      PopupMenuItem(
                        value: _ConnectionAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
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
            onPressed: () => Navigator.of(context).pop(null),
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

    if (confirmed == true) {
      await ref
          .read(connectionsProvider.notifier)
          .deleteConnection(connection.id);
    }
  }

  Future<void> _showAddConnectionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final baseUrlController = TextEditingController();
    final apiKeyController = TextEditingController();
    final apiSecretController = TextEditingController();
    var obscureSecret = true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add connection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://komodo.example.com',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const Gap(12),
                TextField(
                  controller: apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  autocorrect: false,
                ),
                const Gap(12),
                TextField(
                  controller: apiSecretController,
                  decoration: InputDecoration(
                    labelText: 'API Secret',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureSecret
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => obscureSecret = !obscureSecret);
                      },
                    ),
                  ),
                  obscureText: obscureSecret,
                  autocorrect: false,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final baseUrl = baseUrlController.text.trim();
                final apiKey = apiKeyController.text.trim();
                final apiSecret = apiSecretController.text.trim();
                if (baseUrl.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
                  return;
                }

                await ref
                    .read(authProvider.notifier)
                    .login(
                      baseUrl: baseUrl,
                      apiKey: apiKey,
                      apiSecret: apiSecret,
                    );

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConnectionAction { rename, delete }

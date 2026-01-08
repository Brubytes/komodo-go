import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../../../core/router/app_router.dart';
import '../providers/servers_provider.dart';
import '../widgets/server_card.dart';

class ServersListContent extends ConsumerWidget {
  const ServersListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serversProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(serversProvider.notifier).refresh(),
      child: serversAsync.when(
        data: (servers) {
          if (servers.isEmpty) {
            return const _EmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: servers.length,
            separatorBuilder: (context, index) => const Gap(12),
            itemBuilder: (context, index) {
              final server = servers[index];
              return ServerCard(
                server: server,
                onTap: () => context.push(
                  '${AppRoutes.servers}/${server.id}?name=${Uri.encodeComponent(server.name)}',
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(serversProvider),
        ),
      ),
    );
  }
}

/// View displaying the list of all servers.
class ServersListView extends StatelessWidget {
  const ServersListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      body: const ServersListContent(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.server,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'No servers found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          Text(
            'Add servers in the Komodo web interface',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.formError,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const Gap(16),
            Text(
              'Failed to load servers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

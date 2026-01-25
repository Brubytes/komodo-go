import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/servers/presentation/widgets/server_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
              return AppFadeSlide(
                delay: AppMotion.stagger(index),
                play: index < 10,
                child: ServerCard(
                  server: server,
                  onTap: () => context.push(
                    '${AppRoutes.servers}/${server.id}?name=${Uri.encodeComponent(server.name)}',
                  ),
                ),
              );
            },
          );
        },
        loading: () => const _ServersSkeletonList(),
        error: (error, stack) => ErrorStateView(
          title: 'Failed to load servers',
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
    return const Scaffold(
      appBar: MainAppBar(
        title: 'Servers',
        icon: AppIcons.server,
        markColor: AppTokens.resourceServers,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: ServersListContent(),
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

class _ServersSkeletonList extends StatelessWidget {
  const _ServersSkeletonList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const Gap(12),
        itemBuilder: (_, __) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 16),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        'Server name',
                        style: textTheme.titleSmall,
                      ),
                    ),
                    const Gap(8),
                    const CircleAvatar(radius: 6),
                  ],
                ),
                const Gap(10),
                Text('Status • Region • Provider', style: textTheme.bodySmall),
                const Gap(10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: const [
                    Chip(label: Text('Online')),
                    Chip(label: Text('CPU 45%')),
                    Chip(label: Text('Mem 62%')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

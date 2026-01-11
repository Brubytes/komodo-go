import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/containers/presentation/providers/container_log_provider.dart';
import 'package:komodo_go/features/containers/presentation/providers/containers_provider.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card.dart';

class ContainerDetailView extends ConsumerWidget {
  const ContainerDetailView({
    required this.serverId,
    required this.containerIdOrName,
    required this.initialItem,
    super.key,
  });

  final String serverId;
  final String containerIdOrName;
  final ContainerOverviewItem? initialItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(
      _containerItemProviderFamily(
        _ContainerItemArgs(
          serverId: serverId,
          containerIdOrName: containerIdOrName,
          initialItem: initialItem,
        ),
      ),
    );
    final decodedContainerIdOrName = Uri.decodeComponent(containerIdOrName);
    final logAsync = ref.watch(
      containerLogProvider(
        serverIdOrName: serverId,
        containerIdOrName: decodedContainerIdOrName,
      ),
    );

    return Scaffold(
      appBar: const MainAppBar(title: 'Container', icon: AppIcons.containers),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(_containerItemProviderFamily)
            ..invalidate(
              containerLogProvider(
                serverIdOrName: serverId,
                containerIdOrName: decodedContainerIdOrName,
              ),
            );
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            itemAsync.when(
              data: (item) =>
                  item == null ? const _NotFound() : ContainerCard(item: item),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stack) => _ErrorState(
                title: 'Failed to load container',
                message: error.toString(),
                onRetry: () => ref.invalidate(_containerItemProviderFamily),
              ),
            ),
            const Gap(16),
            Text(
              'Log (tail)',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Gap(8),
            logAsync.when(
              data: (log) {
                if (log == null) {
                  return const _LogEmpty();
                }

                final lines = <String>[
                  if (log.stdout.trim().isNotEmpty) log.stdout.trim(),
                  if (log.stderr.trim().isNotEmpty) log.stderr.trim(),
                ];

                if (lines.isEmpty) {
                  return const _LogEmpty();
                }

                return _LogBox(content: lines.join('\n\n'));
              },
              loading: () =>
                  const _LogBox(content: 'Loading…', isLoading: true),
              error: (error, stack) => _ErrorState(
                title: 'Failed to load log',
                message: error.toString(),
                onRetry: () => ref.invalidate(
                  containerLogProvider(
                    serverIdOrName: serverId,
                    containerIdOrName: decodedContainerIdOrName,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _containerItemProviderFamily = FutureProvider.family
    .autoDispose<ContainerOverviewItem?, _ContainerItemArgs>((ref, args) async {
      if (args.initialItem != null) return args.initialItem;

      final result = await ref.watch(containersProvider.future);

      final normalized = Uri.decodeComponent(args.containerIdOrName);
      for (final item in result.items) {
        if (item.serverId != args.serverId) continue;
        final id = item.container.id;
        if (id != null && id == normalized) return item;
        if (item.container.name == normalized) return item;
      }

      return null;
    });

@immutable
class _ContainerItemArgs {
  const _ContainerItemArgs({
    required this.serverId,
    required this.containerIdOrName,
    required this.initialItem,
  });

  final String serverId;
  final String containerIdOrName;
  final ContainerOverviewItem? initialItem;

  @override
  bool operator ==(Object other) {
    return other is _ContainerItemArgs &&
        other.serverId == serverId &&
        other.containerIdOrName == containerIdOrName &&
        other.initialItem == initialItem;
  }

  @override
  int get hashCode => Object.hash(serverId, containerIdOrName, initialItem);
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Container not found.'),
      ),
    );
  }
}

class _LogEmpty extends StatelessWidget {
  const _LogEmpty();

  @override
  Widget build(BuildContext context) {
    return const _LogBox(content: 'No log output.');
  }
}

class _LogBox extends StatelessWidget {
  const _LogBox({required this.content, this.isLoading = false});

  final String content;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: double.infinity,
      child: AppCardSurface(
        padding: const EdgeInsets.all(12),
        radius: 12,
        enableShadow: false,
        child: isLoading
            ? Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const Gap(10),
                  Text(content, style: textTheme.bodySmall),
                ],
              )
            : SelectableText(
                content,
                style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Gap(8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

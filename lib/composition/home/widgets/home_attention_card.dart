import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/home/home_attention_provider.dart';
import 'package:komodo_go/composition/home/widgets/home_sections.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/notifications/presentation/providers/target_display_name_provider.dart';

/// Maximum rows shown before collapsing behind "Show all".
const homeAttentionVisibleRows = 6;

/// Top-of-dashboard card listing everything that needs the user's attention.
class HomeAttentionCard extends ConsumerStatefulWidget {
  const HomeAttentionCard({super.key});

  @override
  ConsumerState<HomeAttentionCard> createState() => _HomeAttentionCardState();
}

class _HomeAttentionCardState extends ConsumerState<HomeAttentionCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final attention = ref.watch(homeAttentionProvider);

    return attention.when(
      loading: () => const HomeLoadingTile(),
      error: (e, _) => HomeErrorTile(message: e.toString()),
      data: (snapshot) {
        if (snapshot.isClear) return const _AllClearRow();

        final scheme = Theme.of(context).colorScheme;
        final items = snapshot.items;
        final visible = _expanded
            ? items
            : items.take(homeAttentionVisibleRows).toList();
        final hidden = items.length - visible.length;

        return AppCardSurface(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Icon(AppIcons.warning, size: 20, color: scheme.error),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        'Needs attention',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${snapshot.total}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: scheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final item in visible) _AttentionRow(item: item),
              if (hidden > 0 || _expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'Show less' : 'Show all ${items.length}',
                    ),
                  ),
                )
              else
                const Gap(6),
            ],
          ),
        );
      },
    );
  }
}

class _AllClearRow extends StatelessWidget {
  const _AllClearRow();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(AppIcons.ok, size: 22, color: AppTokens.statusGreen),
            const Gap(10),
            Text(
              'All clear',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(8),
            Expanded(
              child: Text(
                'Nothing needs attention',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionRow extends ConsumerWidget {
  const _AttentionRow({required this.item});

  final HomeAttentionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = item.isCritical ? scheme.error : AppTokens.statusOrange;
    final route = item.route;

    var title = item.title;
    final target = item.updateTarget;
    if (target != null) {
      final name = ref
          .watch(targetDisplayNameProvider(target))
          .maybeWhen(data: (v) => v, orElse: () => target.displayName);
      title = '${item.title} · $name';
    }

    return InkWell(
      key: ValueKey('home_attention_${item.kind.name}_${item.title}'),
      onTap: route == null ? null : () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Icon(_iconFor(item.kind), size: 20, color: color),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
            if (route != null)
              Icon(
                AppIcons.chevron,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(HomeAttentionKind kind) => switch (kind) {
  HomeAttentionKind.server => AppIcons.server,
  HomeAttentionKind.stack => AppIcons.stacks,
  HomeAttentionKind.deployment => AppIcons.deployments,
  HomeAttentionKind.build => AppIcons.builds,
  HomeAttentionKind.repo => AppIcons.repos,
  HomeAttentionKind.procedure => AppIcons.procedures,
  HomeAttentionKind.action => AppIcons.actions,
  HomeAttentionKind.sync => AppIcons.syncs,
  HomeAttentionKind.alert => AppIcons.error,
  HomeAttentionKind.failedUpdate => AppIcons.updateAvailable,
};

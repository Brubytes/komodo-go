import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

/// Status shown on a [ResourceCard] as a pill and (when attention-worthy) as a
/// left accent bar.
class ResourceStatusSpec {
  const ResourceStatusSpec({
    required this.label,
    required this.icon,
    this.tone = PillTone.neutral,
    this.accent,
  });

  final String label;
  final IconData icon;
  final PillTone tone;

  /// Force the accent bar on/off. By default only [PillTone.alert] and
  /// [PillTone.warning] show it, so healthy lists stay calm.
  final bool? accent;

  bool get showsAccent =>
      accent ?? (tone == PillTone.alert || tone == PillTone.warning);

  Color accentColor(ColorScheme scheme) => switch (tone) {
    PillTone.alert => scheme.error,
    PillTone.warning => pillToneForeground(scheme, PillTone.warning),
    PillTone.success => pillToneForeground(scheme, PillTone.success),
    PillTone.neutral => scheme.outline,
  };
}

/// Small icon + label used in card meta rows.
class ResourceIconLabel extends StatelessWidget {
  const ResourceIconLabel({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared list card for resources (stacks, deployments, builds, repos, ...).
///
/// Layout: title + status pill + menu on the first row, a single-line
/// subtitle, up to two meta items, optional pills and an optional bottom slot.
class ResourceCard extends StatelessWidget {
  const ResourceCard({
    required this.title,
    super.key,
    this.subtitle,
    this.status,
    this.meta = const [],
    this.pills = const [],
    this.bottom,
    this.menu = const [],
    this.menuBuilder,
    this.onTap,
    this.menuKey,
  });

  final String title;
  final String? subtitle;
  final ResourceStatusSpec? status;

  /// Max two icon+label items.
  final List<ResourceIconLabel> meta;
  final List<Widget> pills;
  final Widget? bottom;

  /// Grouped actions for the trailing menu and the long-press menu.
  final List<DetailActionGroup> menu;

  /// Lazy alternative to [menu]: evaluated only when the menu is opened, so
  /// list rebuilds don't construct menu items for every card. When set, the
  /// card always shows the menu button.
  final List<DetailActionGroup> Function()? menuBuilder;
  final VoidCallback? onTap;
  final Key? menuKey;

  static const double _accentWidth = 4;

  bool get _hasMenu =>
      menuBuilder != null || menu.any((g) => g.items.isNotEmpty);

  List<DetailActionGroup> _resolveMenu() => menuBuilder?.call() ?? menu;

  @override
  Widget build(BuildContext context) {
    assert(meta.length <= 2, 'ResourceCard supports at most 2 meta items');
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppTokens.radiusLg);
    final status = this.status;
    final subtitle = this.subtitle;
    final showAccent = status?.showsAccent ?? false;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        _hasMenu ? AppSpacing.xs : AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: AppSpacing.sm),
                StatusPill(
                  label: status.label,
                  icon: status.icon,
                  tone: status.tone,
                ),
              ],
              if (_hasMenu)
                DetailActionMenuButton(
                  key: menuKey,
                  groups: menu,
                  groupsBuilder: menuBuilder,
                  tooltip: 'Actions',
                )
              else
                const SizedBox(height: 48),
            ],
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xxs,
                right: AppSpacing.md,
              ),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                right: AppSpacing.md,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < meta.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    Flexible(child: meta[i]),
                  ],
                ],
              ),
            ),
          if (pills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                right: AppSpacing.md,
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: pills,
              ),
            ),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                right: AppSpacing.md,
              ),
              child: bottom,
            ),
        ],
      ),
    );

    return RepaintBoundary(
      child: AppPressable(
        enabled: onTap != null,
        child: AppCardSurface(
          padding: EdgeInsets.zero,
          child: GestureDetector(
            onLongPressStart: _hasMenu
                ? (details) {
                    unawaited(HapticFeedback.selectionClick());
                    unawaited(
                      showDetailActionMenu(
                        context,
                        groups: _resolveMenu(),
                        position: details.globalPosition,
                      ),
                    );
                  }
                : null,
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Stack(
                  children: [
                    SizedBox(width: double.infinity, child: content),
                    if (showAccent && status != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: _accentWidth,
                        // Clipped by the card's rounded Material shape.
                        child: ColoredBox(
                          key: const ValueKey('resource_card_accent'),
                          color: status.accentColor(scheme),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

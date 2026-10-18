import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

class DetailSubCard extends StatefulWidget {
  const DetailSubCard({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
    this.tintColor,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.summary,
    this.modified = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? tintColor;

  /// When true the header toggles the body with an animation.
  final bool collapsible;

  /// Initial expanded state (only when [collapsible]). If the card has a key,
  /// the expanded state is kept in [PageStorage] so it survives being
  /// scrolled offscreen.
  final bool initiallyExpanded;

  /// One muted line shown in the collapsed header. A [String] or [Widget].
  final Object? summary;

  /// Shows a small primary-colored dot next to the title.
  final bool modified;

  @override
  State<DetailSubCard> createState() => _DetailSubCardState();
}

class _DetailSubCardState extends State<DetailSubCard> {
  late bool _expanded;
  var _restored = false;

  PageStorageKey<String>? get _storageKey => widget.key == null
      ? null
      : PageStorageKey<String>('detail_sub_card_${widget.key}');

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = _storageKey;
    if (!_restored && key != null && widget.collapsible) {
      _restored = true;
      final stored = PageStorage.maybeOf(
        context,
      )?.readState(context, identifier: key);
      if (stored is bool) _expanded = stored;
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    final key = _storageKey;
    if (key != null) {
      PageStorage.maybeOf(
        context,
      )?.writeState(context, _expanded, identifier: key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tint = widget.tintColor ?? scheme.primary;
    final collapsible = widget.collapsible;
    final expanded = !collapsible || _expanded;

    final summary = widget.summary;
    final Widget? summaryWidget;
    if (summary is Widget) {
      summaryWidget = summary;
    } else if (summary is String && summary.isNotEmpty) {
      summaryWidget = Text(
        summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    } else {
      summaryWidget = null;
    }

    final header = Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(widget.icon, size: 18, color: tint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.title,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (widget.modified) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      key: const ValueKey('detail_sub_card_modified_dot'),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              if (collapsible && !expanded && summaryWidget != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: summaryWidget,
                ),
            ],
          ),
        ),
        if (collapsible)
          AppChevron(
            expanded: expanded,
            icon: AppIcons.chevronDown,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
      ],
    );

    return AppCardSurface(
      radius: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (collapsible)
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(12),
              child: header,
            )
          else
            header,
          AppExpand(
            // Keep the body mounted while collapsed so editor state survives.
            child: Visibility(
              visible: expanded,
              maintainState: true,
              replacement: const SizedBox(width: double.infinity),
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Keeps a newest-first list stable while the user is scrolled down.
///
/// Items that arrive above the item the user is reading are held back (not
/// rendered) until the user is at or near the top again, so nothing already on
/// screen moves. Held items are counted in [pending] for a [NewItemsPill].
/// Updates to items that are already shown (status changes, older pages) flow
/// through untouched.
///
/// Call [apply] from `build` with the current scroll offset; it is idempotent
/// for equal inputs.
class NewItemsHold {
  NewItemsHold({this.nearTop = 24});

  /// Scroll offset up to which new items are shown immediately.
  final double nearTop;

  Object? _anchor;

  /// Number of items held back by the last [apply].
  int pending = 0;

  /// Returns the items to render: [items] minus those held above the anchor.
  List<T> apply<T>(
    List<T> items,
    Object Function(T item) idOf,
    double pixels,
  ) {
    if (items.isEmpty) {
      _anchor = null;
      pending = 0;
      return items;
    }
    final anchor = _anchor;
    var index = -1;
    if (anchor != null) {
      index = items.indexWhere((item) => idOf(item) == anchor);
    }
    if (index <= 0 || pixels <= nearTop) {
      _anchor = idOf(items.first);
      pending = 0;
      return items;
    }
    pending = index;
    return items.sublist(index);
  }
}

/// Small pill floating over a list that announces held-back items.
class NewItemsPill extends StatelessWidget {
  const NewItemsPill({
    required this.count,
    required this.noun,
    required this.onPressed,
    this.topInset = 0,
    super.key,
  });

  /// Space reserved above the pill (e.g. a pinned app bar overlapping the list).
  final double topInset;

  /// Held-back items; the pill is hidden for zero.
  final int count;

  /// Singular noun, e.g. `update` (a plural `s` is added).
  final String noun;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: topInset + AppSpacing.sm,
      left: 0,
      right: 0,
      child: Center(
        child: AppSwitcher(
          animateSize: false,
          child: count == 0
              ? const SizedBox.shrink()
              : Material(
                  key: const ValueKey('new_items_pill'),
                  color: scheme.primary,
                  elevation: 3,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            size: 16,
                            color: scheme.onPrimary,
                          ),
                          const Gap(AppSpacing.xs),
                          Text(
                            count == 1 ? '1 new $noun' : '$count new ${noun}s',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: scheme.onPrimary),
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

/// Wires a [NewItemsHold] to the vertical scrollable of a [State].
///
/// Feed scroll notifications to [trackScroll] (return value is always false so
/// it can sit inside an existing handler), render lists through [hold], and
/// call [showHeldItems] from the [NewItemsPill].
mixin NewItemsHoldState<T extends StatefulWidget> on State<T> {
  final hold = NewItemsHold();

  /// Offset of the vertical scrollable as of the last notification.
  double scrollPixels = 0;
  ScrollPosition? _position;

  bool trackScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final context = notification.context;
    if (context != null) _position = Scrollable.maybeOf(context)?.position;
    scrollPixels = notification.metrics.pixels;
    if (hold.pending > 0 && scrollPixels <= hold.nearTop && mounted) {
      // Back at the top: release the held items.
      setState(() {});
    }
    return false;
  }

  /// Scrolls to the top; the held items appear once it arrives.
  Future<void> showHeldItems() async {
    final position = _position;
    if (position == null || !position.hasPixels) return;
    await position.animateTo(
      0,
      duration: AppMotion.slow,
      curve: AppMotion.emphasized,
    );
    if (mounted) setState(() => scrollPixels = 0);
  }
}

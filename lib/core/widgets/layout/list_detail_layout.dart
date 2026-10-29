import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';

/// Local width from which [ListDetailLayout] shows list and detail side by
/// side.
const double kListDetailSplitMinWidth = 720;

/// Tells descendants of a [ListDetailLayout] how they are presented.
class ListDetailScope extends InheritedWidget {
  const ListDetailScope({
    required this.split,
    required this.isDetailPane,
    required this.hasDetail,
    required this.selectedId,
    required super.child,
    super.key,
  });

  /// List and detail are shown side by side.
  final bool split;

  /// The subtree is the detail pane (as opposed to the list pane).
  final bool isDetailPane;

  /// A detail is currently open next to the list.
  final bool hasDetail;

  /// Id of the item shown in the detail pane, if any.
  final String? selectedId;

  static ListDetailScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListDetailScope>();

  /// True when [context] is the detail pane of a side-by-side layout, where
  /// the back arrow becomes a close button.
  static bool isSplitDetailPane(BuildContext context) {
    final scope = maybeOf(context);
    return scope != null && scope.split && scope.isDetailPane;
  }

  @override
  bool updateShouldNotify(ListDetailScope oldWidget) =>
      split != oldWidget.split ||
      isDetailPane != oldWidget.isDetailPane ||
      hasDetail != oldWidget.hasDetail ||
      selectedId != oldWidget.selectedId;
}

extension ListDetailNavigation on BuildContext {
  /// Opens [location] as the detail of the surrounding list.
  ///
  /// In a side-by-side layout that already shows a detail the new detail
  /// replaces it (back stays one step from the list); otherwise it is pushed.
  void openDetail(String location, {Object? extra}) {
    final scope = ListDetailScope.maybeOf(this);
    final shouldReplace =
        scope != null && scope.split && scope.hasDetail && !scope.isDetailPane;
    if (shouldReplace) {
      replace(location, extra: extra);
    } else {
      unawaited(push<Object?>(location, extra: extra));
    }
  }
}

/// Master/detail layout for wide windows.
///
/// At [kListDetailSplitMinWidth] and wider (measured on the local
/// constraints, so it adapts to rails and Split View) the [list] and the
/// [detail] (or [placeholder]) sit side by side. Narrower, only the [detail]
/// is shown when there is one, otherwise the [list].
///
/// The detail subtree is held under a [GlobalKey] so it is reparented, not
/// rebuilt, when the window flips between the two modes (fold/unfold).
class ListDetailLayout extends StatefulWidget {
  const ListDetailLayout({
    required this.list,
    this.detail,
    this.placeholder = const ListDetailPlaceholder(),
    this.selectedId,
    this.splitMinWidth = kListDetailSplitMinWidth,
    this.splitEnabled = true,
    this.listWidthFraction = 0.4,
    this.minListWidth = 320,
    this.maxListWidth = 420,
    this.singlePaneMaxWidth,
    super.key,
  });

  final Widget list;
  final Widget? detail;
  final Widget placeholder;

  /// Id of the item the [detail] shows, exposed through [ListDetailScope].
  final String? selectedId;

  /// Local width from which list and detail sit side by side.
  final double splitMinWidth;

  /// Lets a screen opt out of splitting (e.g. while a tab without a detail is
  /// active) without losing the list's state.
  final bool splitEnabled;

  /// List pane width is `width * listWidthFraction` clamped to
  /// [minListWidth]..[maxListWidth].
  final double listWidthFraction;
  final double minListWidth;
  final double maxListWidth;

  /// Caps and centers the list when it is shown alone on a wide window.
  final double? singlePaneMaxWidth;

  @override
  State<ListDetailLayout> createState() => _ListDetailLayoutState();
}

class _ListDetailLayoutState extends State<ListDetailLayout> {
  final GlobalKey _detailKey = GlobalKey(debugLabel: 'listDetailDetail');
  final GlobalKey _listKey = GlobalKey(debugLabel: 'listDetailList');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split =
            widget.splitEnabled && constraints.maxWidth >= widget.splitMinWidth;
        final hasDetail = widget.detail != null;
        final scheme = Theme.of(context).colorScheme;

        Widget scoped({
          required bool isDetailPane,
          required Widget child,
        }) => ListDetailScope(
          split: split,
          isDetailPane: isDetailPane,
          hasDetail: hasDetail,
          selectedId: widget.selectedId,
          child: child,
        );

        final detail = widget.detail == null
            ? null
            : KeyedSubtree(
                key: _detailKey,
                child: scoped(isDetailPane: true, child: widget.detail!),
              );

        // Keyed so the list keeps its state when the layout flips.
        final list = KeyedSubtree(
          key: _listKey,
          child: scoped(isDetailPane: false, child: widget.list),
        );

        if (!split) {
          if (detail != null) return detail;
          final cap = widget.singlePaneMaxWidth;
          if (cap == null) return list;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cap),
              child: list,
            ),
          );
        }

        final listWidth = (constraints.maxWidth * widget.listWidthFraction)
            .clamp(widget.minListWidth, widget.maxListWidth);
        return Row(
          children: [
            SizedBox(
              width: listWidth,
              child: list,
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant,
            ),
            Expanded(
              child:
                  detail ??
                  scoped(isDetailPane: true, child: widget.placeholder),
            ),
          ],
        );
      },
    );
  }
}

/// Calm empty state for the detail pane while nothing is selected.
class ListDetailPlaceholder extends StatelessWidget {
  const ListDetailPlaceholder({
    this.icon = Icons.touch_app_outlined,
    this.label = 'Select an item',
    super.key,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: EmptyStateView(icon: icon, title: label),
    );
  }
}

/// Subtle primary-tinted outline marking the selected row of a list that
/// feeds a side-by-side detail pane.
class SelectionHighlight extends StatelessWidget {
  const SelectionHighlight({
    required this.selected,
    required this.child,
    super.key,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected) return child;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppTokens.radiusLg);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: radius,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

/// Remembers list scroll offsets by id, so the list instance that appears in
/// a detail page continues where the one in the list page left off.
abstract final class ListScrollMemory {
  static final Map<String, double> _offsets = {};

  static double offsetOf(String id) => _offsets[id] ?? 0;

  static void clear() => _offsets.clear();

  /// A controller that starts at the remembered offset for [id] and records
  /// every scroll.
  static ScrollController controllerFor(String id) =>
      _RememberedScrollController(id);
}

class _RememberedScrollController extends ScrollController {
  _RememberedScrollController(this.id)
    : super(initialScrollOffset: ListScrollMemory.offsetOf(id)) {
    addListener(() {
      if (hasClients) ListScrollMemory._offsets[id] = offset;
    });
  }

  final String id;
}

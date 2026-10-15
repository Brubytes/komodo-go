import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/widgets/detail/detail_tab_bar.dart';

/// Describes one tab of a [DetailTabScaffold]. Tabs are addressed by [id].
class DetailTabSpec {
  const DetailTabSpec({
    required this.id,
    required this.label,
    required this.body,
    this.icon,
    this.keepAlive = true,
  });

  /// Stable identifier (e.g. `'logs'`) used to jump to the tab.
  final String id;
  final String label;
  final IconData? icon;
  final Widget body;

  /// Keep the tab body mounted while another tab is selected.
  final bool keepAlive;
}

/// Pinned tab bar header used inside a `NestedScrollView`.
class PinnedTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  PinnedTabBarHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final PreferredSizeWidget tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Align(alignment: Alignment.centerLeft, child: tabBar),
    );
  }

  @override
  bool shouldRebuild(PinnedTabBarHeaderDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar ||
      backgroundColor != oldDelegate.backgroundColor;
}

/// Reusable detail layout: header slivers, a pinned tab bar and tab bodies in
/// a `NestedScrollView`. Tab bodies should use `DetailTabScrollView`.
///
/// Use a `GlobalKey<DetailTabScaffoldState>` to call
/// [DetailTabScaffoldState.selectTab] with a tab id.
class DetailTabScaffold extends StatefulWidget {
  const DetailTabScaffold({
    required this.headerSlivers,
    required this.tabs,
    super.key,
    this.initialTabId,
    this.onTabChanged,
    this.backgroundColor,
  }) : assert(tabs.length > 0, 'At least one tab is required');

  /// Slivers placed above the pinned tab bar (hero panel, action bar, ...).
  final List<Widget> headerSlivers;
  final List<DetailTabSpec> tabs;
  final String? initialTabId;
  final ValueChanged<String>? onTabChanged;
  final Color? backgroundColor;

  @override
  State<DetailTabScaffold> createState() => DetailTabScaffoldState();
}

class DetailTabScaffoldState extends State<DetailTabScaffold>
    with SingleTickerProviderStateMixin {
  final _nestedScrollKey = GlobalKey<NestedScrollViewState>();
  final _outerScrollController = ScrollController();
  late TabController _controller;

  /// Id of the currently selected tab.
  String get currentTabId => widget.tabs[_controller.index].id;

  int _indexOf(String? id) {
    if (id == null) return 0;
    final index = widget.tabs.indexWhere((t) => t.id == id);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _controller = _createController(_indexOf(widget.initialTabId));
  }

  TabController _createController(int index) {
    return TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: index,
    )..addListener(_handleChange);
  }

  void _handleChange() {
    if (_controller.indexIsChanging) return;
    widget.onTabChanged?.call(currentTabId);
  }

  /// Selects the tab with [id] (no-op for unknown ids).
  void selectTab(String id, {bool animate = true}) {
    final index = widget.tabs.indexWhere((t) => t.id == id);
    if (index < 0) return;
    if (animate) {
      _controller.animateTo(index);
    } else {
      _controller.index = index;
    }
  }

  @override
  void didUpdateWidget(DetailTabScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.tabs.map((t) => t.id).toList();
    final newIds = widget.tabs.map((t) => t.id).toList();
    if (oldIds.length != newIds.length || !_listEquals(oldIds, newIds)) {
      final keepId = oldIds.isEmpty ? null : oldIds[_controller.index];
      _controller
        ..removeListener(_handleChange)
        ..dispose();
      _controller = _createController(_indexOf(keepId));
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChange)
      ..dispose();
    _outerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background =
        widget.backgroundColor ?? Theme.of(context).colorScheme.surface;

    return NestedScrollView(
      key: _nestedScrollKey,
      controller: _outerScrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          ...widget.headerSlivers,
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: PinnedTabBarHeaderDelegate(
                backgroundColor: background,
                tabBar: buildDetailTabBar(
                  context: context,
                  controller: _controller,
                  outerScrollController: _outerScrollController,
                  nestedScrollKey: _nestedScrollKey,
                  tabs: [
                    for (final tab in widget.tabs)
                      Tab(
                        key: ValueKey('detail_tab_${tab.id}'),
                        icon: tab.icon == null ? null : Icon(tab.icon),
                        text: tab.label,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _controller,
        children: [
          for (final tab in widget.tabs)
            _TabBody(key: ValueKey('detail_tab_body_${tab.id}'), spec: tab),
        ],
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin<_KeepAlive> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.spec, super.key});

  final DetailTabSpec spec;

  @override
  Widget build(BuildContext context) {
    return spec.keepAlive ? _KeepAlive(child: spec.body) : spec.body;
  }
}

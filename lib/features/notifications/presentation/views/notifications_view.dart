import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/segmented/app_segmented_control.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/notifications_tab_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications/notifications_sections.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({
    this.selectedUpdateId,
    this.selectedAlertId,
    super.key,
  });

  /// Update open in the detail pane; also opens the Updates tab initially.
  final String? selectedUpdateId;

  /// Alert open in the detail pane; opens the Alerts tab initially.
  final String? selectedAlertId;

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _didAutoSwitchOnAlertsError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.selectedUpdateId != null
          ? 1
          : widget.selectedAlertId != null
          ? 0
          : ref.read(notificationsTabIndexProvider),
      vsync: this,
      animationDuration: AppMotion.slow,
    )..addListener(_publishTab);
    // Opening a detail implies its tab.
    final detailTab = widget.selectedUpdateId != null
        ? 1
        : widget.selectedAlertId != null
        ? 0
        : null;
    if (detailTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(notificationsTabIndexProvider.notifier).index = detailTab;
        }
      });
    }
  }

  void _publishTab() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    if (ref.read(notificationsTabIndexProvider) != index) {
      ref.read(notificationsTabIndexProvider.notifier).index = index;
    }
    // A detail belongs to its tab: switching tabs closes it, so the
    // placeholder shows instead of a stale detail from the other tab.
    final staleDetail =
        (index == 0 && widget.selectedUpdateId != null) ||
        (index == 1 && widget.selectedAlertId != null);
    if (staleDetail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.notifications);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToUpdates() {
    _tabController.animateTo(
      1,
      duration: AppMotion.durationOf(context, AppMotion.slow),
      curve: AppMotion.emphasized,
    );
  }

  void _switchToUpdatesIfNeeded() {
    if (_didAutoSwitchOnAlertsError || _tabController.index != 0 || !mounted) {
      return;
    }
    _didAutoSwitchOnAlertsError = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabController.index != 0) return;
      _goToUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);

    // Keep this instance on the tab chosen in the other list instance (the
    // one in the list page / detail page).
    ref.listen<int>(notificationsTabIndexProvider, (_, next) {
      if (_tabController.index != next) _tabController.index = next;
    });

    ref.listen<AsyncValue<AlertsState>>(alertsProvider, (_, next) {
      if (next.hasValue) {
        _didAutoSwitchOnAlertsError = false;
        return;
      }
      if (next.hasError) {
        _switchToUpdatesIfNeeded();
      }
    });

    final alertsUnavailable = alertsAsync.hasError;
    final unresolvedAlerts = alertsAsync.asData?.value.items
        .where((a) => !a.resolved)
        .length;
    final failedUpdates = ref
        .watch(updatesProvider)
        .asData
        ?.value
        .items
        .where((u) => u.status == UpdateStatus.failed)
        .length;

    return Scaffold(
      appBar: MainAppBar(
        tabRoot: true,
        title: 'Notifications',
        icon: AppIcons.notifications,
        showBottomBorder: false,
        bottom: AppSegmentedTabBar(
          controller: _tabController,
          segments: [
            AppSegment(
              label: 'Alerts',
              icon: alertsUnavailable ? AppIcons.warning : null,
              badgeCount: unresolvedAlerts,
              badgeTone: PillTone.warning,
            ),
            AppSegment(
              label: 'Updates',
              badgeCount: failedUpdates,
              badgeTone: PillTone.warning,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AlertsTab(
            onOpenUpdates: _goToUpdates,
            selectedAlertId: widget.selectedAlertId,
          ),
          UpdatesTab(selectedUpdateId: widget.selectedUpdateId),
        ],
      ),
    );
  }
}

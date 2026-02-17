import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications/notifications_sections.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchToUpdatesIfNeeded() {
    if (_didAutoSwitchOnAlertsError || _tabController.index != 0 || !mounted) {
      return;
    }
    _didAutoSwitchOnAlertsError = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabController.index != 0) return;
      _tabController.animateTo(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);

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

    return Scaffold(
      appBar: MainAppBar(
        title: 'Notifications',
        icon: AppIcons.notifications,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Alerts'),
                  if (alertsUnavailable) ...[
                    const SizedBox(width: 6),
                    const Icon(AppIcons.warning, size: 14),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Updates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AlertsTab(onOpenUpdates: () => _tabController.animateTo(1)),
          const UpdatesTab(),
        ],
      ),
    );
  }
}

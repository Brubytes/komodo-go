import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications/notifications_sections.dart';

class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: MainAppBar(
          title: 'Notifications',
          icon: AppIcons.notifications,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Alerts'),
              Tab(text: 'Updates'),
            ],
          ),
        ),
        body: TabBarView(children: [AlertsTab(), UpdatesTab()]),
      ),
    );
  }
}

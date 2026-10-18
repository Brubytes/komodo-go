import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/shared/logs/server_log_controller.dart';
import 'package:komodo_go/shared/logs/widgets/server_log_toolbar.dart';
import 'package:komodo_go/shared/logs/widgets/server_log_viewer.dart';

/// Full-screen log reader sharing the inline explorer's controller, so
/// search, filters and refresh state carry over in both directions.
class ServerLogFullscreenPage extends StatelessWidget {
  const ServerLogFullscreenPage({
    required this.controller,
    required this.title,
    this.onAutoRefreshChanged,
    super.key,
  });

  final ServerLogController controller;
  final String title;
  final ValueChanged<bool>? onAutoRefreshChanged;

  static Future<void> open(
    BuildContext context, {
    required ServerLogController controller,
    required String title,
    ValueChanged<bool>? onAutoRefreshChanged,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ServerLogFullscreenPage(
          controller: controller,
          title: title,
          onAutoRefreshChanged: onAutoRefreshChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(AppIcons.close),
        ),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => IconButton(
              tooltip: 'Refresh logs',
              onPressed: controller.loading ? null : controller.load,
              icon: const Icon(AppIcons.refresh, size: 20),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ServerLogToolbar(
                controller: controller,
                onAutoRefreshChanged: onAutoRefreshChanged,
              ),
              const Gap(10),
              Expanded(child: ServerLogViewer(controller: controller)),
            ],
          ),
        ),
      ),
    );
  }
}

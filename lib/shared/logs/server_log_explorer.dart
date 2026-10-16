import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/network/network_status.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/shared/logs/server_log_controller.dart';
import 'package:komodo_go/shared/logs/server_log_fullscreen_page.dart';
import 'package:komodo_go/shared/logs/widgets/server_log_toolbar.dart';
import 'package:komodo_go/shared/logs/widgets/server_log_viewer.dart';

export 'package:komodo_go/shared/logs/server_log_controller.dart'
    show ServerLogLoader;

/// Inline log explorer: compact search/filter header, the log output and a
/// full-screen mode that shares the same state.
class ServerLogExplorer extends ConsumerStatefulWidget {
  const ServerLogExplorer({
    required this.loader,
    this.title = 'Server logs',
    this.autoRefresh = true,
    this.onAutoRefreshChanged,
    this.fillHeight = false,
    super.key,
  });

  final ServerLogLoader loader;
  final String title;
  final bool autoRefresh;

  /// Called when the user toggles live refresh, so parents can keep related
  /// polling (e.g. operation logs) in step.
  final ValueChanged<bool>? onAutoRefreshChanged;

  /// Fill the available height (e.g. a dedicated Logs tab) instead of a
  /// fixed-height card. Requires bounded height constraints.
  final bool fillHeight;

  @override
  ConsumerState<ServerLogExplorer> createState() => _ServerLogExplorerState();
}

class _ServerLogExplorerState extends ConsumerState<ServerLogExplorer> {
  late final _controller = ServerLogController(
    loader: widget.loader,
    autoRefresh: widget.autoRefresh,
    networkStatus: () => ref.read(networkStatusProvider),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
  }

  @override
  void didUpdateWidget(covariant ServerLogExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.loader = widget.loader;
    if (oldWidget.autoRefresh != widget.autoRefresh) {
      _controller.setAutoRefresh(value: widget.autoRefresh);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _refreshButton() => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => IconButton(
      key: const ValueKey('server_log_refresh'),
      tooltip: 'Refresh logs',
      onPressed: _controller.loading ? null : _controller.load,
      icon: const Icon(AppIcons.refresh, size: 20),
    ),
  );

  void _expand() => ServerLogFullscreenPage.open(
    context,
    controller: _controller,
    title: widget.title,
    onAutoRefreshChanged: widget.onAutoRefreshChanged,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.fillHeight) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ServerLogToolbar(
              controller: _controller,
              onAutoRefreshChanged: widget.onAutoRefreshChanged,
              trailing: [_refreshButton()],
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: ServerLogViewer(
                controller: _controller,
                onExpand: _expand,
              ),
            ),
          ],
        ),
      );
    }
    final size = MediaQuery.sizeOf(context);
    final logHeight = size.width >= 720
        ? 620.0
        : (size.height * 0.6).clamp(320.0, 640.0);
    return DetailSection(
      title: widget.title,
      icon: AppIcons.logs,
      trailing: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => IconButton(
          tooltip: 'Refresh logs',
          onPressed: _controller.loading ? null : _controller.load,
          icon: const Icon(AppIcons.refresh, size: 20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServerLogToolbar(
            controller: _controller,
            onAutoRefreshChanged: widget.onAutoRefreshChanged,
          ),
          const Gap(10),
          ServerLogViewer(
            controller: _controller,
            height: logHeight,
            onExpand: () => ServerLogFullscreenPage.open(
              context,
              controller: _controller,
              title: widget.title,
              onAutoRefreshChanged: widget.onAutoRefreshChanged,
            ),
          ),
        ],
      ),
    );
  }
}

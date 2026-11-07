import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/async/async_value_x.dart';
import 'package:komodo_go/core/widgets/async/refresh_progress_bar.dart';
import 'package:komodo_go/core/widgets/async/stale_data_banner.dart';

/// Background-refresh feedback for a list that keeps its content on screen:
/// the thin [RefreshProgressBar] (hidden while [pulling]) followed by a
/// [StaleDataBanner] when a refresh failed but older data is still shown.
///
/// [onRetry] should refresh without hiding the progress bar (e.g.
/// `PullRefreshMixin.refreshData`), so the user sees the retry running.
class RefreshStatusHeader extends StatelessWidget {
  const RefreshStatusHeader({
    required this.async,
    required this.pulling,
    required this.onRetry,
    this.bannerPadding = const EdgeInsets.only(bottom: 12),
    super.key,
  });

  final AsyncValue<Object?> async;

  /// True during pull-to-refresh, where the RefreshIndicator spinner is
  /// already visible.
  final bool pulling;

  final Future<void> Function() onRetry;

  /// Space around the stale-data banner while visible.
  final EdgeInsetsGeometry bannerPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RefreshProgressBar(active: async.isBackgroundRefresh && !pulling),
        StaleDataBanner(
          visible: async.hasStaleError,
          error: async.error,
          onRetry: () => unawaited(onRetry()),
          padding: bannerPadding,
        ),
      ],
    );
  }
}

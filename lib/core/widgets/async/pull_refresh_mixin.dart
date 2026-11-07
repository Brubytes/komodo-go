import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Pull-to-refresh bookkeeping shared by list screens.
///
/// Implement [refreshData] with the awaited refresh (typically
/// `refreshProviders`). Wire [pullRefresh] to `RefreshIndicator.onRefresh`,
/// and [refreshData] to the stale-data banner's Retry. While a pull runs,
/// [isPulling] is true so the thin `RefreshProgressBar` can stay hidden
/// instead of doubling up with the RefreshIndicator spinner.
mixin PullRefreshMixin<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  bool _pulling = false;

  /// True while a pull-to-refresh is running.
  bool get isPulling => _pulling;

  /// Refreshes the screen's data without touching [isPulling], so the thin
  /// progress bar shows (used by the stale-data banner's Retry).
  Future<void> refreshData();

  /// Pull-to-refresh: the RefreshIndicator spinner is visible, hide the bar.
  Future<void> pullRefresh() async {
    setState(() => _pulling = true);
    try {
      await refreshData();
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }
}

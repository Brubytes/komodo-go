import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komodo_go/core/async/async_value_x.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/async/refresh_progress_bar.dart';
import 'package:komodo_go/core/widgets/async/stale_data_banner.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';

/// Renders an [AsyncValue] without ever replacing existing content.
///
/// * No value and loading: skeleton ([skeletonBuilder], default
///   [AppSkeletonCard]).
/// * No value and error: [ErrorStateView] with Retry.
/// * Has a value (including during reload/refresh and after a failed
///   refresh): always [builder]'s content, plus a thin [RefreshProgressBar] at
///   the top while loading and a [StaleDataBanner] when the latest fetch
///   failed.
///
/// The switch between the three kinds is animated with `AppSwitcher` keyed by
/// kind, never by data, so polling and refreshes do not trigger transitions.
/// [builder] is called with the (possibly stale) value and stays mounted.
///
/// Layout modes:
/// * default (`fill: false`): inline box for use inside a scroll view or a
///   detail tab (`DetailTabScrollView.box(child: AsyncContent(...))`).
/// * `fill: true`: fills a bounded area; [builder] should return a scrollable
///   (e.g. `ListView` with `AlwaysScrollableScrollPhysics`). The skeleton and
///   error states are wrapped in an always-scrollable view so that a
///   surrounding `RefreshIndicator` works in every state.
///
/// For `CustomScrollView` screens use [SliverAsyncContent].
/// ```dart
/// AsyncContent<List<Foo>>(
///   value: ref.watch(foosProvider),
///   errorTitle: 'Failed to load foos',
///   onRetry: () => ref.invalidate(foosProvider),
///   fill: true,
///   builder: (context, foos) => FooList(foos),
/// )
/// ```
class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    required this.value,
    required this.builder,
    required this.onRetry,
    super.key,
    this.errorTitle = 'Failed to load',
    this.skeletonBuilder,
    this.minHeight = 0,
    this.fill = false,
    this.showProgress = true,
    this.showStaleBanner = true,
    this.bannerPadding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final AsyncValue<T> value;

  /// Builds the content for the current (possibly stale) value.
  final Widget Function(BuildContext context, T data) builder;

  /// Called by the error view's and the stale banner's Retry button.
  final VoidCallback onRetry;

  final String errorTitle;

  /// First-load placeholder. Make it roughly as tall as the real content to
  /// avoid a jump when data arrives; see also [minHeight].
  final WidgetBuilder? skeletonBuilder;

  /// Minimum height of the first-load and error states (inline mode).
  final double minHeight;

  /// Fill a bounded area with scrollable first-load/error states.
  final bool fill;

  /// Show the thin progress bar while refreshing with existing content.
  final bool showProgress;

  /// Show the inline banner when a refresh failed but content exists.
  final bool showStaleBanner;

  /// Padding of the stale banner; use [EdgeInsets.zero] if the surrounding
  /// layout already pads.
  final EdgeInsetsGeometry bannerPadding;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (value.hasValue) {
      child = _content(context, value.requireValue);
    } else if (value.hasError) {
      child = _scrollable(
        key: const ValueKey('async_error'),
        child: _withRetryBar(
          value: value,
          showProgress: showProgress,
          child: ErrorStateView.fromError(
            title: errorTitle,
            error: value.error!,
            onRetry: onRetry,
          ),
        ),
      );
    } else {
      child = _scrollable(
        key: const ValueKey('async_first_load'),
        child: skeletonBuilder?.call(context) ?? const AppSkeletonCard(),
      );
    }
    return AppSwitcher(
      animateSize: !fill,
      alignment: fill ? Alignment.center : Alignment.topCenter,
      child: child,
    );
  }

  Widget _content(BuildContext context, T data) {
    final body = builder(context, data);
    return Stack(
      key: const ValueKey('async_content'),
      fit: StackFit.passthrough,
      children: [
        Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaleDataBanner(
              visible: showStaleBanner && value.hasStaleError,
              error: value.error,
              onRetry: onRetry,
              padding: bannerPadding,
            ),
            if (fill) Expanded(child: body) else body,
          ],
        ),
        if (showProgress)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: RefreshProgressBar(active: value.isLoading),
            ),
          ),
      ],
    );
  }

  Widget _scrollable({required Key key, required Widget child}) {
    if (!fill) {
      return ConstrainedBox(
        key: key,
        constraints: BoxConstraints(minHeight: minHeight),
        child: child,
      );
    }
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: bounded
                  ? math.max(constraints.maxHeight, minHeight)
                  : minHeight,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Overlays a [RefreshProgressBar] at the top of a first-load error page, so
/// tapping Retry gives feedback (the value is then error + loading) without
/// swapping the layout.
Widget _withRetryBar({
  required AsyncValue<Object?> value,
  required bool showProgress,
  required Widget child,
}) {
  if (!showProgress) return child;
  return Stack(
    children: [
      child,
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: RefreshProgressBar(active: value.isLoading),
        ),
      ),
    ],
  );
}

/// Sliver counterpart of [AsyncContent] for `CustomScrollView` screens.
///
/// [builder] returns a sliver. The first-load skeleton and error state are
/// slivers too (the error uses `SliverFillRemaining`), so a
/// `RefreshIndicator` around the scroll view keeps working in every state.
/// The progress bar and stale banner are leading box slivers (the bar
/// reserves 2px, so nothing shifts). Kind switches are not cross-faded
/// because slivers cannot be wrapped in a switcher; use the box variant if
/// you need that.
/// ```dart
/// CustomScrollView(
///   physics: const AlwaysScrollableScrollPhysics(),
///   slivers: [
///     SliverAsyncContent<List<Foo>>(
///       value: foosAsync,
///       onRetry: retry,
///       builder: (context, foos) => SliverList.builder(...),
///     ),
///   ],
/// )
/// ```
class SliverAsyncContent<T> extends StatelessWidget {
  const SliverAsyncContent({
    required this.value,
    required this.builder,
    required this.onRetry,
    super.key,
    this.errorTitle = 'Failed to load',
    this.skeletonBuilder,
    this.showProgress = true,
    this.showStaleBanner = true,
    this.bannerPadding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final AsyncValue<T> value;

  /// Builds the content sliver for the current (possibly stale) value.
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final String errorTitle;

  /// First-load placeholder (a box widget, wrapped in a sliver for you).
  final WidgetBuilder? skeletonBuilder;
  final bool showProgress;
  final bool showStaleBanner;
  final EdgeInsetsGeometry bannerPadding;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      return SliverMainAxisGroup(
        slivers: [
          if (showProgress)
            SliverToBoxAdapter(
              child: RefreshProgressBar(active: value.isLoading),
            ),
          SliverToBoxAdapter(
            child: StaleDataBanner(
              visible: showStaleBanner && value.hasStaleError,
              error: value.error,
              onRetry: onRetry,
              padding: bannerPadding,
            ),
          ),
          builder(context, value.requireValue),
        ],
      );
    }
    if (value.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _withRetryBar(
          value: value,
          showProgress: showProgress,
          child: ErrorStateView.fromError(
            title: errorTitle,
            error: value.error!,
            onRetry: onRetry,
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: skeletonBuilder?.call(context) ?? const AppSkeletonCard(),
    );
  }
}

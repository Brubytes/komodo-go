import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komodo_go/core/async/async_value_x.dart';
import 'package:komodo_go/core/widgets/async/async_content.dart';

/// Keeps a config editor mounted across reloads, refreshes and failed
/// refreshes, and only feeds it new server data while it is not dirty.
///
/// Problem it solves: an editor built inside `asyncValue.when(...)` is
/// unmounted whenever the provider goes back to loading or error, which
/// throws away its controllers, `GlobalKey` state and unsaved edits.
///
/// How it works:
/// * The first non-null value builds the editor. From then on the editor
///   stays in the tree no matter what the [value] does (loading, error). A
///   progress bar / stale banner from [AsyncContent] shows the refresh state
///   above it.
/// * New server data replaces the data passed to [builder] only when
///   [isDirty] returns false. While dirty, the newest data is held back
///   (the user's draft wins); it is applied on the first rebuild after the
///   editor becomes clean (a dirty-change `setState` in the parent does
///   that). Editors should additionally implement `didUpdateWidget` that
///   compares `initialConfig` (see `StackConfigEditorContent`).
/// * After a successful save, call `resetTo(...)` on the editor as before;
///   the next server value is then adopted because the editor is clean.
///
/// ```dart
/// EditorHost<StackConfig>(
///   value: stackAsync.whenData((s) => s?.config),
///   isDirty: () => _configDirty,
///   onRetry: () => ref.invalidate(stackDetailProvider(id)),
///   builder: (context, config) => StackConfigEditorContent(
///     key: _configEditorKey,
///     initialConfig: config,
///     onDirtyChanged: (dirty) => _onDirtyChanged(config: dirty),
///   ),
/// )
/// ```
/// Pass `ref.watch(provider).whenData(...)` or build the [AsyncValue] with
/// `copyWithPrevious` yourself; only the carried value matters here since the
/// host remembers the last one itself. A null data value means "nothing to
/// edit" and renders [emptyBuilder]; a settled null while the editor is clean
/// also drops the previously shown editor (the resource is gone).
class EditorHost<T extends Object> extends StatefulWidget {
  const EditorHost({
    required this.value,
    required this.builder,
    required this.onRetry,
    super.key,
    this.isDirty,
    this.errorTitle = 'Failed to load',
    this.skeletonBuilder,
    this.emptyBuilder,
    this.minHeight = 0,
    this.bannerPadding = EdgeInsets.zero,
    this.showProgress = true,
    this.showStaleBanner = true,
  });

  final AsyncValue<T?> value;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;

  /// Whether the editor holds unsaved edits. While true, new server data is
  /// not passed to [builder].
  final bool Function()? isDirty;

  final String errorTitle;
  final WidgetBuilder? skeletonBuilder;

  /// Rendered when loading finished with no data (null). Default: nothing.
  final WidgetBuilder? emptyBuilder;
  final double minHeight;
  final EdgeInsetsGeometry bannerPadding;

  /// Forwarded to [AsyncContent]; turn off when the screen already shows the
  /// refresh state of the same provider elsewhere (e.g. in its header).
  final bool showProgress;
  final bool showStaleBanner;

  @override
  State<EditorHost<T>> createState() => _EditorHostState<T>();
}

class _EditorHostState<T extends Object> extends State<EditorHost<T>> {
  T? _shown;

  /// Newest server data that arrived while the editor was dirty.
  T? _held;

  @override
  void initState() {
    super.initState();
    _absorb();
  }

  @override
  void didUpdateWidget(EditorHost<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _absorb();
  }

  void _absorb() {
    final raw = widget.value;
    final dirty = widget.isDirty?.call() ?? false;
    // Settled "nothing to edit" (e.g. the resource was deleted): stop showing
    // the stale editor, unless it holds unsaved edits.
    if (raw.hasValue &&
        raw.value == null &&
        !raw.isLoading &&
        !raw.hasError &&
        !dirty) {
      _shown = null;
      _held = null;
      return;
    }
    final incoming = widget.value.value ?? _held;
    if (incoming == null) return;
    final shown = _shown;
    if (shown == null || !dirty) {
      _shown = incoming;
      _held = null;
    } else if (!identical(incoming, shown) && incoming != shown) {
      _held = incoming;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final raw = widget.value;
    final AsyncValue<T?> effective;
    if (shown == null) {
      effective = raw;
    } else if (raw.hasError) {
      effective = asyncWithPrevious<T?>(
        AsyncError<T?>(raw.error!, raw.stackTrace ?? StackTrace.empty),
        AsyncData<T?>(shown),
      );
    } else if (raw.isLoading) {
      effective = asyncWithPrevious<T?>(
        AsyncLoading<T?>(),
        AsyncData<T?>(shown),
      );
    } else {
      effective = AsyncData<T?>(shown);
    }
    return AsyncContent<T?>(
      value: effective,
      errorTitle: widget.errorTitle,
      onRetry: widget.onRetry,
      skeletonBuilder: widget.skeletonBuilder,
      minHeight: widget.minHeight,
      bannerPadding: widget.bannerPadding,
      showProgress: widget.showProgress,
      showStaleBanner: widget.showStaleBanner,
      builder: (context, data) => data == null
          ? widget.emptyBuilder?.call(context) ?? const SizedBox.shrink()
          : widget.builder(context, data),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Edge of the window the system reserves for a vertical bar (iOS 27.1+, e.g.
/// the foldable iPhone's inner display).
enum VerticalBarEdge { leading, trailing }

/// What the system reports about the vertical bar strip.
@immutable
class VerticalBarInfo {
  const VerticalBarInfo({
    required this.edge,
    this.occludedRegions = const [],
  });

  final VerticalBarEdge edge;

  /// Regions covered by the status bar or camera, in logical pixels of the
  /// window.
  final List<Rect> occludedRegions;

  /// Bounding box of [occludedRegions], if any.
  Rect? get occludedRect => occludedRegions.isEmpty
      ? null
      : occludedRegions.reduce((a, b) => a.expandToInclude(b));

  /// Physical side of the strip for [direction].
  bool isOnRight(TextDirection direction) =>
      (edge == VerticalBarEdge.trailing) == (direction == TextDirection.ltr);

  /// Lowest y the occluded regions reach inside the strip of [stripWidth] on
  /// the given side of a window [windowWidth] wide; 0 if none.
  double occludedBottomInStrip({
    required double windowWidth,
    required double stripWidth,
    required bool onRight,
  }) {
    var bottom = 0.0;
    for (final r in occludedRegions) {
      final inStrip = onRight
          ? r.right > windowWidth - stripWidth
          : r.left < stripWidth;
      if (inStrip && r.bottom > bottom) bottom = r.bottom;
    }
    return bottom;
  }

  @override
  bool operator ==(Object other) =>
      other is VerticalBarInfo &&
      other.edge == edge &&
      listEquals(other.occludedRegions, occludedRegions);

  @override
  int get hashCode => Object.hash(edge, Object.hashAll(occludedRegions));
}

/// Exposes the current [VerticalBarInfo] (null = no vertical bar).
class VerticalBarScope extends InheritedWidget {
  const VerticalBarScope({
    required this.info,
    required super.child,
    super.key,
  });

  final VerticalBarInfo? info;

  static VerticalBarInfo? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VerticalBarScope>()?.info;

  @override
  bool updateShouldNotify(VerticalBarScope oldWidget) => info != oldWidget.info;
}

/// Physical sides on which the system reserves a vertical bar strip.
({bool left, bool right}) verticalBarSides(BuildContext context) {
  final info = VerticalBarScope.maybeOf(context);
  if (info == null) return (left: false, right: false);
  final onRight = info.isOnRight(
    Directionality.maybeOf(context) ?? TextDirection.ltr,
  );
  return (left: !onRight, right: onRight);
}

/// Applies the system inset on the vertical bar side only. The app root
/// leaves that side to the screens, so the shell can place its navigation in
/// the strip; screens outside the shell wrap themselves in this.
class VerticalBarSafeArea extends StatelessWidget {
  const VerticalBarSafeArea({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sides = verticalBarSides(context);
    return SafeArea(
      left: sides.left,
      right: sides.right,
      top: false,
      bottom: false,
      child: child,
    );
  }
}

/// Asks the iOS runner for the vertical bar edge and occluded regions
/// whenever the window metrics change (fold/unfold, rotation, Split View) and
/// provides them through [VerticalBarScope]. Without a native answer (other
/// platforms, older iOS, tests) the info is null and nothing changes.
class VerticalBarHost extends StatefulWidget {
  const VerticalBarHost({required this.child, super.key});

  final Widget child;

  static const MethodChannel channel = MethodChannel(
    'app.komodo_go/vertical_bar',
  );

  @override
  State<VerticalBarHost> createState() => _VerticalBarHostState();
}

class _VerticalBarHostState extends State<VerticalBarHost>
    with WidgetsBindingObserver {
  VerticalBarInfo? _info;

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => unawaited(_refresh());

  Future<void> _refresh() async {
    if (!_supported) return;
    VerticalBarInfo? next;
    try {
      final raw = await VerticalBarHost.channel
          .invokeMapMethod<String, Object?>(
            'getInfo',
          );
      next = _parse(raw);
    } on MissingPluginException {
      next = null;
    } on PlatformException {
      next = null;
    }
    if (!mounted || next == _info) return;
    setState(() => _info = next);
  }

  static VerticalBarInfo? _parse(Map<String, Object?>? raw) {
    if (raw == null) return null;
    final edge = switch (raw['edge']) {
      'leading' => VerticalBarEdge.leading,
      'trailing' => VerticalBarEdge.trailing,
      _ => null,
    };
    if (edge == null) return null;
    final regions = <Rect>[];
    for (final item in (raw['occluded'] as List<Object?>? ?? const [])) {
      final v = (item! as List<Object?>).cast<num>();
      regions.add(
        Rect.fromLTWH(
          v[0].toDouble(),
          v[1].toDouble(),
          v[2].toDouble(),
          v[3].toDouble(),
        ),
      );
    }
    return VerticalBarInfo(edge: edge, occludedRegions: regions);
  }

  @override
  Widget build(BuildContext context) =>
      VerticalBarScope(info: _info, child: widget.child);
}

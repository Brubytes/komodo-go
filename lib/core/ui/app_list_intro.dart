import 'package:flutter/widgets.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// One policy for list intros.
///
/// Own one instance per screen/list (e.g. a `late final` field of a `State`)
/// and wrap each item with [wrap]:
///
/// * During the first built frame in which any item is requested, items with
///   `index < AppMotion.introItemLimit` fade and slide in, staggered by
///   `AppMotion.stagger(index)`. Later items of that frame are not animated.
/// * Items first seen after that frame (polling inserts, scrolling) get a
///   short fade at `AppMotion.fast`, without slide or stagger.
/// * An item that was already seen never animates again, even if it is
///   rebuilt or scrolled out and back in.
///
/// The widget type returned by [wrap] is stable, so rebuilds keep state.
/// Reduced motion is handled by `AppFadeSlide` (no animation).
class AppListIntro {
  AppListIntro({this.enabled = true, this.limit = AppMotion.introItemLimit});

  /// When false, nothing ever animates.
  final bool enabled;

  /// Number of leading items that take part in the intro.
  final int limit;

  bool _scheduled = false;
  bool _introDone = false;
  final Set<Object> _seen = <Object>{};

  /// True while the intro frame is still in progress.
  bool get introPending => !_introDone;

  void _arm() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _introDone = true);
  }

  /// Whether the item at [index] plays the staggered intro right now.
  bool shouldPlay(int index) => enabled && !_introDone && index < limit;

  /// Stagger delay of the item at [index] (zero outside the intro).
  Duration delay(int index) =>
      shouldPlay(index) ? AppMotion.stagger(index) : Duration.zero;

  /// Wraps [child] with the intro animation matching its position.
  ///
  /// [id] identifies the item across rebuilds (e.g. resource id); it defaults
  /// to [index]. Use it when items can be inserted or reordered.
  Widget wrap(int index, Widget child, {Object? id}) {
    if (!enabled) return child;
    _arm();
    final key = id ?? index;
    final firstSight = _seen.add(key);
    if (!firstSight) {
      // Already seen: stable wrapper, never replays.
      return AppFadeSlide(play: false, child: child);
    }
    if (!_introDone) {
      if (index < limit) {
        return AppFadeSlide(delay: AppMotion.stagger(index), child: child);
      }
      return AppFadeSlide(play: false, child: child);
    }
    return AppFadeSlide(
      duration: AppMotion.fast,
      offsetY: 0,
      curve: AppMotion.standard,
      child: child,
    );
  }
}

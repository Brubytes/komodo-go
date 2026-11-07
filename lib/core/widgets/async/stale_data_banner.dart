import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/detail/detail_resource_header.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';

/// Compact inline banner for "refresh failed, showing the last loaded data".
///
/// Built on [DetailAttentionBanner] (warning tone by default) with a Retry
/// action. [visible] animates it in and out (size + fade) so it never pops;
/// when hidden it takes no space. Pass the failure as [error] to include a
/// short friendly reason, or a custom [message].
///
/// `AsyncContent` shows it automatically for `hasValue && hasError`.
/// ```dart
/// StaleDataBanner(visible: async.hasStaleError, error: async.error, onRetry: retry)
/// ```
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({
    required this.visible,
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.tone = PillTone.warning,
    this.padding = EdgeInsets.zero,
  });

  final bool visible;
  final Object? error;

  /// Overrides the generated message.
  final String? message;
  final VoidCallback? onRetry;
  final PillTone tone;

  /// Space around the banner while visible.
  final EdgeInsetsGeometry padding;

  static const _maxReasonLength = 90;

  String _message() {
    if (message != null) return message!;
    const base = "Couldn't refresh. Showing last loaded data.";
    final err = error;
    if (err == null) return base;
    var reason = friendlyErrorMessage(err);
    if (reason.length > _maxReasonLength) {
      reason = '${reason.substring(0, _maxReasonLength - 1).trimRight()}…';
    }
    return "Couldn't refresh: $reason";
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reducedOf(context);
    return AnimatedSize(
      duration: reduced ? Duration.zero : AppMotion.base,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: visible
            ? Padding(
                key: const ValueKey('stale_data_banner'),
                padding: padding,
                child: DetailAttentionBanner(
                  icon: AppIcons.warning,
                  message: _message(),
                  tone: tone,
                  actionLabel: onRetry == null ? null : 'Retry',
                  onAction: onRetry,
                ),
              )
            : const SizedBox.shrink(key: ValueKey('stale_data_banner_hidden')),
      ),
    );
  }
}

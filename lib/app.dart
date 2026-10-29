import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/providers/theme_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_theme.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// The root application widget.
class KomodoApp extends ConsumerWidget {
  const KomodoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Komodo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => SkeletonizerConfig(
        data: _skeletonConfig(context),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  /// App-wide skeleton look: subtle shimmer, a static tint under reduced
  /// motion, and a cross-fade when a Skeletonizer toggles off.
  static SkeletonizerConfigData _skeletonConfig(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.onSurface.withValues(alpha: 0.08);
    final highlight = scheme.onSurface.withValues(alpha: 0.14);
    final effect = AppMotion.reducedOf(context)
        ? SolidColorEffect(color: base)
        : ShimmerEffect(
            baseColor: base,
            highlightColor: highlight,
            duration: AppMotion.shimmer,
          );
    return SkeletonizerConfigData(
      effectResolver: (_) => effect,
      enableSwitchAnimation: true,
      switchAnimationConfig: const SwitchAnimationConfig(
        duration: AppMotion.base,
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.standard,
      ),
    );
  }
}

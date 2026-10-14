import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';

/// Status line shown under a detail page title: a colored dot plus label,
/// e.g. "Running · 2 services" or "Ok · built 5m ago".
class MainAppBarStatus {
  const MainAppBarStatus({required this.label, this.tone = PillTone.neutral});

  final String label;
  final PillTone tone;
}

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({
    required this.title,
    this.subtitle,
    this.status,
    this.icon,
    this.markColor,
    this.markUseGradient,
    this.centerTitle,
    this.actions,
    this.bottom,
    this.onTitleLongPress,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Takes precedence over [subtitle] when set.
  final MainAppBarStatus? status;
  final IconData? icon;
  final Color? markColor;
  final bool? markUseGradient;
  final bool? centerTitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final VoidCallback? onTitleLongPress;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCentered = centerTitle ?? false;

    return AppBar(
      centerTitle: isCentered,
      titleSpacing: isCentered ? 0 : 16,
      toolbarHeight: 68,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(
        bottom: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      title: GestureDetector(
        onLongPress: onTitleLongPress,
        behavior: HitTestBehavior.opaque,
        child: MainAppBarTitle(
          title: title,
          subtitle: subtitle,
          status: status,
          icon: icon,
          markColor: markColor,
          markUseGradient: markUseGradient,
          centered: isCentered,
        ),
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}

class MainAppBarTitle extends StatelessWidget {
  const MainAppBarTitle({
    required this.title,
    this.subtitle,
    this.status,
    this.icon,
    this.markColor,
    this.markUseGradient,
    this.centered = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final MainAppBarStatus? status;
  final IconData? icon;
  final Color? markColor;
  final bool? markUseGradient;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    );
    final subtitleStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.1,
    );

    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle, overflow: TextOverflow.ellipsis),
        if (status != null && status!.label.trim().isNotEmpty)
          _StatusLine(status: status!, style: subtitleStyle)
        else if (subtitle != null && subtitle!.trim().isNotEmpty)
          Text(
            subtitle!,
            style: subtitleStyle,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _Mark(
          icon: icon,
          title: title,
          color: markColor,
          useGradient: markUseGradient,
        ),
        const Gap(12),
        if (centered)
          // Flexible lets the title shrink when leading/actions leave less
          // room than the 60% cap, so long names ellipsize instead of
          // overflowing the toolbar.
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.6,
              ),
              child: titleBlock,
            ),
          )
        else
          Flexible(child: titleBlock),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.style});

  final MainAppBarStatus status;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = pillToneForeground(
      Theme.of(context).colorScheme,
      status.tone,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const Gap(6),
        Flexible(
          child: Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.icon,
    required this.title,
    this.color,
    this.useGradient,
  });

  final IconData? icon;
  final String title;
  final Color? color;
  final bool? useGradient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shouldUseGradient = color == null || (useGradient ?? false);

    BoxDecoration decoration;
    if (color == null) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTokens.brandPrimary, AppTokens.brandSecondary],
        ),
        borderRadius: BorderRadius.circular(10),
      );
    } else if (shouldUseGradient) {
      Color tone(Color base, {required double lightnessDelta}) {
        final hsl = HSLColor.fromColor(base);
        final next = (hsl.lightness + lightnessDelta).clamp(0.0, 1.0);
        return hsl.withLightness(next).toColor();
      }

      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone(color!, lightnessDelta: -0.10),
            tone(color!, lightnessDelta: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      );
    } else {
      decoration = BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      );
    }

    final foreground = () {
      if (color == null) {
        return scheme.brightness == Brightness.dark
            ? scheme.onSecondary
            : scheme.onPrimary;
      }

      final brightness = ThemeData.estimateBrightnessForColor(color!);
      return brightness == Brightness.dark ? Colors.white : Colors.black;
    }();

    return Container(
      width: 32,
      height: 32,
      decoration: decoration,
      alignment: Alignment.center,
      child: icon == null
          ? Text(
              title.trim().isEmpty ? 'K' : title.trim().characters.first,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w900,
              ),
            )
          : Icon(icon, size: 18, color: foreground),
    );
  }
}

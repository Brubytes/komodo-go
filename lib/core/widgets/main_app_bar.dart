import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../theme/app_tokens.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({
    required this.title,
    this.subtitle,
    this.icon,
    this.actions,
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      centerTitle: false,
      titleSpacing: 16,
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
      title: MainAppBarTitle(
        title: title,
        subtitle: subtitle,
        icon: icon,
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
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

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

    return Row(
      children: [
        _Mark(icon: icon, title: title),
        const Gap(12),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle, overflow: TextOverflow.ellipsis),
              if (subtitle != null && subtitle!.trim().isNotEmpty)
                Text(
                  subtitle!,
                  style: subtitleStyle,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.icon, required this.title});

  final IconData? icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = scheme.brightness == Brightness.dark
        ? scheme.onSecondary
        : scheme.onPrimary;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTokens.brandPrimary, AppTokens.brandSecondary],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
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


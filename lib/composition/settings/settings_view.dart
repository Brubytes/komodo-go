import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/providers/theme_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authAsync = ref.watch(authProvider);
    final connection = authAsync.asData?.value.connection;
    final coreVersion = ref.watch(komodoCoreVersionProvider);
    final capabilities = ref.watch(komodoApiCapabilitiesProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const MainAppBar(title: 'Settings', icon: AppIcons.settings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const Gap(4),
          const _SettingsSectionHeader(title: 'Connection'),
          const Gap(8),
          _SettingsCardTile(
            icon: AppIcons.server,
            accentColor: scheme.primary,
            title: 'Connections',
            subtitle: connection?.baseUrl,
            trailing: _CardTrailing(label: connection?.name, showChevron: true),
            onTap: () => context.push(AppRoutes.connections),
          ),
          if (coreVersion != null) ...[
            const Gap(10),
            _SettingsCardTile(
              icon: AppIcons.info,
              accentColor: scheme.primary,
              title: 'Komodo Core',
              subtitle: capabilities.isLegacyV22
                  ? 'Komodo 2.2 compatibility mode'
                  : null,
              trailing: _CardTrailing(
                label: coreVersion.display,
                showChevron: false,
              ),
            ),
          ],
          const Gap(20),
          const _SettingsSectionHeader(title: 'Appearance'),
          const Gap(8),
          AppCardSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(AppIcons.theme, size: 20, color: scheme.primary),
                ),
                const Gap(12),
                Expanded(
                  child: SegmentedButton<ThemeMode>(
                    key: const ValueKey('settings_theme_selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => unawaited(
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(selection.first),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),
          const _SettingsSectionHeader(title: 'About'),
          const Gap(8),
          _SettingsCardTile(
            icon: AppIcons.heart,
            accentColor: scheme.primary,
            title: 'About Komodo Go',
            trailing: const _CardTrailing(showChevron: true),
            onTap: () => context.push(AppRoutes.credits),
          ),
          const Gap(20),
          const _SettingsSectionHeader(title: 'Account'),
          const Gap(8),
          _SettingsCardTile(
            icon: AppIcons.logout,
            accentColor: scheme.error,
            title: 'Logout',
            enabled: !authAsync.isLoading,
            trailing: const _CardTrailing(showChevron: false),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Logout',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  content: const Text('Are you sure you want to disconnect?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if ((confirmed ?? false) && context.mounted) {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          Container(
            width: 34,
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

class _SettingsCardTile extends StatelessWidget {
  const _SettingsCardTile({
    required this.icon,
    required this.accentColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.enabled = true,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: cardRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: accentColor),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const Gap(2),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(12),
                DefaultTextStyle.merge(
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  child:
                      trailing ??
                      Icon(
                        AppIcons.chevron,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTrailing extends StatelessWidget {
  const _CardTrailing({required this.showChevron, this.label});

  final String? label;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.trim().isNotEmpty) ...[
          TextPill(label: label!),
          const Gap(8),
        ],
        if (showChevron)
          Icon(
            AppIcons.chevron,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
          ),
      ],
    );
  }
}

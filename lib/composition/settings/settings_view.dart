import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/providers/theme_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/layout/list_detail_layout.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/segmented/app_segmented_control.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({this.activeRoute, super.key});

  /// Settings page shown in the detail pane, highlighted in the index.
  final String? activeRoute;

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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          28,
        ),
        children: [
          const Gap(AppSpacing.xs),
          const _SettingsSectionHeader(title: 'Connection'),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            icon: AppIcons.server,
            accentColor: scheme.primary,
            title: 'Connections',
            subtitle: connection?.baseUrl,
            trailing: _CardTrailing(label: connection?.name, showChevron: true),
            selected: activeRoute == AppRoutes.connections,
            onTap: () => context.openDetail(AppRoutes.connections),
          ),
          if (coreVersion != null) ...[
            const Gap(AppSpacing.sm),
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
          const Gap(AppSpacing.sm),
          AppCardSurface(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
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
                const Gap(AppSpacing.md),
                Expanded(
                  child: AppSegmentedControl<ThemeMode>(
                    key: const ValueKey('settings_theme_selector'),
                    segments: const [
                      AppSegmentOption(
                        value: ThemeMode.system,
                        label: 'System',
                      ),
                      AppSegmentOption(value: ThemeMode.light, label: 'Light'),
                      AppSegmentOption(value: ThemeMode.dark, label: 'Dark'),
                    ],
                    value: themeMode,
                    onChanged: (mode) => unawaited(
                      ref.read(themeModeProvider.notifier).setThemeMode(mode),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),
          const _SettingsSectionHeader(title: 'Komodo'),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            key: const ValueKey('settings_komodo_autoUpdateReview'),
            icon: Icons.system_update_alt,
            accentColor: scheme.primary,
            title: 'Auto-update review',
            subtitle: 'Check images and review updates before deployment',
            trailing: const _CardTrailing(showChevron: true),
            selected: activeRoute == AppRoutes.autoUpdateReview,
            onTap: () => context.openDetail(AppRoutes.autoUpdateReview),
          ),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            key: const ValueKey('settings_komodo_komodoVariables'),
            icon: AppIcons.key,
            accentColor: scheme.primary,
            title: 'Variables',
            subtitle: 'View and edit global variables',
            trailing: const _CardTrailing(showChevron: true),
            selected: activeRoute == AppRoutes.komodoVariables,
            onTap: () => context.openDetail(AppRoutes.komodoVariables),
          ),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            key: const ValueKey('settings_komodo_komodoTags'),
            icon: AppIcons.tag,
            accentColor: scheme.primary,
            title: 'Tags',
            subtitle: 'View and edit tags',
            trailing: const _CardTrailing(showChevron: true),
            selected: activeRoute == AppRoutes.komodoTags,
            onTap: () => context.openDetail(AppRoutes.komodoTags),
          ),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            key: const ValueKey('settings_komodo_komodoProviders'),
            icon: AppIcons.repos,
            accentColor: scheme.primary,
            title: 'Providers',
            subtitle: 'Manage git and registry accounts',
            trailing: const _CardTrailing(showChevron: true),
            selected: activeRoute == AppRoutes.komodoProviders,
            onTap: () => context.openDetail(AppRoutes.komodoProviders),
          ),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            key: const ValueKey('settings_komodo_komodoBuilders'),
            icon: AppIcons.factory,
            accentColor: scheme.primary,
            title: 'Builders',
            subtitle: 'View and manage builders',
            trailing: const _CardTrailing(showChevron: true),
            selected: activeRoute == AppRoutes.komodoBuilders,
            onTap: () => context.openDetail(AppRoutes.komodoBuilders),
          ),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            key: const ValueKey('settings_komodo_komodoAlerters'),
            icon: AppIcons.notifications,
            accentColor: scheme.primary,
            title: 'Alerters',
            subtitle: 'View and manage alerters',
            trailing: const _CardTrailing(showChevron: true),
            selected: activeRoute == AppRoutes.komodoAlerters,
            onTap: () => context.openDetail(AppRoutes.komodoAlerters),
          ),
          const Gap(20),
          const _SettingsSectionHeader(title: 'About'),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            icon: AppIcons.heart,
            accentColor: scheme.primary,
            title: 'About Komodo Go',
            trailing: const _CardTrailing(showChevron: true),
            selected: activeRoute == AppRoutes.credits,
            onTap: () => context.openDetail(AppRoutes.credits),
          ),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            icon: AppIcons.mail,
            accentColor: scheme.primary,
            title: 'Contact & feedback',
            subtitle: 'Questions, suggestions, or bug reports',
            trailing: const _CardTrailing(showChevron: false),
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: 'info@komodogo.eu',
                // Some email clients keep '+' instead of decoding it to spaces.
                query: 'subject=${Uri.encodeComponent('Komodo Go Feedback')}',
              );
              final launched = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!launched && context.mounted) {
                AppSnackBar.show(
                  context,
                  'No email app available to handle this.',
                  tone: AppSnackBarTone.error,
                );
              }
            },
          ),
          const Gap(20),
          const _SettingsSectionHeader(title: 'Account'),
          const Gap(AppSpacing.sm),
          _SettingsCardTile(
            icon: AppIcons.logout,
            accentColor: scheme.error,
            title: 'Logout',
            enabled: !authAsync.isLoading,
            trailing: const _CardTrailing(showChevron: false),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                animationStyle: AppMotion.dialogStyle(context),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
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
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return SelectionHighlight(
      selected: selected,
      child: AppCardSurface(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: cardRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: cardRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
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
                  const Gap(AppSpacing.md),
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
                          const Gap(AppSpacing.xxs),
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
                  const Gap(AppSpacing.md),
                  DefaultTextStyle.merge(
                    style: TextStyle(color: scheme.onSurfaceVariant),
                    child:
                        trailing ??
                        Icon(
                          AppIcons.chevron,
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.65,
                          ),
                        ),
                  ),
                ],
              ),
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
          const Gap(AppSpacing.sm),
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

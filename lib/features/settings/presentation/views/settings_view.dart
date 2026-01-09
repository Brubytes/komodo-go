import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:komodo_go/features/settings/presentation/providers/theme_provider.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authAsync = ref.watch(authProvider);
    final connection = authAsync.asData?.value.connection;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Settings',
        icon: AppIcons.settings,
      ),
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
            subtitle: connection == null
                ? 'Manage server connections'
                : connection.baseUrl,
            trailing: _CardTrailing(
              label: connection?.name,
              showChevron: true,
            ),
            onTap: () => context.push(AppRoutes.connections),
          ),
          const Gap(20),
          const _SettingsSectionHeader(title: 'Appearance'),
          const Gap(8),
          _SettingsCardTile(
            icon: AppIcons.theme,
            accentColor: scheme.secondary,
            title: 'Theme',
            subtitle: 'Customize the app appearance',
            trailing: _CardTrailing(
              label: _themeModeLabel(themeMode),
              showChevron: true,
            ),
            onTap: () async {
              final selectedMode = await _ThemePickerSheet.show(
                context: context,
                currentMode: themeMode,
              );

              if (selectedMode != null) {
                await ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selectedMode);
              }
            },
          ),
          const Gap(20),
          const _SettingsSectionHeader(title: 'Account'),
          const Gap(8),
          _SettingsCardTile(
            icon: AppIcons.logout,
            accentColor: scheme.error,
            title: 'Logout',
            subtitle: 'Disconnect from the current instance',
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

              if (confirmed ?? false) {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
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
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.enabled = true,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor.withValues(alpha: 0.22)),
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
                    const Gap(2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Gap(12),
              DefaultTextStyle.merge(
                style: TextStyle(color: scheme.onSurfaceVariant),
                child: trailing ??
                    Icon(
                      AppIcons.chevron,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
              ),
            ],
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

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet({required this.currentMode});

  final ThemeMode currentMode;

  static Future<ThemeMode?> show({
    required BuildContext context,
    required ThemeMode currentMode,
  }) {
    return showModalBottomSheet<ThemeMode>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ThemePickerSheet(currentMode: currentMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Theme',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(8),
              Text(
                'Choose how Komodo Go looks on this device.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(16),
              _ThemeChoiceTile(
                icon: AppIcons.themeSystem,
                title: 'System',
                subtitle: 'Follow device settings',
                isSelected: currentMode == ThemeMode.system,
                onTap: () => Navigator.of(context).pop(ThemeMode.system),
              ),
              const Gap(10),
              _ThemeChoiceTile(
                icon: AppIcons.themeLight,
                title: 'Light',
                subtitle: 'Always use light mode',
                isSelected: currentMode == ThemeMode.light,
                onTap: () => Navigator.of(context).pop(ThemeMode.light),
              ),
              const Gap(10),
              _ThemeChoiceTile(
                icon: AppIcons.themeDark,
                title: 'Dark',
                subtitle: 'Always use dark mode',
                isSelected: currentMode == ThemeMode.dark,
                onTap: () => Navigator.of(context).pop(ThemeMode.dark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeChoiceTile extends StatelessWidget {
  const _ThemeChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = scheme.secondary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Icon(icon, size: 20, color: accent),
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
                    const Gap(2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.secondaryContainer.withValues(alpha: 0.55)
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(
                  isSelected ? AppIcons.check : AppIcons.chevron,
                  size: 18,
                  color: isSelected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

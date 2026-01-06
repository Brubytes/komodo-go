import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/features/settings/presentation/providers/theme_provider.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _SettingsItem(
            icon: AppIcons.server,
            title: 'Connections',
            subtitle: 'Manage server connections',
            onTap: () => context.push(AppRoutes.connections),
          ),
          _SettingsItem(
            icon: AppIcons.theme,
            title: 'Theme',
            subtitle: _themeModeLabel(themeMode),
            onTap: () => _showThemeDialog(context, ref, themeMode),
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

  Future<void> _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) async {
    final selectedMode = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          _ThemeOption(
            mode: ThemeMode.system,
            label: 'System',
            icon: AppIcons.themeSystem,
            isSelected: currentMode == ThemeMode.system,
          ),
          _ThemeOption(
            mode: ThemeMode.light,
            label: 'Light',
            icon: AppIcons.themeLight,
            isSelected: currentMode == ThemeMode.light,
          ),
          _ThemeOption(
            mode: ThemeMode.dark,
            label: 'Dark',
            icon: AppIcons.themeDark,
            isSelected: currentMode == ThemeMode.dark,
          ),
        ],
      ),
    );

    if (selectedMode != null) {
      await ref.read(themeModeProvider.notifier).setThemeMode(selectedMode);
    }
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(AppIcons.chevron),
      onTap: onTap,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.label,
    required this.icon,
    required this.isSelected,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(mode),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(child: Text(label)),
          if (isSelected)
            Icon(
              AppIcons.check,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

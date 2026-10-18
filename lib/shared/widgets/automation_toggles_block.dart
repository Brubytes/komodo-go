import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';

/// One switch row in [AutomationTogglesBlock].
class AutomationToggle {
  const AutomationToggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
}

/// Shared toggles section for scheduled resources (actions, procedures).
///
/// Common switches are always visible. Webhook settings and rare switches
/// live in collapsible cards that start collapsed.
class AutomationTogglesBlock extends StatelessWidget {
  const AutomationTogglesBlock({
    required this.primary,
    required this.webhookEnabled,
    required this.webhookSecret,
    super.key,
    this.rare = const [],
  });

  /// Always visible switches (e.g. Schedule enabled, Failure alerts).
  final List<AutomationToggle> primary;

  /// Rarely changed switches, shown in a collapsed "More options" card.
  final List<AutomationToggle> rare;

  final AutomationToggle webhookEnabled;
  final TextEditingController webhookSecret;

  Widget _switch(AutomationToggle t) {
    return SwitchListTile.adaptive(
      value: t.value,
      onChanged: t.onChanged,
      title: Text(t.label),
      secondary: Icon(t.icon),
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Toggles',
          icon: AppIcons.settings,
          child: Column(children: primary.map(_switch).toList()),
        ),
        const SizedBox(height: AppSpacing.md),
        DetailSubCard(
          key: const ValueKey('automation_webhook_card'),
          title: 'Webhook',
          icon: AppIcons.network,
          collapsible: true,
          initiallyExpanded: false,
          summary: webhookEnabled.value ? 'Enabled' : 'Disabled',
          child: Column(
            children: [
              _switch(webhookEnabled),
              TextFormField(
                controller: webhookSecret,
                decoration: InputDecoration(
                  labelText: 'Webhook secret',
                  prefixIcon: const Icon(AppIcons.key),
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        if (rare.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          DetailSubCard(
            key: const ValueKey('automation_more_options_card'),
            title: 'More options',
            icon: AppIcons.settings,
            collapsible: true,
            initiallyExpanded: false,
            summary:
                '${rare.where((t) => t.value).length} of ${rare.length} on',
            child: Column(children: rare.map(_switch).toList()),
          ),
        ],
      ],
    );
  }
}

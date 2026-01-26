import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/detail/detail_surface.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';

class AlerterSummaryPanel extends StatelessWidget {
  const AlerterSummaryPanel({
    required this.enabled,
    required this.endpointType,
    required this.alertTypeCount,
    required this.resourceCount,
    required this.exceptCount,
    required this.maintenanceCount,
    super.key,
  });

  final bool enabled;
  final String endpointType;
  final int alertTypeCount;
  final int resourceCount;
  final int exceptCount;
  final int maintenanceCount;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      radius: 20,
      enableGradientInDark: false,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusPill.onOff(
            isOn: enabled,
            onLabel: 'Enabled',
            offLabel: 'Disabled',
          ),
          TextPill(label: endpointType),
          ValuePill(label: 'Types', value: alertTypeCount.toString()),
          ValuePill(label: 'Targets', value: resourceCount.toString()),
          ValuePill(label: 'Except', value: exceptCount.toString()),
          ValuePill(label: 'Maintenance', value: maintenanceCount.toString()),
        ],
      ),
    );
  }
}

class AlerterNameSection extends StatelessWidget {
  const AlerterNameSection({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Name',
          subtitle: 'Displayed name for this alerter.',
        ),
        const Gap(8),
        DetailSurface(
          padding: const EdgeInsets.all(14),
          radius: 16,
          enableGradientInDark: false,
          child: TextFormField(
            controller: controller,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Alerter name',
              prefixIcon: Icon(AppIcons.notifications),
            ),
            validator: (value) {
              final name = (value ?? '').trim();
              if (name.isEmpty) return 'Name is required';
              return null;
            },
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class AlerterEnabledSection extends StatelessWidget {
  const AlerterEnabledSection({
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Enabled',
          subtitle: 'Whether to send alerts to the endpoint.',
        ),
        const Gap(8),
        DetailSurface(
          padding: const EdgeInsets.all(8),
          radius: 16,
          enableGradientInDark: false,
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            title: const Text('Enabled'),
            value: enabled,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class AlerterEndpointSection extends StatelessWidget {
  const AlerterEndpointSection({
    required this.endpointType,
    required this.endpointTypes,
    required this.urlController,
    required this.emailController,
    required this.onTypeChanged,
    super.key,
  });

  final String endpointType;
  final List<String> endpointTypes;
  final TextEditingController urlController;
  final TextEditingController emailController;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Endpoint',
          subtitle: 'Configure the endpoint to send the alert to.',
        ),
        const Gap(8),
        DetailSurface(
          padding: const EdgeInsets.all(14),
          radius: 16,
          enableGradientInDark: false,
          child: Column(
            children: [
              KomodoSelectMenuField<String>(
                key: ValueKey(endpointType),
                value: endpointType,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  prefixIcon: Icon(AppIcons.plug),
                ),
                items: [
                  for (final t in endpointTypes)
                    KomodoSelectMenuItem(value: t, label: t),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  onTypeChanged(value);
                },
              ),
              const Gap(12),
              TextFormField(
                controller: urlController,
                textInputAction: endpointType == 'Ntfy'
                    ? TextInputAction.next
                    : TextInputAction.done,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Endpoint URL',
                  prefixIcon: Icon(AppIcons.network),
                ),
                validator: (v) {
                  final url = (v ?? '').trim();
                  if (url.isEmpty) return 'Endpoint URL is required';
                  return null;
                },
              ),
              if (endpointType == 'Ntfy') ...[
                const Gap(12),
                TextFormField(
                  controller: emailController,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    prefixIcon: Icon(AppIcons.user),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class AlerterAlertTypesSection extends StatelessWidget {
  const AlerterAlertTypesSection({
    required this.selectedLabels,
    required this.onEdit,
    super.key,
  });

  final List<String> selectedLabels;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Alert types',
          subtitle: 'Only send alerts of certain types.',
        ),
        const Gap(8),
        DetailSurface(
          padding: const EdgeInsets.all(14),
          radius: 16,
          enableGradientInDark: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SummaryRow(
                label: 'Selected',
                value: selectedLabels.isEmpty
                    ? 'All'
                    : selectedLabels.length.toString(),
              ),
              const Gap(8),
              SelectionPills(
                items: [for (final label in selectedLabels) PillData(label)],
                emptyLabel: 'All alert types',
              ),
              const Gap(6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(AppIcons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AlerterResourceSection extends StatelessWidget {
  const AlerterResourceSection({
    required this.title,
    required this.subtitle,
    required this.countLabel,
    required this.pills,
    required this.emptyLabel,
    required this.onEdit,
    super.key,
  });

  final String title;
  final String subtitle;
  final String countLabel;
  final List<PillData> pills;
  final String emptyLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        const Gap(8),
        DetailSurface(
          padding: const EdgeInsets.all(14),
          radius: 16,
          enableGradientInDark: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SummaryRow(label: 'Selected', value: countLabel),
              const Gap(8),
              SelectionPills(items: pills, emptyLabel: emptyLabel),
              const Gap(6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(AppIcons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AlerterMaintenanceSection extends StatelessWidget {
  const AlerterMaintenanceSection({
    required this.count,
    required this.pills,
    required this.onEdit,
    super.key,
  });

  final int count;
  final List<PillData> pills;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Maintenance',
          subtitle: 'Temporarily suppress alerts during scheduled maintenance.',
        ),
        const Gap(8),
        DetailSurface(
          padding: const EdgeInsets.all(14),
          radius: 16,
          enableGradientInDark: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SummaryRow(label: 'Windows', value: count.toString()),
              const Gap(8),
              SelectionPills(
                items: pills,
                emptyLabel: 'No maintenance windows',
              ),
              const Gap(6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(AppIcons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Gap(4),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class SummaryRow extends StatelessWidget {
  const SummaryRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class PillData {
  const PillData(this.label, [this.icon]);

  final String label;
  final IconData? icon;
}

class SelectionPills extends StatelessWidget {
  const SelectionPills({
    required this.items,
    required this.emptyLabel,
    super.key,
  });

  final List<PillData> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return TextPill(label: emptyLabel);
    }

    final sorted = List<PillData>.from(items)
      ..sort((a, b) => a.label.compareTo(b.label));
    final visible = sorted.take(6).toList();
    final remaining = sorted.length - visible.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in visible)
          TextPill(label: item.label, icon: item.icon),
        if (remaining > 0) ValuePill(label: 'More', value: '+$remaining'),
      ],
    );
  }
}

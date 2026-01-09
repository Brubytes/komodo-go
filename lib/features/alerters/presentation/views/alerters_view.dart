import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/detail/detail_surface.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';
import 'package:komodo_go/features/alerters/presentation/providers/alerters_provider.dart';

class AlertersView extends ConsumerWidget {
  const AlertersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertersAsync = ref.watch(alertersProvider);
    final actionsState = ref.watch(alerterActionsProvider);

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Alerters',
        icon: AppIcons.notifications,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(alertersProvider.notifier).refresh(),
            child: alertersAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) =>
                      _AlerterTile(item: items[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(alertersProvider),
              ),
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.scrim.withValues(alpha: 0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _AlerterTile extends ConsumerWidget {
  const _AlerterTile({required this.item});

  final AlerterListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final info = item.info;

    return DetailSurface(
      padding: const EdgeInsets.all(14),
      radius: 20,
      enableGradientInDark: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  AppIcons.notifications,
                  color: scheme.secondary,
                  size: 18,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      info.endpointType,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: info.enabled,
                onChanged: (value) async {
                  final ok = await ref
                      .read(alerterActionsProvider.notifier)
                      .setEnabled(id: item.id, enabled: value);

                  if (!context.mounted) return;
                  AppSnackBar.show(
                    context,
                    ok ? 'Alerter updated' : 'Failed to update alerter',
                    tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
                  );
                },
              ),
              PopupMenuButton<_AlerterAction>(
                onSelected: (action) async {
                  switch (action) {
                    case _AlerterAction.editConfig:
                      await _editConfig(context, ref);
                    case _AlerterAction.test:
                      await _test(context, ref);
                    case _AlerterAction.rename:
                      await _rename(context, ref);
                    case _AlerterAction.delete:
                      await _delete(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _AlerterAction.editConfig,
                    child: Row(
                      children: [
                        Icon(AppIcons.edit, color: scheme.primary, size: 18),
                        const Gap(10),
                        const Text('Edit config'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _AlerterAction.test,
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.activity,
                          color: scheme.primary,
                          size: 18,
                        ),
                        const Gap(10),
                        const Text('Test'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _AlerterAction.rename,
                    child: Row(
                      children: [
                        Icon(AppIcons.edit, color: scheme.primary, size: 18),
                        const Gap(10),
                        const Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _AlerterAction.delete,
                    child: Row(
                      children: [
                        Icon(AppIcons.delete, color: scheme.error, size: 18),
                        const Gap(10),
                        const Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.template) const TextPill(label: 'Template'),
              if (info.endpointType.trim().isNotEmpty)
                TextPill(label: info.endpointType),
            ],
          ),
          if (item.tags.isNotEmpty) ...[
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in item.tags.take(6)) TextPill(label: t),
                if (item.tags.length > 6)
                  ValuePill(label: 'More', value: '+${item.tags.length - 6}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editConfig(BuildContext context, WidgetRef ref) async {
    final json = await ref.read(alerterJsonProvider(item.id).future);
    if (!context.mounted) return;

    if (json == null) {
      AppSnackBar.show(
        context,
        'Failed to load alerter config',
        tone: AppSnackBarTone.error,
      );
      return;
    }

    final result = await AlerterConfigEditorSheet.show(
      context,
      alerterName: item.name,
      alerterJson: json,
    );

    if (!context.mounted) return;
    if (result == null) return;

    final ok = await ref
        .read(alerterActionsProvider.notifier)
        .updateConfig(id: item.id, config: result.config);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Alerter updated' : 'Failed to update alerter',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(alerterActionsProvider.notifier)
        .test(idOrName: item.id);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Test triggered' : 'Failed to trigger test',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: item.name);
    final nextName = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename alerter'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (nextName == null || nextName.isEmpty) return;
    final ok = await ref
        .read(alerterActionsProvider.notifier)
        .rename(id: item.id, name: nextName);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Alerter renamed' : 'Failed to rename alerter',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete alerter'),
        content: Text('Delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(alerterActionsProvider.notifier)
        .delete(id: item.id);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Alerter deleted' : 'Failed to delete alerter',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}

enum _AlerterAction { editConfig, test, rename, delete }

class AlerterConfigEditorResult {
  const AlerterConfigEditorResult({required this.config});

  final Map<String, dynamic> config;
}

class AlerterConfigEditorSheet extends StatefulWidget {
  const AlerterConfigEditorSheet({
    required this.alerterName,
    required this.alerterJson,
    super.key,
  });

  final String alerterName;
  final Map<String, dynamic> alerterJson;

  static Future<AlerterConfigEditorResult?> show(
    BuildContext context, {
    required String alerterName,
    required Map<String, dynamic> alerterJson,
  }) {
    return showModalBottomSheet<AlerterConfigEditorResult>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AlerterConfigEditorSheet(
        alerterName: alerterName,
        alerterJson: alerterJson,
      ),
    );
  }

  @override
  State<AlerterConfigEditorSheet> createState() =>
      _AlerterConfigEditorSheetState();
}

class _AlerterConfigEditorSheetState extends State<AlerterConfigEditorSheet> {
  late final Map<String, dynamic> _config;
  late final TextEditingController _urlController;
  late final TextEditingController _emailController;
  late bool _enabled;
  late String _endpointVariant;
  late final Set<String> _alertTypes;
  late List<_ResourceTargetEntry> _resources;
  late List<_ResourceTargetEntry> _exceptResources;
  late List<Map<String, dynamic>> _maintenanceWindows;

  @override
  void initState() {
    super.initState();

    final rawConfig = widget.alerterJson['config'];
    _config = rawConfig is Map<String, dynamic>
        ? rawConfig
        : <String, dynamic>{};

    _enabled = _toBool(_config['enabled']) ?? false;
    final endpoint = _parseEndpointConfig(_config['endpoint']);
    _endpointVariant = endpoint.variant ?? 'Custom';
    _urlController = TextEditingController(text: endpoint.url ?? '');
    _emailController = TextEditingController(text: endpoint.email ?? '');

    _alertTypes = _readStringList(_config['alert_types']).toSet();
    _resources = _parseResourceTargets(_config['resources']);
    _exceptResources = _parseResourceTargets(_config['except_resources']);
    _maintenanceWindows = _parseMaintenanceWindows(
      _config['maintenance_windows'],
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        children: [
          Row(
            children: [
              Text(
                'Edit alerter',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Gap(6),
          Text(
            widget.alerterName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Gap(12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill.onOff(
                isOn: _enabled,
                onLabel: 'Enabled',
                offLabel: 'Disabled',
              ),
              TextPill(label: _endpointVariant),
              ValuePill(label: 'Types', value: _alertTypes.length.toString()),
              ValuePill(label: 'Targets', value: _resources.length.toString()),
              ValuePill(
                label: 'Except',
                value: _exceptResources.length.toString(),
              ),
              ValuePill(
                label: 'Maintenance',
                value: _maintenanceWindows.length.toString(),
              ),
            ],
          ),
          const Gap(14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            subtitle: Text(
              'Whether to send alerts to the endpoint.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const Gap(8),
          const _SectionHeader(
            title: 'Endpoint',
            subtitle: 'Configure the endpoint to send the alert to.',
          ),
          const Gap(8),
          DropdownButtonFormField<String>(
            key: ValueKey(_endpointVariant),
            initialValue: _endpointVariant,
            decoration: const InputDecoration(
              labelText: 'Endpoint',
              prefixIcon: Icon(AppIcons.plug),
            ),
            items: [
              for (final t in _supportedEndpointTypes)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _endpointVariant = value);
            },
          ),
          const Gap(12),
          TextField(
            controller: _urlController,
            textInputAction: _endpointVariant == 'Ntfy'
                ? TextInputAction.next
                : TextInputAction.done,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Endpoint URL',
              prefixIcon: Icon(AppIcons.network),
            ),
          ),
          if (_endpointVariant == 'Ntfy') ...[
            const Gap(12),
            TextField(
              controller: _emailController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(AppIcons.user),
              ),
            ),
          ],
          const Gap(18),
          const _SectionHeader(
            title: 'Alert types',
            subtitle: 'Only send alerts of certain types.',
          ),
          const Gap(8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _knownAlertTypes.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            itemBuilder: (context, index) {
              final type = _knownAlertTypes[index];
              final selected = _alertTypes.contains(type);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected,
                title: Text(_humanizeEnum(type)),
                controlAffinity: ListTileControlAffinity.trailing,
                dense: true,
                onChanged: (v) {
                  setState(() {
                    final next = v ?? false;
                    if (next) {
                      _alertTypes.add(type);
                    } else {
                      _alertTypes.remove(type);
                    }
                  });
                },
              );
            },
          ),
          const Gap(18),
          const _SectionHeader(
            title: 'Resource whitelist',
            subtitle: 'Only send alerts for these resources.',
          ),
          const Gap(8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _editWhitelist,
              child: const Text('Edit resources'),
            ),
          ),
          const Gap(18),
          const _SectionHeader(
            title: 'Resource blacklist',
            subtitle: 'Suppress alerts for these resources.',
          ),
          const Gap(8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _editBlacklist,
              child: const Text('Edit resources'),
            ),
          ),
          const Gap(18),
          const _SectionHeader(
            title: 'Maintenance',
            subtitle:
                'Configure maintenance windows to temporarily suppress alerts during scheduled maintenance.',
          ),
          const Gap(8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _editMaintenance,
              child: const Text('Edit maintenance windows'),
            ),
          ),
          const Gap(18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _onSave, child: const Text('Save')),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  Future<void> _editWhitelist() async {
    final next = await _ResourceTargetsEditorSheet.show(
      context,
      title: 'Resource whitelist',
      subtitle: 'Only send alerts for these resources.',
      initial: _resources,
    );

    if (!mounted) return;
    if (next != null) setState(() => _resources = next);
  }

  Future<void> _editBlacklist() async {
    final next = await _ResourceTargetsEditorSheet.show(
      context,
      title: 'Resource blacklist',
      subtitle: 'Suppress alerts for these resources.',
      initial: _exceptResources,
    );

    if (!mounted) return;
    if (next != null) setState(() => _exceptResources = next);
  }

  Future<void> _editMaintenance() async {
    final next = await MaintenanceWindowsEditorSheet.show(
      context,
      initial: _maintenanceWindows,
    );

    if (!mounted) return;
    if (next != null) setState(() => _maintenanceWindows = next);
  }

  void _onSave() {
    final next = <String, dynamic>{
      'enabled': _enabled,
      'alert_types': _alertTypes.toList()..sort(),
      'resources': _resources.map((e) => e.toJson()).toList(),
      'except_resources': _exceptResources.map((e) => e.toJson()).toList(),
      'maintenance_windows': _maintenanceWindows,
    };

    next['endpoint'] = <String, dynamic>{
      _endpointVariant: <String, dynamic>{
        'url': _urlController.text.trim(),
        if (_endpointVariant == 'Ntfy')
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
      }..removeWhere((k, v) => v == null),
    };

    Navigator.of(context).pop(AlerterConfigEditorResult(config: next));
  }
}

class _EndpointConfig {
  const _EndpointConfig({
    required this.variant,
    required this.url,
    required this.email,
  });

  final String? variant;
  final String? url;
  final String? email;
}

const List<String> _supportedEndpointTypes = <String>[
  'Custom',
  'Slack',
  'Discord',
  'Ntfy',
  'Pushover',
];

_EndpointConfig _parseEndpointConfig(Object? raw) {
  if (raw is Map<String, dynamic>) {
    if (raw.length == 1) {
      final entry = raw.entries.first;
      if (entry.value is Map) {
        final inner = Map<String, dynamic>.from(entry.value as Map);
        return _EndpointConfig(
          variant: entry.key,
          url: inner['url']?.toString(),
          email: inner['email']?.toString(),
        );
      }
    }

    final type = (raw['type'] ?? raw['variant'])?.toString().trim();
    return _EndpointConfig(
      variant: type?.isNotEmpty ?? false ? type : null,
      url: raw['url']?.toString(),
      email: raw['email']?.toString(),
    );
  }

  return const _EndpointConfig(variant: null, url: null, email: null);
}

class _ResourceTargetEntry {
  const _ResourceTargetEntry({required this.variant, required this.value});

  final String variant;
  final String value;

  Map<String, dynamic> toJson() => <String, dynamic>{variant: value};
}

List<_ResourceTargetEntry> _parseResourceTargets(Object? raw) {
  if (raw is! List) return const <_ResourceTargetEntry>[];

  final out = <_ResourceTargetEntry>[];
  for (final e in raw) {
    if (e is Map && e.length == 1) {
      final entry = e.entries.first;
      final k = entry.key?.toString();
      final v = entry.value?.toString();
      if (k != null &&
          v != null &&
          k.trim().isNotEmpty &&
          v.trim().isNotEmpty) {
        out.add(_ResourceTargetEntry(variant: k.trim(), value: v.trim()));
      }
    } else if (e is String && e.trim().isNotEmpty) {
      out.add(_ResourceTargetEntry(variant: 'System', value: e.trim()));
    }
  }
  return out;
}

List<Map<String, dynamic>> _parseMaintenanceWindows(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];

  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is Map) out.add(Map<String, dynamic>.from(e));
  }
  return out;
}

List<String> _readStringList(Object? v) {
  if (v is List) {
    return v
        .map((e) => e?.toString())
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }
  return const <String>[];
}

String _humanizeEnum(String v) {
  final out = v.replaceAllMapped(
    RegExp('([a-z0-9])([A-Z])'),
    (m) => '${m[1]} ${m[2]}',
  );
  return out.replaceAll('_', ' ').trim();
}

const List<String> _knownAlertTypes = <String>[
  'None',
  'Test',
  'ServerUnreachable',
  'ServerCpu',
  'ServerMem',
  'ServerDisk',
  'ServerVersionMismatch',
  'ContainerStateChange',
  'DeploymentImageUpdateAvailable',
  'DeploymentAutoUpdated',
  'StackStateChange',
  'StackImageUpdateAvailable',
  'StackAutoUpdated',
  'AwsBuilderTerminationFailed',
  'ResourceSyncPendingUpdates',
  'BuildFailed',
  'RepoBuildFailed',
  'ProcedureFailed',
  'ActionFailed',
  'ScheduleRun',
  'Custom',
];

bool? _toBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
  }
  return null;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

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

class _ResourceTargetsEditorSheet extends StatefulWidget {
  const _ResourceTargetsEditorSheet({
    required this.title,
    required this.subtitle,
    required this.initial,
  });

  final String title;
  final String subtitle;
  final List<_ResourceTargetEntry> initial;

  static Future<List<_ResourceTargetEntry>?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<_ResourceTargetEntry> initial,
  }) {
    return showModalBottomSheet<List<_ResourceTargetEntry>>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ResourceTargetsEditorSheet(
        title: title,
        subtitle: subtitle,
        initial: initial,
      ),
    );
  }

  @override
  State<_ResourceTargetsEditorSheet> createState() =>
      _ResourceTargetsEditorSheetState();
}

class _ResourceTargetsEditorSheetState
    extends State<_ResourceTargetsEditorSheet> {
  late List<_ResourceTargetEntry> _items;

  @override
  void initState() {
    super.initState();
    _items = List<_ResourceTargetEntry>.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Gap(8),
          Text(
            widget.subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Gap(12),
          if (_items.isEmpty)
            Text(
              'No resources selected',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            )
          else ...[
            for (final (index, item) in _items.indexed) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.variant),
                subtitle: Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: Icon(AppIcons.delete, color: scheme.error),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              ),
            ],
          ],
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _addTarget,
              child: const Text('Add resource'),
            ),
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_items),
              child: const Text('Done'),
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  Future<void> _addTarget() async {
    final result = await showDialog<_ResourceTargetEntry?>(
      context: context,
      builder: (context) => const _ResourceTargetDialog(),
    );

    if (!mounted) return;
    if (result != null) setState(() => _items = [..._items, result]);
  }
}

class _ResourceTargetDialog extends StatefulWidget {
  const _ResourceTargetDialog();

  @override
  State<_ResourceTargetDialog> createState() => _ResourceTargetDialogState();
}

class _ResourceTargetDialogState extends State<_ResourceTargetDialog> {
  static const List<String> _variants = <String>[
    'System',
    'Server',
    'Stack',
    'Deployment',
    'Build',
    'Repo',
    'Procedure',
    'Action',
    'Builder',
    'Alerter',
    'ResourceSync',
  ];

  String _variant = _variants.first;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add resource'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(_variant),
            initialValue: _variant,
            items: [
              for (final v in _variants)
                DropdownMenuItem(value: v, child: Text(v)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _variant = v);
            },
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const Gap(12),
          TextField(
            controller: _valueController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ID or name'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _valueController.text.trim();
            if (value.isEmpty) return;
            Navigator.of(
              context,
            ).pop(_ResourceTargetEntry(variant: _variant, value: value));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class MaintenanceWindowsEditorSheet extends StatefulWidget {
  const MaintenanceWindowsEditorSheet({required this.initial, super.key});

  final List<Map<String, dynamic>> initial;

  static Future<List<Map<String, dynamic>>?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> initial,
  }) {
    return showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => MaintenanceWindowsEditorSheet(initial: initial),
    );
  }

  @override
  State<MaintenanceWindowsEditorSheet> createState() =>
      _MaintenanceWindowsEditorSheetState();
}

class _MaintenanceWindowsEditorSheetState
    extends State<MaintenanceWindowsEditorSheet> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.initial.map(Map<String, dynamic>.from).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Maintenance windows',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Gap(8),
          Text(
            'Temporarily suppress alerts during scheduled maintenance.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Gap(12),
          if (_items.isEmpty)
            Text(
              'No maintenance windows',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            )
          else ...[
            for (final (index, w) in _items.indexed) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text((w['name'] ?? 'Maintenance').toString()),
                subtitle: Text(
                  '${w['schedule_type']?.toString() ?? ''} • ${w['timezone']?.toString() ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: Icon(AppIcons.delete, color: scheme.error),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
                onTap: () => _editWindow(index),
              ),
            ],
          ],
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _addWindow,
              child: const Text('Add maintenance window'),
            ),
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_items),
              child: const Text('Done'),
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  Future<void> _addWindow() async {
    final next = await MaintenanceWindowEditorDialog.show(context);
    if (!mounted) return;
    if (next != null) setState(() => _items = [..._items, next]);
  }

  Future<void> _editWindow(int index) async {
    final current = _items[index];
    final next = await MaintenanceWindowEditorDialog.show(
      context,
      initial: current,
    );
    if (!mounted) return;
    if (next != null) setState(() => _items[index] = next);
  }
}

class MaintenanceWindowEditorDialog extends StatefulWidget {
  const MaintenanceWindowEditorDialog({super.key, this.initial});

  final Map<String, dynamic>? initial;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? initial,
  }) {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => MaintenanceWindowEditorDialog(initial: initial),
    );
  }

  @override
  State<MaintenanceWindowEditorDialog> createState() =>
      _MaintenanceWindowEditorDialogState();
}

class _MaintenanceWindowEditorDialogState
    extends State<MaintenanceWindowEditorDialog> {
  static const List<String> _scheduleTypes = <String>[
    'Daily',
    'Weekly',
    'OneTime',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String _scheduleType = _scheduleTypes.first;
  late final TextEditingController _dayOfWeekController;
  late final TextEditingController _dateController;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  late final TextEditingController _durationController;
  late final TextEditingController _timezoneController;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const <String, dynamic>{};
    _nameController = TextEditingController(text: (i['name'] ?? '').toString());
    _descriptionController = TextEditingController(
      text: (i['description'] ?? '').toString(),
    );
    final st = (i['schedule_type'] ?? '').toString().trim();
    _scheduleType = _scheduleTypes.contains(st) ? st : _scheduleTypes.first;
    _dayOfWeekController = TextEditingController(
      text: (i['day_of_week'] ?? '').toString(),
    );
    _dateController = TextEditingController(text: (i['date'] ?? '').toString());
    _hourController = TextEditingController(
      text: (i['hour'] ?? '0').toString(),
    );
    _minuteController = TextEditingController(
      text: (i['minute'] ?? '0').toString(),
    );
    _durationController = TextEditingController(
      text: (i['duration_minutes'] ?? '60').toString(),
    );
    _timezoneController = TextEditingController(
      text: (i['timezone'] ?? 'UTC').toString(),
    );
    _enabled = _toBool(i['enabled']) ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dayOfWeekController.dispose();
    _dateController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _durationController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? 'Add maintenance window'
            : 'Edit maintenance window',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const Gap(12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const Gap(12),
            DropdownButtonFormField<String>(
              key: ValueKey(_scheduleType),
              initialValue: _scheduleType,
              items: [
                for (final t in _scheduleTypes)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _scheduleType = v);
              },
              decoration: const InputDecoration(labelText: 'Schedule type'),
            ),
            const Gap(12),
            if (_scheduleType == 'Weekly')
              TextField(
                controller: _dayOfWeekController,
                decoration: const InputDecoration(
                  labelText: 'Day of week (e.g. Mon)',
                ),
              ),
            if (_scheduleType == 'OneTime') ...[
              const Gap(12),
              TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                ),
              ),
            ],
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hourController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hour'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: TextField(
                    controller: _minuteController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minute'),
                  ),
                ),
              ],
            ),
            const Gap(12),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
              ),
            ),
            const Gap(12),
            TextField(
              controller: _timezoneController,
              decoration: const InputDecoration(labelText: 'Timezone'),
            ),
            const Gap(8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            Navigator.of(context).pop(<String, dynamic>{
              'name': name,
              'description': _descriptionController.text.trim(),
              'schedule_type': _scheduleType,
              'day_of_week': _scheduleType == 'Weekly'
                  ? _dayOfWeekController.text.trim()
                  : '',
              'date': _scheduleType == 'OneTime'
                  ? _dateController.text.trim()
                  : '',
              'hour': int.tryParse(_hourController.text.trim()) ?? 0,
              'minute': int.tryParse(_minuteController.text.trim()) ?? 0,
              'duration_minutes':
                  int.tryParse(_durationController.text.trim()) ?? 60,
              'timezone': _timezoneController.text.trim().isEmpty
                  ? 'UTC'
                  : _timezoneController.text.trim(),
              'enabled': _enabled,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(48),
        Icon(
          AppIcons.notifications,
          size: 64,
          color: scheme.primary.withValues(alpha: 0.5),
        ),
        const Gap(16),
        Text(
          'No alerters found',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          'Create and configure alerters in the Komodo web interface.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(48),
        Icon(AppIcons.formError, size: 64, color: scheme.error),
        const Gap(16),
        Text(
          'Failed to load alerters',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(24),
        FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

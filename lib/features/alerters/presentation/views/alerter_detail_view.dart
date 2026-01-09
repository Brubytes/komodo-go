import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/detail/detail_surface.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/alerters/presentation/providers/alerters_provider.dart';

class AlerterDetailView extends ConsumerStatefulWidget {
  const AlerterDetailView({required this.alerterIdOrName, super.key});

  final String alerterIdOrName;

  @override
  ConsumerState<AlerterDetailView> createState() => _AlerterDetailViewState();
}

class _AlerterDetailViewState extends ConsumerState<AlerterDetailView> {
  final _formKey = GlobalKey<FormState>();

  String? _loadedMarker;
  String _name = '';

  bool _enabled = false;
  String _endpointType = _endpointTypes.first;
  late final TextEditingController _endpointUrlController;
  late final TextEditingController _endpointEmailController;

  final Set<String> _alertTypes = <String>{};
  List<_ResourceTargetEntry> _resources = <_ResourceTargetEntry>[];
  List<_ResourceTargetEntry> _exceptResources = <_ResourceTargetEntry>[];
  List<Map<String, dynamic>> _maintenanceWindows = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _endpointUrlController = TextEditingController();
    _endpointEmailController = TextEditingController();
  }

  @override
  void dispose() {
    _endpointUrlController.dispose();
    _endpointEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actionsState = ref.watch(alerterActionsProvider);
    final alerterAsync = ref.watch(alerterJsonProvider(widget.alerterIdOrName));

    return Scaffold(
      appBar: MainAppBar(
        title: _name.isEmpty ? 'Alerter' : _name,
        icon: AppIcons.notifications,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: actionsState.isLoading ? null : () => _save(context),
          child: actionsState.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ),
      body: alerterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(alerterJsonProvider(widget.alerterIdOrName)),
        ),
        data: (json) {
          if (json != null) _maybeLoadFromJson(json);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              DetailSurface(
                padding: const EdgeInsets.all(16),
                radius: 20,
                enableGradientInDark: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit alerter',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Gap(6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill.onOff(
                          isOn: _enabled,
                          onLabel: 'Enabled',
                          offLabel: 'Disabled',
                        ),
                        TextPill(label: _endpointType),
                        ValuePill(
                          label: 'Types',
                          value: _alertTypes.length.toString(),
                        ),
                        ValuePill(
                          label: 'Targets',
                          value: _resources.length.toString(),
                        ),
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
                  ],
                ),
              ),
              const Gap(12),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                      context,
                      title: 'Enabled',
                      subtitle: 'Whether to send alerts to the endpoint.',
                    ),
                    const Gap(8),
                    DetailSurface(
                      padding: const EdgeInsets.all(8),
                      radius: 16,
                      enableGradientInDark: false,
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        title: const Text('Enabled'),
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ),
                    const Gap(16),
                    _sectionHeader(
                      context,
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
                          DropdownButtonFormField<String>(
                            key: ValueKey(_endpointType),
                            initialValue: _endpointType,
                            decoration: const InputDecoration(
                              labelText: 'Endpoint',
                              prefixIcon: Icon(AppIcons.plug),
                            ),
                            items: [
                              for (final t in _endpointTypes)
                                DropdownMenuItem(value: t, child: Text(t)),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _endpointType = value);
                            },
                          ),
                          const Gap(12),
                          TextFormField(
                            controller: _endpointUrlController,
                            textInputAction: _endpointType == 'Ntfy'
                                ? TextInputAction.next
                                : TextInputAction.done,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Endpoint URL',
                              prefixIcon: Icon(AppIcons.network),
                            ),
                            validator: (v) {
                              final url = (v ?? '').trim();
                              if (url.isEmpty)
                                return 'Endpoint URL is required';
                              return null;
                            },
                          ),
                          if (_endpointType == 'Ntfy') ...[
                            const Gap(12),
                            TextFormField(
                              controller: _endpointEmailController,
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
                    const Gap(16),
                    _sectionHeader(
                      context,
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
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Select alert types'),
                            subtitle: Text(
                              _alertTypes.isEmpty
                                  ? 'All alert types (no filter)'
                                  : '${_alertTypes.length} selected',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            trailing: Icon(AppIcons.chevron, size: 18),
                            onTap: _pickAlertTypes,
                          ),
                          if (_alertTypes.isNotEmpty) ...[
                            const Gap(4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final t
                                    in (_alertTypes.toList()..sort()).take(6))
                                  TextPill(label: _humanizeEnum(t)),
                                if (_alertTypes.length > 6)
                                  ValuePill(
                                    label: 'More',
                                    value: '+${_alertTypes.length - 6}',
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Gap(16),
                    _sectionHeader(
                      context,
                      title: 'Resource whitelist',
                      subtitle: 'Only send alerts for these resources.',
                    ),
                    const Gap(8),
                    DetailSurface(
                      padding: const EdgeInsets.all(14),
                      radius: 16,
                      enableGradientInDark: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summaryRow(
                            context,
                            label: 'Selected',
                            value: _resources.length.toString(),
                          ),
                          const Gap(10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _editWhitelist,
                              icon: const Icon(AppIcons.edit, size: 18),
                              label: const Text('Edit resources'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    _sectionHeader(
                      context,
                      title: 'Resource blacklist',
                      subtitle: 'Suppress alerts for these resources.',
                    ),
                    const Gap(8),
                    DetailSurface(
                      padding: const EdgeInsets.all(14),
                      radius: 16,
                      enableGradientInDark: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summaryRow(
                            context,
                            label: 'Selected',
                            value: _exceptResources.length.toString(),
                          ),
                          const Gap(10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _editBlacklist,
                              icon: const Icon(AppIcons.edit, size: 18),
                              label: const Text('Edit resources'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    _sectionHeader(
                      context,
                      title: 'Maintenance',
                      subtitle:
                          'Temporarily suppress alerts during scheduled maintenance.',
                    ),
                    const Gap(8),
                    DetailSurface(
                      padding: const EdgeInsets.all(14),
                      radius: 16,
                      enableGradientInDark: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summaryRow(
                            context,
                            label: 'Windows',
                            value: _maintenanceWindows.length.toString(),
                          ),
                          const Gap(10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _editMaintenance,
                              icon: const Icon(AppIcons.maintenance, size: 18),
                              label: const Text('Edit maintenance windows'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _maybeLoadFromJson(Map<String, dynamic> json) {
    final updatedAt = json['updated_at']?.toString() ?? '';
    final marker = '${widget.alerterIdOrName}::$updatedAt';
    if (_loadedMarker == marker) return;
    _loadedMarker = marker;

    _name = (json['name'] ?? '').toString();

    final config = json['config'];
    if (config is! Map<String, dynamic>) return;

    _enabled = _toBool(config['enabled']) ?? false;

    final endpoint = _parseEndpointConfig(config['endpoint']);
    final nextType = endpoint.type ?? _endpointTypes.first;
    _endpointType = _endpointTypes.contains(nextType)
        ? nextType
        : _endpointTypes.first;
    _endpointUrlController.text = endpoint.url ?? '';
    _endpointEmailController.text = endpoint.email ?? '';

    _alertTypes
      ..clear()
      ..addAll(_readStringList(config['alert_types']));

    _resources = _parseResourceTargets(config['resources']);
    _exceptResources = _parseResourceTargets(config['except_resources']);
    _maintenanceWindows = _parseMaintenanceWindows(
      config['maintenance_windows'],
    );

    if (mounted) setState(() {});
  }

  Future<void> _pickAlertTypes() async {
    final selected = await _AlertTypesPickerSheet.show(
      context,
      selected: _alertTypes,
    );
    if (!mounted) return;
    if (selected == null) return;
    setState(() {
      _alertTypes
        ..clear()
        ..addAll(selected);
    });
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
    final next = await _MaintenanceWindowsEditorSheet.show(
      context,
      initial: _maintenanceWindows,
    );
    if (!mounted) return;
    if (next != null) setState(() => _maintenanceWindows = next);
  }

  Future<void> _save(BuildContext context) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final endpointUrl = _endpointUrlController.text.trim();
    final endpointEmail = _endpointEmailController.text.trim();

    final config = <String, dynamic>{
      'enabled': _enabled,
      'endpoint': <String, dynamic>{
        'type': _endpointType,
        'params': <String, dynamic>{
          'url': endpointUrl,
          if (_endpointType == 'Ntfy' && endpointEmail.isNotEmpty)
            'email': endpointEmail,
        },
      },
      'alert_types': _alertTypes.toList()..sort(),
      'resources': _resources.map((e) => e.toJson()).toList(),
      'except_resources': _exceptResources.map((e) => e.toJson()).toList(),
      'maintenance_windows': _maintenanceWindows,
    };

    final ok = await ref
        .read(alerterActionsProvider.notifier)
        .updateConfig(id: widget.alerterIdOrName, config: config);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Alerter updated' : 'Failed to update alerter',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );

    if (ok) {
      ref.invalidate(alerterJsonProvider(widget.alerterIdOrName));
      ref.invalidate(alertersProvider);
    }
  }
}

Widget _sectionHeader(
  BuildContext context, {
  required String title,
  required String subtitle,
}) {
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

Widget _summaryRow(
  BuildContext context, {
  required String label,
  required String value,
}) {
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
          'Failed to load alerter',
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

const List<String> _endpointTypes = <String>[
  'Custom',
  'Slack',
  'Discord',
  'Ntfy',
  'Pushover',
];

class _EndpointConfig {
  const _EndpointConfig({
    required this.type,
    required this.url,
    required this.email,
  });

  final String? type;
  final String? url;
  final String? email;
}

_EndpointConfig _parseEndpointConfig(Object? raw) {
  if (raw is Map<String, dynamic>) {
    // Expected server shape: { type: "Custom", params: { url: "..." } }
    final type = raw['type']?.toString().trim();
    final params = raw['params'];
    if (params is Map) {
      final map = Map<String, dynamic>.from(params);
      return _EndpointConfig(
        type: type,
        url: map['url']?.toString(),
        email: map['email']?.toString(),
      );
    }

    // Alternate shape: { Custom: { url: "..." } }
    if (raw.length == 1) {
      final entry = raw.entries.first;
      if (entry.value is Map) {
        final inner = Map<String, dynamic>.from(entry.value as Map);
        return _EndpointConfig(
          type: entry.key,
          url: inner['url']?.toString(),
          email: inner['email']?.toString(),
        );
      }
    }
  }

  return const _EndpointConfig(type: null, url: null, email: null);
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
    return v.map((e) => e?.toString()).whereType<String>().toList();
  }
  return const <String>[];
}

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

String _humanizeEnum(String v) {
  final out = v.replaceAllMapped(
    RegExp('([a-z0-9])([A-Z])'),
    (m) => '${m[1]} ${m[2]}',
  );
  return out.replaceAll('_', ' ').trim();
}

class _AlertTypesPickerSheet extends StatefulWidget {
  const _AlertTypesPickerSheet({required this.initial});

  final Set<String> initial;

  static Future<Set<String>?> show(
    BuildContext context, {
    required Set<String> selected,
  }) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _AlertTypesPickerSheet(initial: selected),
    );
  }

  @override
  State<_AlertTypesPickerSheet> createState() => _AlertTypesPickerSheetState();
}

class _AlertTypesPickerSheetState extends State<_AlertTypesPickerSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initial);
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              Text(
                'Alert types',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Save'),
              ),
            ],
          ),
          const Gap(8),
          Text(
            'Select the alert types to send. Leave empty to send all.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Gap(12),
          for (final (index, type) in _knownAlertTypes.indexed) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(type),
              title: Text(_humanizeEnum(type)),
              controlAffinity: ListTileControlAffinity.trailing,
              dense: true,
              onChanged: (v) {
                setState(() {
                  final next = v ?? false;
                  if (next) {
                    _selected.add(type);
                  } else {
                    _selected.remove(type);
                  }
                });
              },
            ),
          ],
          const Gap(12),
        ],
      ),
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

class _MaintenanceWindowsEditorSheet extends StatefulWidget {
  const _MaintenanceWindowsEditorSheet({required this.initial});

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
      builder: (context) => _MaintenanceWindowsEditorSheet(initial: initial),
    );
  }

  @override
  State<_MaintenanceWindowsEditorSheet> createState() =>
      _MaintenanceWindowsEditorSheetState();
}

class _MaintenanceWindowsEditorSheetState
    extends State<_MaintenanceWindowsEditorSheet> {
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
    final next = await _MaintenanceWindowEditorDialog.show(context);
    if (!mounted) return;
    if (next != null) setState(() => _items = [..._items, next]);
  }

  Future<void> _editWindow(int index) async {
    final current = _items[index];
    final next = await _MaintenanceWindowEditorDialog.show(
      context,
      initial: current,
    );
    if (!mounted) return;
    if (next != null) setState(() => _items[index] = next);
  }
}

class _MaintenanceWindowEditorDialog extends StatefulWidget {
  const _MaintenanceWindowEditorDialog({this.initial});

  final Map<String, dynamic>? initial;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? initial,
  }) {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => _MaintenanceWindowEditorDialog(initial: initial),
    );
  }

  @override
  State<_MaintenanceWindowEditorDialog> createState() =>
      _MaintenanceWindowEditorDialogState();
}

class _MaintenanceWindowEditorDialogState
    extends State<_MaintenanceWindowEditorDialog> {
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

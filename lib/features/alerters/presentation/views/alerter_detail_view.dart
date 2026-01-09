import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/detail/detail_surface.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';
import 'package:komodo_go/features/alerters/presentation/providers/alerters_provider.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';

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

  bool _initialEnabled = false;
  String? _initialEndpointType;
  String? _initialEndpointUrl;
  String? _initialEndpointEmail;
  Set<String> _initialAlertTypes = <String>{};
  List<_ResourceTargetEntry> _initialResources = <_ResourceTargetEntry>[];
  List<_ResourceTargetEntry> _initialExceptResources = <_ResourceTargetEntry>[];
  List<Map<String, dynamic>> _initialMaintenanceWindows =
      <Map<String, dynamic>>[];

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

    final title = alerterAsync.maybeWhen(
      data: (json) {
        if (json == null) return 'Alerter';
        final name = _alerterNameFromJson(json).trim();
        return name.isEmpty ? 'Alerter' : name;
      },
      orElse: () => _name.isEmpty ? 'Alerter' : _name,
    );

    return Scaffold(
      appBar: MainAppBar(title: title, icon: AppIcons.notifications),
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
          if (json != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _maybeLoadFromJson(json);
            });
          }

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
                          _summaryRow(
                            context,
                            label: 'Selected',
                            value: _alertTypes.isEmpty
                                ? 'All'
                                : _alertTypes.length.toString(),
                          ),
                          const Gap(10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _pickAlertTypes,
                              icon: const Icon(AppIcons.edit, size: 18),
                              label: const Text('Edit alert types'),
                            ),
                          ),
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

    _name = _alerterNameFromJson(json);

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

    _initialEnabled = _enabled;
    _initialEndpointType = _endpointType;
    _initialEndpointUrl = _endpointUrlController.text;
    _initialEndpointEmail = _endpointEmailController.text;
    _initialAlertTypes = Set<String>.from(_alertTypes);
    _initialResources = List<_ResourceTargetEntry>.from(_resources);
    _initialExceptResources = List<_ResourceTargetEntry>.from(_exceptResources);
    _initialMaintenanceWindows = _maintenanceWindows
        .map((window) => Map<String, dynamic>.from(window))
        .toList();

    if (mounted) setState(() {});
  }

  String _alerterNameFromJson(Map<String, dynamic> json) {
    final nested = json['alerter'];
    return switch (nested) {
      Map<String, dynamic>() =>
        (nested['name'] ?? json['name'] ?? '').toString(),
      _ => (json['name'] ?? '').toString(),
    };
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
      modeLabel: 'Whitelist',
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
      modeLabel: 'Blacklist',
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
      if (_enabled != _initialEnabled) 'enabled': _enabled,
      if (_endpointChanged(
        currentType: _endpointType,
        initialType: _initialEndpointType,
        currentUrl: endpointUrl,
        initialUrl: _initialEndpointUrl,
        currentEmail: endpointEmail,
        initialEmail: _initialEndpointEmail,
      ))
        'endpoint': _buildEndpointPayload(
          type: _endpointType,
          url: endpointUrl,
          email: endpointEmail,
        ),
      if (!_setEquals(_alertTypes, _initialAlertTypes))
        'alert_types': _alertTypes.toList()..sort(),
      if (!_resourceSetsEqual(_resources, _initialResources))
        'resources': _resources.map((e) => e.toJson()).toList(),
      if (!_resourceSetsEqual(_exceptResources, _initialExceptResources))
        'except_resources': _exceptResources.map((e) => e.toJson()).toList(),
      if (!_deepEquals(_maintenanceWindows, _initialMaintenanceWindows))
        'maintenance_windows': _maintenanceWindows,
    };

    if (config.isEmpty) {
      AppSnackBar.show(
        context,
        'No changes to save',
        tone: AppSnackBarTone.neutral,
      );
      return;
    }

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

  String get key => '${variant.toLowerCase()}:$value';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': variant,
        'id': value,
      };
}

bool _endpointChanged({
  required String currentType,
  required String? initialType,
  required String currentUrl,
  required String? initialUrl,
  required String currentEmail,
  required String? initialEmail,
}) {
  return currentType != initialType ||
      currentUrl != (initialUrl ?? '') ||
      currentEmail != (initialEmail ?? '');
}

Map<String, dynamic> _buildEndpointPayload({
  required String type,
  required String url,
  required String email,
}) {
  final params = <String, dynamic>{'url': url};
  if (type == 'Ntfy' && email.isNotEmpty) {
    params['email'] = email;
  }
  return <String, dynamic>{type: params};
}

bool _resourceSetsEqual(
  List<_ResourceTargetEntry> a,
  List<_ResourceTargetEntry> b,
) {
  final aKeys = a.map((entry) => entry.key).toSet();
  final bKeys = b.map((entry) => entry.key).toSet();
  return aKeys.length == bKeys.length && aKeys.containsAll(bKeys);
}

bool _setEquals(Set<String> a, Set<String> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!_deepEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

class _ResourceOption {
  const _ResourceOption({
    required this.variant,
    required this.id,
    required this.name,
    required this.icon,
  });

  final String variant;
  final String id;
  final String name;
  final IconData icon;

  String get key => '${variant.toLowerCase()}:$id';

  _ResourceTargetEntry toEntry() =>
      _ResourceTargetEntry(variant: variant, value: id);
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

List<T> _asyncListOrEmpty<T>(AsyncValue<List<T>> async) {
  return async.maybeWhen(data: (value) => value, orElse: () => <T>[]);
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
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initial);
    _searchController = TextEditingController()..addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  void _toggleType(String type, bool next) {
    setState(() {
      if (next) {
        _selected.add(type);
      } else {
        _selected.remove(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _knownAlertTypes
        : _knownAlertTypes
            .where((t) => _humanizeEnum(t).toLowerCase().contains(query))
            .toList();

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
              Text(
                'Alert types',
                style: textTheme.titleLarge?.copyWith(
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
          const Gap(8),
          Text(
            'Select the alert types to send. Leave empty to send all.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Gap(12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search alert types',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(AppIcons.close),
                      onPressed: () => _searchController.clear(),
                    ),
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Text(
                '${_selected.length} selected',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${_knownAlertTypes.length} types',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Gap(12),
          DetailSurface(
            padding: EdgeInsets.zero,
            radius: 16,
            enableGradientInDark: false,
            child: Column(
              children: [
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No alert types match your search.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final (index, type) in filtered.indexed) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _humanizeEnum(type),
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch(
                            value: _selected.contains(type),
                            onChanged: (next) => _toggleType(type, next),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Confirm'),
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }
}

class _ResourceTargetsEditorSheet extends ConsumerStatefulWidget {
  const _ResourceTargetsEditorSheet({
    required this.title,
    required this.subtitle,
    required this.modeLabel,
    required this.initial,
  });

  final String title;
  final String subtitle;
  final String modeLabel;
  final List<_ResourceTargetEntry> initial;

  static Future<List<_ResourceTargetEntry>?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String modeLabel,
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
        modeLabel: modeLabel,
        initial: initial,
      ),
    );
  }

  @override
  ConsumerState<_ResourceTargetsEditorSheet> createState() =>
      _ResourceTargetsEditorSheetState();
}

class _ResourceTargetsEditorSheetState
    extends ConsumerState<_ResourceTargetsEditorSheet> {
  late List<_ResourceTargetEntry> _items;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _items = List<_ResourceTargetEntry>.from(widget.initial);
    _searchController = TextEditingController()..addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final serversAsync = ref.watch(serversProvider);
    final stacksAsync = ref.watch(stacksProvider);
    final deploymentsAsync = ref.watch(deploymentsProvider);
    final buildsAsync = ref.watch(buildsProvider);
    final reposAsync = ref.watch(reposProvider);
    final proceduresAsync = ref.watch(proceduresProvider);
    final actionsAsync = ref.watch(actionsProvider);
    final syncsAsync = ref.watch(syncsProvider);
    final buildersAsync = ref.watch(buildersProvider);
    final alertersAsync = ref.watch(alertersProvider);

    final options = <_ResourceOption>[];

    void addOptions<T>(
      List<T> items, {
      required String variant,
      required IconData icon,
      required String Function(T) getId,
      required String Function(T) getName,
    }) {
      for (final item in items) {
        final id = getId(item).trim();
        final name = getName(item).trim();
        if (id.isEmpty || name.isEmpty) continue;
        options.add(
          _ResourceOption(variant: variant, id: id, name: name, icon: icon),
        );
      }
    }

    addOptions<Server>(
      _asyncListOrEmpty(serversAsync),
      variant: 'Server',
      icon: AppIcons.server,
      getId: (server) => server.id,
      getName: (server) => server.name,
    );
    addOptions<StackListItem>(
      _asyncListOrEmpty(stacksAsync),
      variant: 'Stack',
      icon: AppIcons.stacks,
      getId: (stack) => stack.id,
      getName: (stack) => stack.name,
    );
    addOptions<Deployment>(
      _asyncListOrEmpty(deploymentsAsync),
      variant: 'Deployment',
      icon: AppIcons.deployments,
      getId: (deployment) => deployment.id,
      getName: (deployment) => deployment.name,
    );
    addOptions<BuildListItem>(
      _asyncListOrEmpty(buildsAsync),
      variant: 'Build',
      icon: AppIcons.builds,
      getId: (build) => build.id,
      getName: (build) => build.name,
    );
    addOptions<RepoListItem>(
      _asyncListOrEmpty(reposAsync),
      variant: 'Repo',
      icon: AppIcons.repos,
      getId: (repo) => repo.id,
      getName: (repo) => repo.name,
    );
    addOptions<ProcedureListItem>(
      _asyncListOrEmpty(proceduresAsync),
      variant: 'Procedure',
      icon: AppIcons.procedures,
      getId: (procedure) => procedure.id,
      getName: (procedure) => procedure.name,
    );
    addOptions<ActionListItem>(
      _asyncListOrEmpty(actionsAsync),
      variant: 'Action',
      icon: AppIcons.actions,
      getId: (action) => action.id,
      getName: (action) => action.name,
    );
    addOptions<ResourceSyncListItem>(
      _asyncListOrEmpty(syncsAsync),
      variant: 'ResourceSync',
      icon: AppIcons.syncs,
      getId: (sync) => sync.id,
      getName: (sync) => sync.name,
    );
    addOptions<BuilderListItem>(
      _asyncListOrEmpty(buildersAsync),
      variant: 'Builder',
      icon: AppIcons.factory,
      getId: (builder) => builder.id,
      getName: (builder) => builder.name,
    );
    addOptions<AlerterListItem>(
      _asyncListOrEmpty(alertersAsync),
      variant: 'Alerter',
      icon: AppIcons.notifications,
      getId: (alerter) => alerter.id,
      getName: (alerter) => alerter.name,
    );

    options.sort((a, b) {
      final typeSort = a.variant.compareTo(b.variant);
      if (typeSort != 0) return typeSort;
      return a.name.compareTo(b.name);
    });

    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? options
        : options
              .where(
                (option) =>
                    option.name.toLowerCase().contains(query) ||
                    option.variant.toLowerCase().contains(query),
              )
              .toList();

    final selectedKeys = _items.map((e) => e.key).toSet();
    final optionKeys = options.map((e) => e.key).toSet();
    final unknownItems = _items
        .where((entry) => !optionKeys.contains(entry.key))
        .toList();

    final hasErrors = [
      serversAsync,
      stacksAsync,
      deploymentsAsync,
      buildsAsync,
      reposAsync,
      proceduresAsync,
      actionsAsync,
      syncsAsync,
      buildersAsync,
      alertersAsync,
    ].any((async) => async.hasError);
    final isLoading = [
      serversAsync,
      stacksAsync,
      deploymentsAsync,
      buildsAsync,
      reposAsync,
      proceduresAsync,
      actionsAsync,
      syncsAsync,
      buildersAsync,
      alertersAsync,
    ].any((async) => async.isLoading);

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
                  style: textTheme.titleLarge?.copyWith(
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
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Gap(12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search resources',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(AppIcons.close),
                      onPressed: () => _searchController.clear(),
                    ),
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Text(
                '${_items.length} selected',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${options.length} resources',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (isLoading) ...[
            const Gap(8),
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const Gap(8),
                Text(
                  'Loading resources...',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (hasErrors) ...[
            const Gap(8),
            Text(
              'Some resources could not be loaded.',
              style: textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
          const Gap(12),
          DetailSurface(
            padding: EdgeInsets.zero,
            radius: 16,
            enableGradientInDark: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Resource',
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Target',
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 84,
                        child: Text(
                          widget.modeLabel,
                          textAlign: TextAlign.end,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      query.isEmpty
                          ? 'No resources available.'
                          : 'No resources match your search.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final (index, option) in filtered.indexed) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Icon(
                                  option.icon,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const Gap(6),
                                Flexible(
                                  child: Text(
                                    option.variant,
                                    style: textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              option.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 84,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Switch(
                                value: selectedKeys.contains(option.key),
                                onChanged: (next) =>
                                    _toggleOption(option, next),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          ),
          if (unknownItems.isNotEmpty) ...[
            const Gap(12),
            DetailSurface(
              padding: const EdgeInsets.all(12),
              radius: 16,
              enableGradientInDark: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Other selections',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(6),
                  Text(
                    'These targets are not available in the list above.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(8),
                  for (final (index, item) in unknownItems.indexed) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.variant),
                      subtitle: const Text('Unavailable target'),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: Icon(AppIcons.delete, color: scheme.error),
                        onPressed: () => _removeUnknown(item),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_items),
              child: const Text('Confirm'),
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  void _toggleOption(_ResourceOption option, bool next) {
    final nextItems = List<_ResourceTargetEntry>.from(_items);
    final index = nextItems.indexWhere((item) => item.key == option.key);
    if (next) {
      if (index == -1) nextItems.add(option.toEntry());
    } else {
      if (index != -1) nextItems.removeAt(index);
    }
    setState(() => _items = nextItems);
  }

  void _removeUnknown(_ResourceTargetEntry entry) {
    final nextItems = List<_ResourceTargetEntry>.from(_items)
      ..removeWhere((item) => item.key == entry.key);
    setState(() => _items = nextItems);
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

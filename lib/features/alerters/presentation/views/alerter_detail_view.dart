import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';
import 'package:komodo_go/features/alerters/presentation/providers/alerters_provider.dart';
import 'package:komodo_go/features/alerters/presentation/views/alerter_detail/alert_types_picker_sheet.dart';
import 'package:komodo_go/features/alerters/presentation/views/alerter_detail/alerter_detail_sections.dart';
import 'package:komodo_go/features/alerters/presentation/views/alerter_detail/maintenance_windows_editor_sheet.dart';
import 'package:komodo_go/features/alerters/presentation/views/alerter_detail/resource_targets_editor_sheet.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/shared/resources/resource_helpers.dart';

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
  List<AlerterResourceTarget> _resources = <AlerterResourceTarget>[];
  List<AlerterResourceTarget> _exceptResources = <AlerterResourceTarget>[];
  List<AlerterMaintenanceWindow> _maintenanceWindows =
      <AlerterMaintenanceWindow>[];

  bool _initialEnabled = false;
  AlerterEndpoint? _initialEndpoint;
  Set<String> _initialAlertTypes = <String>{};
  List<AlerterResourceTarget> _initialResources = <AlerterResourceTarget>[];
  List<AlerterResourceTarget> _initialExceptResources =
      <AlerterResourceTarget>[];
  List<AlerterMaintenanceWindow> _initialMaintenanceWindows =
      <AlerterMaintenanceWindow>[];

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
    final actionsState = ref.watch(alerterActionsProvider);
    final alerterAsync = ref.watch(
      alerterDetailProvider(widget.alerterIdOrName),
    );
    final resourceNameLookupMap = resourceNameLookup(
      servers: _asyncListOrEmpty(ref.watch(serversProvider)),
      stacks: _asyncListOrEmpty(ref.watch(stacksProvider)),
      deployments: _asyncListOrEmpty(ref.watch(deploymentsProvider)),
      builds: _asyncListOrEmpty(ref.watch(buildsProvider)),
      repos: _asyncListOrEmpty(ref.watch(reposProvider)),
      procedures: _asyncListOrEmpty(ref.watch(proceduresProvider)),
      actions: _asyncListOrEmpty(ref.watch(actionsProvider)),
      syncs: _asyncListOrEmpty(ref.watch(syncsProvider)),
      builders: _asyncListOrEmpty(ref.watch(buildersProvider)),
      alerters: _asyncListOrEmpty(ref.watch(alertersProvider)),
    );

    final title = alerterAsync.maybeWhen(
      data: (detail) {
        if (detail == null) return 'Alerter';
        final name = detail.name.trim();
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
        error: (error, _) => ErrorStateView(
          title: 'Failed to load alerter',
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(alerterDetailProvider(widget.alerterIdOrName)),
        ),
        data: (detail) {
          if (detail != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _maybeLoadFromDetail(detail);
            });
          }

          final alertTypeLabels = (_alertTypes.toList()..sort())
              .map(_humanizeEnum)
              .toList();
          final resourcePills = _resources
              .map(
                (entry) => PillData(
                  resourceLabel(entry, resourceNameLookupMap),
                  resourceIcon(entry.variant),
                ),
              )
              .toList();
          final exceptPills = _exceptResources
              .map(
                (entry) => PillData(
                  resourceLabel(entry, resourceNameLookupMap),
                  resourceIcon(entry.variant),
                ),
              )
              .toList();
          final maintenancePills = _maintenanceWindows
              .map(
                (window) => PillData(
                  window.name.isEmpty ? 'Maintenance' : window.name,
                  AppIcons.maintenance,
                ),
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              AlerterSummaryPanel(
                enabled: _enabled,
                endpointType: _endpointType,
                alertTypeCount: _alertTypes.length,
                resourceCount: _resources.length,
                exceptCount: _exceptResources.length,
                maintenanceCount: _maintenanceWindows.length,
              ),
              const Gap(12),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AlerterEnabledSection(
                      enabled: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    const Gap(16),
                    AlerterEndpointSection(
                      endpointType: _endpointType,
                      endpointTypes: _endpointTypes,
                      urlController: _endpointUrlController,
                      emailController: _endpointEmailController,
                      onTypeChanged: (value) =>
                          setState(() => _endpointType = value),
                    ),
                    const Gap(16),
                    AlerterAlertTypesSection(
                      selectedLabels: alertTypeLabels,
                      onEdit: _pickAlertTypes,
                    ),
                    const Gap(16),
                    AlerterResourceSection(
                      title: 'Resource whitelist',
                      subtitle: 'Only send alerts for these resources.',
                      countLabel: _resources.length.toString(),
                      pills: resourcePills,
                      emptyLabel: 'No resource filter',
                      onEdit: _editWhitelist,
                    ),
                    const Gap(16),
                    AlerterResourceSection(
                      title: 'Resource blacklist',
                      subtitle: 'Suppress alerts for these resources.',
                      countLabel: _exceptResources.length.toString(),
                      pills: exceptPills,
                      emptyLabel: 'No exclusions',
                      onEdit: _editBlacklist,
                    ),
                    const Gap(16),
                    AlerterMaintenanceSection(
                      count: _maintenanceWindows.length,
                      pills: maintenancePills,
                      onEdit: _editMaintenance,
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

  void _maybeLoadFromDetail(AlerterDetail detail) {
    final marker = '${detail.id}::${detail.updatedAt}';
    if (_loadedMarker == marker) return;
    _loadedMarker = marker;

    _name = detail.name;

    final config = detail.config;

    _enabled = config.enabled;

    final endpoint = config.endpoint;
    final nextType = endpoint?.type ?? _endpointTypes.first;
    _endpointType = _endpointTypes.contains(nextType)
        ? nextType
        : _endpointTypes.first;
    _endpointUrlController.text = endpoint?.url ?? '';
    _endpointEmailController.text = endpoint?.email ?? '';

    _alertTypes
      ..clear()
      ..addAll(config.alertTypes);

    _resources = List<AlerterResourceTarget>.from(config.resources);
    _exceptResources = List<AlerterResourceTarget>.from(config.exceptResources);
    _maintenanceWindows = List<AlerterMaintenanceWindow>.from(
      config.maintenanceWindows,
    );

    _initialEnabled = _enabled;
    _initialEndpoint = AlerterEndpoint(
      type: _endpointType,
      url: _endpointUrlController.text,
      email: _endpointEmailController.text,
    );
    _initialAlertTypes = Set<String>.from(_alertTypes);
    _initialResources = List<AlerterResourceTarget>.from(_resources);
    _initialExceptResources = List<AlerterResourceTarget>.from(
      _exceptResources,
    );
    _initialMaintenanceWindows =
        List<AlerterMaintenanceWindow>.from(_maintenanceWindows);

    if (mounted) setState(() {});
  }

  Future<void> _pickAlertTypes() async {
    final selected = await AlertTypesPickerSheet.show(
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
    final next = await ResourceTargetsEditorSheet.show(
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
    final next = await ResourceTargetsEditorSheet.show(
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
    final next = await MaintenanceWindowsEditorSheet.show(
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
    final currentEndpoint = AlerterEndpoint(
      type: _endpointType,
      url: endpointUrl,
      email: endpointEmail,
    );

    final config = <String, dynamic>{
      if (_enabled != _initialEnabled) 'enabled': _enabled,
      if (_endpointChanged(current: currentEndpoint, initial: _initialEndpoint))
        'endpoint': currentEndpoint.toApiPayload(),
      if (!_setEquals(_alertTypes, _initialAlertTypes))
        'alert_types': _alertTypes.toList()..sort(),
      if (!_resourceSetsEqual(_resources, _initialResources))
        'resources': _resources.map((e) => e.toJson()).toList(),
      if (!_resourceSetsEqual(_exceptResources, _initialExceptResources))
        'except_resources': _exceptResources.map((e) => e.toJson()).toList(),
      if (!_maintenanceEquals(_maintenanceWindows, _initialMaintenanceWindows))
        'maintenance_windows': _maintenanceWindows
            .map((window) => window.toApiMap())
            .toList(),
    };

    if (config.isEmpty) {
      AppSnackBar.show(
        context,
        'No changes to save',
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
      ref.invalidate(alerterDetailProvider(widget.alerterIdOrName));
      ref.invalidate(alertersProvider);
    }
  }
}

const List<String> _endpointTypes = <String>[
  'Custom',
  'Slack',
  'Discord',
  'Ntfy',
  'Pushover',
];

typedef _ResourceTargetEntry = AlerterResourceTarget;

bool _endpointChanged({
  required AlerterEndpoint current,
  required AlerterEndpoint? initial,
}) {
  final initialType = initial?.type ?? '';
  final initialUrl = initial?.url ?? '';
  final initialEmail = initial?.email ?? '';
  return current.type != initialType ||
      (current.url ?? '') != initialUrl ||
      (current.email ?? '') != initialEmail;
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

bool _maintenanceEquals(
  List<AlerterMaintenanceWindow> a,
  List<AlerterMaintenanceWindow> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<T> _asyncListOrEmpty<T>(AsyncValue<List<T>> async) {
  return async.maybeWhen(data: (value) => value, orElse: () => <T>[]);
}

String _humanizeEnum(String v) {
  final out = v.replaceAllMapped(
    RegExp('([a-z0-9])([A-Z])'),
    (m) => '${m[1]} ${m[2]}',
  );
  return out.replaceAll('_', ' ').trim();
}

// resource helpers moved to alerter_detail_helpers.dart

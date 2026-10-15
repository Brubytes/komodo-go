import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/views/server_detail/maintenance_windows_editor_sheet.dart';

class ServerConfigEditorContent extends StatefulWidget {
  const ServerConfigEditorContent({
    required this.initialConfig,
    this.onDirtyChanged,
    super.key,
  });

  final ServerConfig initialConfig;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<ServerConfigEditorContent> createState() =>
      ServerConfigEditorContentState();
}

class ServerConfigEditorContentState extends State<ServerConfigEditorContent> {
  late ServerConfig _initial;

  var _lastDirty = false;
  var _suppressDirtyNotify = false;
  Set<String> _changedKeys = const {};

  late final TextEditingController _address;
  late final TextEditingController _externalAddress;
  late final TextEditingController _region;
  late final TextEditingController _timeoutSeconds;
  late final TextEditingController _passkey;

  late final TextEditingController _cpuWarning;
  late final TextEditingController _cpuCritical;
  late final TextEditingController _memWarning;
  late final TextEditingController _memCritical;
  late final TextEditingController _diskWarning;
  late final TextEditingController _diskCritical;

  final List<TextEditingController> _links = [];
  final List<TextEditingController> _ignoreMounts = [];

  late bool _enabled;
  late bool _statsMonitoring;
  late bool _autoPrune;
  late bool _sendUnreachableAlerts;
  late bool _sendCpuAlerts;
  late bool _sendMemAlerts;
  late bool _sendDiskAlerts;
  late bool _sendVersionMismatchAlerts;

  late List<MaintenanceWindow> _maintenanceWindows;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialConfig;
    _address = TextEditingController(text: _initial.address);
    _externalAddress = TextEditingController(text: _initial.externalAddress);
    _region = TextEditingController(text: _initial.region);
    _timeoutSeconds = TextEditingController(
      text: _initial.timeoutSeconds.toString(),
    );
    _passkey = TextEditingController();

    _cpuWarning = TextEditingController(text: _initial.cpuWarning.toString());
    _cpuCritical = TextEditingController(text: _initial.cpuCritical.toString());
    _memWarning = TextEditingController(text: _initial.memWarning.toString());
    _memCritical = TextEditingController(text: _initial.memCritical.toString());
    _diskWarning = TextEditingController(text: _initial.diskWarning.toString());
    _diskCritical = TextEditingController(
      text: _initial.diskCritical.toString(),
    );

    _enabled = _initial.enabled;
    _statsMonitoring = _initial.statsMonitoring;
    _autoPrune = _initial.autoPrune;
    _sendUnreachableAlerts = _initial.sendUnreachableAlerts;
    _sendCpuAlerts = _initial.sendCpuAlerts;
    _sendMemAlerts = _initial.sendMemAlerts;
    _sendDiskAlerts = _initial.sendDiskAlerts;
    _sendVersionMismatchAlerts = _initial.sendVersionMismatchAlerts;

    _maintenanceWindows = List<MaintenanceWindow>.from(
      _initial.maintenanceWindows,
    );

    _setRowControllers(_links, _initial.links);
    _setRowControllers(_ignoreMounts, _initial.ignoreMounts);

    for (final c in <ChangeNotifier>[
      _address,
      _externalAddress,
      _region,
      _timeoutSeconds,
      _passkey,
      _cpuWarning,
      _cpuCritical,
      _memWarning,
      _memCritical,
      _diskWarning,
      _diskCritical,
    ]) {
      c.addListener(_notifyDirtyIfChanged);
    }
  }

  @override
  void didUpdateWidget(covariant ServerConfigEditorContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialConfig != oldWidget.initialConfig) {
      final dirty = buildPartialConfigParams().isNotEmpty;
      if (!dirty) {
        resetTo(widget.initialConfig);
      }
    }
  }

  @override
  void dispose() {
    for (final c in <ChangeNotifier>[
      _address,
      _externalAddress,
      _region,
      _timeoutSeconds,
      _passkey,
      _cpuWarning,
      _cpuCritical,
      _memWarning,
      _memCritical,
      _diskWarning,
      _diskCritical,
    ]) {
      c.removeListener(_notifyDirtyIfChanged);
    }

    _address.dispose();
    _externalAddress.dispose();
    _region.dispose();
    _timeoutSeconds.dispose();
    _passkey.dispose();
    _cpuWarning.dispose();
    _cpuCritical.dispose();
    _memWarning.dispose();
    _memCritical.dispose();
    _diskWarning.dispose();
    _diskCritical.dispose();

    _disposeRowControllers(_links);
    _disposeRowControllers(_ignoreMounts);
    super.dispose();
  }

  void _disposeRowControllers(List<TextEditingController> controllers) {
    for (final c in controllers) {
      c
        ..removeListener(_notifyDirtyIfChanged)
        ..dispose();
    }
    controllers.clear();
  }

  void _setRowControllers(
    List<TextEditingController> target,
    List<String> values,
  ) {
    _disposeRowControllers(target);

    final cleaned = values.map((e) => e.trim()).where((e) => e.isNotEmpty);
    target.addAll(cleaned.map((e) => TextEditingController(text: e)).toList());
    for (final c in target) {
      c.addListener(_notifyDirtyIfChanged);
    }
  }

  void _addRow(List<TextEditingController> target) {
    setState(() {
      final c = TextEditingController()..addListener(_notifyDirtyIfChanged);
      target.add(c);
    });
    _notifyDirtyIfChanged();
  }

  void _removeRow(List<TextEditingController> target, int index) {
    if (index < 0 || index >= target.length) return;
    setState(() {
      target.removeAt(index)
        ..removeListener(_notifyDirtyIfChanged)
        ..dispose();
    });
    _notifyDirtyIfChanged();
  }

  void resetTo(ServerConfig config) {
    _suppressDirtyNotify = true;

    _setRowControllers(_links, config.links);
    _setRowControllers(_ignoreMounts, config.ignoreMounts);

    setState(() {
      _initial = config;
      _address.text = config.address;
      _externalAddress.text = config.externalAddress;
      _region.text = config.region;
      _timeoutSeconds.text = config.timeoutSeconds.toString();
      _passkey.text = '';

      _cpuWarning.text = config.cpuWarning.toString();
      _cpuCritical.text = config.cpuCritical.toString();
      _memWarning.text = config.memWarning.toString();
      _memCritical.text = config.memCritical.toString();
      _diskWarning.text = config.diskWarning.toString();
      _diskCritical.text = config.diskCritical.toString();

      _enabled = config.enabled;
      _statsMonitoring = config.statsMonitoring;
      _autoPrune = config.autoPrune;
      _sendUnreachableAlerts = config.sendUnreachableAlerts;
      _sendCpuAlerts = config.sendCpuAlerts;
      _sendMemAlerts = config.sendMemAlerts;
      _sendDiskAlerts = config.sendDiskAlerts;
      _sendVersionMismatchAlerts = config.sendVersionMismatchAlerts;

      _maintenanceWindows = List<MaintenanceWindow>.from(
        config.maintenanceWindows,
      );
    });

    _suppressDirtyNotify = false;
    _lastDirty = false;
    _changedKeys = const {};
    widget.onDirtyChanged?.call(false);
  }

  void _notifyDirtyIfChanged() {
    if (_suppressDirtyNotify) return;
    final keys = buildPartialConfigParams().keys.toSet();
    if (keys.length != _changedKeys.length || !keys.containsAll(_changedKeys)) {
      setState(() => _changedKeys = keys);
    }
    final dirty = keys.isNotEmpty;
    if (dirty == _lastDirty) return;
    _lastDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
  }

  bool _modified(List<String> keys) => keys.any(_changedKeys.contains);

  String _countLabel(int count, String singular, String plural) =>
      count == 0 ? 'None' : '$count ${count == 1 ? singular : plural}';

  String _alertsSummary() {
    final on = [
      _sendUnreachableAlerts,
      _sendCpuAlerts,
      _sendMemAlerts,
      _sendDiskAlerts,
      _sendVersionMismatchAlerts,
    ].where((v) => v).length;
    return '$on of 5 on';
  }

  String _thresholdsSummary() {
    String pair(TextEditingController w, TextEditingController c) =>
        '${w.text.trim()}/${c.text.trim()}';
    return 'CPU ${pair(_cpuWarning, _cpuCritical)} · '
        'Mem ${pair(_memWarning, _memCritical)} · '
        'Disk ${pair(_diskWarning, _diskCritical)}';
  }

  Widget _thresholdRow({
    required String label,
    required String unit,
    required TextEditingController warn,
    required TextEditingController crit,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: warn,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'warn',
              suffixText: unit,
              isDense: true,
            ),
          ),
        ),
        const Gap(AppSpacing.md),
        Expanded(
          child: TextFormField(
            controller: crit,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'crit',
              suffixText: unit,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> buildPartialConfigParams() {
    final params = <String, dynamic>{};

    void setIfChanged<T>(String key, T current, T initial) {
      if (current != initial) params[key] = current;
    }

    void setListIfChanged(
      String key,
      List<TextEditingController> controllers,
      List<String> initial,
    ) {
      final cleaned = controllers
          .map((c) => c.text.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final initCleaned = initial
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (!_listEquals(cleaned, initCleaned)) {
        params[key] = cleaned;
      }
    }

    setIfChanged('address', _address.text.trim(), _initial.address);
    setIfChanged(
      'external_address',
      _externalAddress.text.trim(),
      _initial.externalAddress,
    );
    setIfChanged('region', _region.text.trim(), _initial.region);

    final timeout =
        int.tryParse(_timeoutSeconds.text.trim()) ?? _initial.timeoutSeconds;
    setIfChanged('timeout_seconds', timeout, _initial.timeoutSeconds);

    final passkey = _passkey.text.trim();
    if (passkey.isNotEmpty) params['passkey'] = passkey;

    setIfChanged('enabled', _enabled, _initial.enabled);
    setIfChanged(
      'stats_monitoring',
      _statsMonitoring,
      _initial.statsMonitoring,
    );
    setIfChanged('auto_prune', _autoPrune, _initial.autoPrune);

    setListIfChanged('links', _links, _initial.links);
    setListIfChanged('ignore_mounts', _ignoreMounts, _initial.ignoreMounts);

    setIfChanged(
      'send_unreachable_alerts',
      _sendUnreachableAlerts,
      _initial.sendUnreachableAlerts,
    );
    setIfChanged('send_cpu_alerts', _sendCpuAlerts, _initial.sendCpuAlerts);
    setIfChanged('send_mem_alerts', _sendMemAlerts, _initial.sendMemAlerts);
    setIfChanged('send_disk_alerts', _sendDiskAlerts, _initial.sendDiskAlerts);
    setIfChanged(
      'send_version_mismatch_alerts',
      _sendVersionMismatchAlerts,
      _initial.sendVersionMismatchAlerts,
    );

    final cpuWarning =
        double.tryParse(_cpuWarning.text.trim()) ?? _initial.cpuWarning;
    final cpuCritical =
        double.tryParse(_cpuCritical.text.trim()) ?? _initial.cpuCritical;
    final memWarning =
        double.tryParse(_memWarning.text.trim()) ?? _initial.memWarning;
    final memCritical =
        double.tryParse(_memCritical.text.trim()) ?? _initial.memCritical;
    final diskWarning =
        double.tryParse(_diskWarning.text.trim()) ?? _initial.diskWarning;
    final diskCritical =
        double.tryParse(_diskCritical.text.trim()) ?? _initial.diskCritical;

    setIfChanged('cpu_warning', cpuWarning, _initial.cpuWarning);
    setIfChanged('cpu_critical', cpuCritical, _initial.cpuCritical);
    setIfChanged('mem_warning', memWarning, _initial.memWarning);
    setIfChanged('mem_critical', memCritical, _initial.memCritical);
    setIfChanged('disk_warning', diskWarning, _initial.diskWarning);
    setIfChanged('disk_critical', diskCritical, _initial.diskCritical);

    if (!_maintenanceEquals(_maintenanceWindows, _initial.maintenanceWindows)) {
      params['maintenance_windows'] = _maintenanceWindows
          .map((w) => w.toJson())
          .toList();
    }

    params.removeWhere((k, v) => v is String && v.trim().isEmpty);
    return params;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _maintenanceEquals(
    List<MaintenanceWindow> a,
    List<MaintenanceWindow> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _editMaintenanceWindows() async {
    final next = await ServerMaintenanceWindowsEditorSheet.show(
      context,
      initial: _maintenanceWindows,
    );
    if (!mounted || next == null) return;
    setState(() => _maintenanceWindows = List<MaintenanceWindow>.from(next));
    _notifyDirtyIfChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Status',
          icon: AppIcons.ok,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (v) {
                  setState(() => _enabled = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Stats monitoring'),
                value: _statsMonitoring,
                onChanged: (v) {
                  setState(() => _statsMonitoring = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto prune'),
                value: _autoPrune,
                onChanged: (v) {
                  setState(() => _autoPrune = v);
                  _notifyDirtyIfChanged();
                },
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Connection',
          icon: AppIcons.network,
          child: Column(
            children: [
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(AppIcons.network),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _externalAddress,
                decoration: const InputDecoration(
                  labelText: 'External address',
                  prefixIcon: Icon(AppIcons.network),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _region,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  prefixIcon: Icon(AppIcons.tag),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _timeoutSeconds,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Timeout (seconds)',
                  prefixIcon: Icon(AppIcons.clock),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          key: const ValueKey('server_security_card'),
          title: 'Security',
          icon: AppIcons.lock,
          collapsible: true,
          initiallyExpanded: false,
          summary:
              'Passkey ${_passkey.text.trim().isEmpty ? 'unchanged' : 'will change'}'
              ' · ${_countLabel(_ignoreMounts.length, 'ignored mount', 'ignored mounts')}',
          modified: _modified(const ['passkey', 'ignore_mounts']),
          child: Column(
            children: [
              TextFormField(
                controller: _passkey,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Passkey',
                  prefixIcon: Icon(AppIcons.key),
                  helperText: 'Leave blank to keep the current passkey.',
                ),
              ),
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ignore mounts',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Gap(8),
              if (_ignoreMounts.isEmpty)
                Text(
                  'No ignored mounts.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                Column(
                  children: [
                    for (final (index, controller)
                        in _ignoreMounts.indexed) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: 'Mount path',
                                prefixIcon: Icon(AppIcons.hardDrive),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: Icon(AppIcons.close, color: scheme.error),
                            onPressed: () => _removeRow(_ignoreMounts, index),
                          ),
                        ],
                      ),
                      if (index < _ignoreMounts.length - 1) const Gap(8),
                    ],
                  ],
                ),
              const Gap(10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addRow(_ignoreMounts),
                  icon: const Icon(AppIcons.add),
                  label: const Text('Ignore mount'),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          key: const ValueKey('server_links_card'),
          title: 'Links',
          icon: AppIcons.plug,
          collapsible: true,
          initiallyExpanded: false,
          summary: _countLabel(_links.length, 'link', 'links'),
          modified: _modified(const ['links']),
          child: Column(
            children: [
              if (_links.isEmpty)
                Text(
                  'No links configured.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                Column(
                  children: [
                    for (final (index, controller) in _links.indexed) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: 'Link',
                                prefixIcon: Icon(AppIcons.plug),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: Icon(AppIcons.close, color: scheme.error),
                            onPressed: () => _removeRow(_links, index),
                          ),
                        ],
                      ),
                      if (index < _links.length - 1) const Gap(8),
                    ],
                  ],
                ),
              const Gap(10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addRow(_links),
                  icon: const Icon(AppIcons.add),
                  label: const Text('Link'),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          key: const ValueKey('server_alerts_card'),
          title: 'Alerts',
          icon: AppIcons.notifications,
          collapsible: true,
          initiallyExpanded: false,
          summary: _alertsSummary(),
          modified: _modified(const [
            'send_unreachable_alerts',
            'send_cpu_alerts',
            'send_mem_alerts',
            'send_disk_alerts',
            'send_version_mismatch_alerts',
          ]),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unreachable alerts'),
                value: _sendUnreachableAlerts,
                onChanged: (v) {
                  setState(() => _sendUnreachableAlerts = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('CPU alerts'),
                value: _sendCpuAlerts,
                onChanged: (v) {
                  setState(() => _sendCpuAlerts = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Memory alerts'),
                value: _sendMemAlerts,
                onChanged: (v) {
                  setState(() => _sendMemAlerts = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disk alerts'),
                value: _sendDiskAlerts,
                onChanged: (v) {
                  setState(() => _sendDiskAlerts = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Version mismatch alerts'),
                value: _sendVersionMismatchAlerts,
                onChanged: (v) {
                  setState(() => _sendVersionMismatchAlerts = v);
                  _notifyDirtyIfChanged();
                },
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          key: const ValueKey('server_thresholds_card'),
          title: 'Thresholds',
          icon: AppIcons.warning,
          collapsible: true,
          initiallyExpanded: false,
          summary: _thresholdsSummary(),
          modified: _modified(const [
            'cpu_warning',
            'cpu_critical',
            'mem_warning',
            'mem_critical',
            'disk_warning',
            'disk_critical',
          ]),
          child: Column(
            children: [
              _thresholdRow(
                label: 'CPU',
                unit: '%',
                warn: _cpuWarning,
                crit: _cpuCritical,
              ),
              const Gap(AppSpacing.md),
              _thresholdRow(
                label: 'Mem',
                unit: 'GB',
                warn: _memWarning,
                crit: _memCritical,
              ),
              const Gap(AppSpacing.md),
              _thresholdRow(
                label: 'Disk',
                unit: 'GB',
                warn: _diskWarning,
                crit: _diskCritical,
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          key: const ValueKey('server_maintenance_card'),
          title: 'Maintenance',
          icon: AppIcons.maintenance,
          collapsible: true,
          initiallyExpanded: false,
          summary: _countLabel(
            _maintenanceWindows.length,
            'window',
            'windows',
          ),
          modified: _modified(const ['maintenance_windows']),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_maintenanceWindows.isEmpty)
                Text(
                  'No maintenance windows configured.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                Column(
                  children: [
                    for (final (index, window)
                        in _maintenanceWindows.indexed) ...[
                      if (index > 0) const Gap(8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusPill.onOff(
                            isOn: window.enabled,
                            onLabel: 'Enabled',
                            offLabel: 'Disabled',
                            onIcon: AppIcons.ok,
                            offIcon: AppIcons.close,
                          ),
                          ValuePill(
                            label: 'Name',
                            value: window.name.isNotEmpty
                                ? window.name
                                : 'Maintenance',
                          ),
                          ValuePill(
                            label: 'Type',
                            value: _maintenanceTypeLabel(window.scheduleType),
                          ),
                          ValuePill(
                            label: 'At',
                            value:
                                '${window.hour.toString().padLeft(2, '0')}:${window.minute.toString().padLeft(2, '0')}',
                          ),
                          if (window.timezone.isNotEmpty)
                            ValuePill(label: 'TZ', value: window.timezone),
                        ],
                      ),
                    ],
                  ],
                ),
              const Gap(10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: _editMaintenanceWindows,
                  child: const Text('Edit maintenance windows'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _maintenanceTypeLabel(MaintenanceScheduleType type) {
    return switch (type) {
      MaintenanceScheduleType.daily => 'Daily',
      MaintenanceScheduleType.weekly => 'Weekly',
      MaintenanceScheduleType.oneTime => 'One-time',
    };
  }
}

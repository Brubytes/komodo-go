import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/utils/byte_format.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/presentation/views/server_detail/maintenance_windows_editor_sheet.dart';

class ServerHeroPanel extends StatelessWidget {
  const ServerHeroPanel({
    required this.server,
    required this.listServer,
    required this.stats,
    required this.systemInformation,
    required this.ingressBytesPerSecond,
    required this.egressBytesPerSecond,
    super.key,
  });

  final Server? server;
  final Server? listServer;
  final SystemStats? stats;
  final SystemInformation? systemInformation;
  final double? ingressBytesPerSecond;
  final double? egressBytesPerSecond;

  @override
  Widget build(BuildContext context) {
    final server = this.server;
    final listServer = this.listServer;
    final stats = this.stats;
    final systemInformation = this.systemInformation;

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final version = (listServer?.info?.version.isNotEmpty ?? false)
        ? listServer!.info!.version
        : server?.info?.version;
    final cores = systemInformation?.coreCount;
    final load = stats?.loadAverage?.one;
    final memUsed = stats?.memUsedGb;
    final memTotal = stats?.memTotalGb;
    final diskUsed = stats?.diskUsedGb;
    final diskTotal = stats?.diskTotalGb;

    final address = (listServer?.address.isNotEmpty ?? false)
        ? listServer!.address
        : server?.address;
    final description = server?.description;

    final loadPercent = (load != null && (cores ?? 0) > 0)
        ? (load / cores!).clamp(0.0, 1.0)
        : null;
    final memPercent = stats != null
        ? (stats.memPercent / 100).clamp(0.0, 1.0)
        : null;
    final diskPercent = stats != null
        ? (stats.diskPercent / 100).clamp(0.0, 1.0)
        : null;

    return DetailHeroPanel(
      tintColor: scheme.primary,
      metrics: [
        if (address?.isNotEmpty ?? false)
          DetailMetricTileData(
            icon: AppIcons.network,
            label: 'Address',
            value: address!,
            tone: DetailMetricTone.neutral,
          ),
        DetailMetricTileData(
          icon: AppIcons.ok,
          label: 'Version',
          value: (version?.isNotEmpty ?? false) ? version! : '—',
          tone: DetailMetricTone.success,
        ),
        DetailMetricTileData(
          icon: AppIcons.cpu,
          label: 'Cores',
          value: cores != null ? cores.toString() : '—',
          tone: DetailMetricTone.neutral,
        ),
        DetailMetricTileData(
          icon: AppIcons.activity,
          label: 'Load (1m)',
          value: load != null ? load.toStringAsFixed(2) : '—',
          progress: loadPercent,
          tone: DetailMetricTone.primary,
        ),
        DetailMetricTileData(
          icon: AppIcons.memory,
          label: 'Memory',
          value: memUsed != null && memTotal != null && memTotal > 0
              ? '${memUsed.toStringAsFixed(1)} / ${memTotal.toStringAsFixed(1)} GB'
              : '—',
          progress: memPercent,
          tone: DetailMetricTone.secondary,
        ),
        DetailMetricTileData(
          icon: AppIcons.hardDrive,
          label: 'Disk',
          value: diskUsed != null && diskTotal != null && diskTotal > 0
              ? _formatDiskUsage(usedGb: diskUsed, totalGb: diskTotal)
              : '—',
          progress: diskPercent,
          tone: DetailMetricTone.tertiary,
        ),
        DetailMetricTileData(
          icon: AppIcons.wifi,
          label: 'Net (in/out)',
          value: ingressBytesPerSecond != null && egressBytesPerSecond != null
              ? '${formatBytesPerSecond(ingressBytesPerSecond!)} / ${formatBytesPerSecond(egressBytesPerSecond!)}'
              : '—',
          tone: DetailMetricTone.neutral,
        ),
      ],
      footer: (server?.tags.isNotEmpty ?? false) ||
              (description?.isNotEmpty ?? false)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (server?.tags.isNotEmpty ?? false)
                  DetailPillList(
                    items: server!.tags,
                    emptyLabel: 'No tags',
                  ),
                if (description?.isNotEmpty ?? false) ...[
                  if (server?.tags.isNotEmpty ?? false) const Gap(12),
                  Text(
                    'Description',
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(6),
                  Text(
                    description!,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ],
            )
          : null,
    );
  }

  String _formatDiskUsage({required double usedGb, required double totalGb}) {
    final showTb = usedGb >= 1024 || totalGb >= 1024;
    if (!showTb) {
      final used = usedGb.toStringAsFixed(1);
      final total = totalGb.toStringAsFixed(1);
      return '$used/$total GB';
    }

    final usedTb = usedGb / 1024;
    final totalTb = totalGb / 1024;

    String fmt(double v) {
      if (v < 10) return v.toStringAsFixed(2);
      if (v < 100) return v.toStringAsFixed(1);
      return v.toStringAsFixed(0);
    }

    final used = fmt(usedTb);
    final total = fmt(totalTb);
    return '$used/$total TB';
  }
}

class ServerSystemInfoContent extends StatelessWidget {
  const ServerSystemInfoContent({required this.info, super.key});

  final SystemInformation info;

  @override
  Widget build(BuildContext context) {
    final isLockedDown = info.terminalsDisabled || info.containerExecDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Basics',
          icon: AppIcons.server,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.name?.isNotEmpty ?? false)
                ValuePill(label: 'Name', value: info.name!),
              if (info.hostName?.isNotEmpty ?? false)
                ValuePill(label: 'Host', value: info.hostName!),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'OS',
          icon: AppIcons.settings,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.os?.isNotEmpty ?? false)
                ValuePill(label: 'OS', value: info.os!),
              if (info.kernel?.isNotEmpty ?? false)
                ValuePill(label: 'Kernel', value: info.kernel!),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Hardware',
          icon: AppIcons.cpu,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.cpuBrand.isNotEmpty)
                ValuePill(label: 'CPU', value: info.cpuBrand),
              if (info.coreCount != null)
                ValuePill(label: 'Cores', value: info.coreCount.toString()),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Access',
          icon: AppIcons.lock,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill.onOff(
                isOn: !info.terminalsDisabled,
                onLabel: 'Terminal enabled',
                offLabel: 'Terminal disabled',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: !info.containerExecDisabled,
                onLabel: 'Exec enabled',
                offLabel: 'Exec disabled',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill(
                label: isLockedDown ? 'Locked down' : 'Operational',
                icon: isLockedDown ? AppIcons.warning : AppIcons.ok,
                tone: isLockedDown ? PillTone.warning : PillTone.success,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ServerConfigContent extends StatelessWidget {
  const ServerConfigContent({required this.config, super.key});

  final ServerConfig config;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final enabledPill = StatusPill.onOff(
      isOn: config.enabled,
      onLabel: 'Enabled',
      offLabel: 'Disabled',
      onIcon: AppIcons.ok,
      offIcon: AppIcons.close,
      offTone: PillTone.alert,
    );
    final statsMonitoringPill = StatusPill.onOff(
      isOn: config.statsMonitoring,
      onLabel: 'Monitoring on',
      offLabel: 'Monitoring off',
      onIcon: AppIcons.ok,
      offIcon: AppIcons.warning,
      offTone: PillTone.warning,
    );
    final autoPrunePill = StatusPill.onOff(
      isOn: config.autoPrune,
      onLabel: 'Auto prune on',
      offLabel: 'Auto prune off',
      onIcon: AppIcons.ok,
      offIcon: AppIcons.unknown,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            enabledPill,
            statsMonitoringPill,
            autoPrunePill,
            if (config.passkey.isNotEmpty)
              const StatusPill(
                label: 'Passkey set',
                icon: AppIcons.key,
                tone: PillTone.success,
              )
            else
              const StatusPill(
                label: 'No passkey',
                icon: AppIcons.lock,
                tone: PillTone.neutral,
              ),
          ],
        ),
        const Gap(14),
        DetailSubCard(
          title: 'Connection',
          icon: AppIcons.network,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Address',
                value: config.address.isNotEmpty ? config.address : '—',
              ),
              DetailKeyValueRow(
                label: 'External',
                value: config.externalAddress.isNotEmpty
                    ? config.externalAddress
                    : '—',
              ),
              DetailKeyValueRow(
                label: 'Region',
                value: config.region.isNotEmpty ? config.region : '—',
              ),
              DetailKeyValueRow(
                label: 'Timeout',
                value: config.timeoutSeconds > 0
                    ? '${config.timeoutSeconds}s'
                    : '—',
              ),
              if (config.links.isNotEmpty)
                DetailKeyValueRow(
                  label: 'Links',
                  value: config.links.join('\n'),
                ),
              if (config.ignoreMounts.isNotEmpty)
                DetailKeyValueRow(
                  label: 'Ignore mounts',
                  value: config.ignoreMounts.join(', '),
                ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Alerts',
          icon: AppIcons.notifications,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill.onOff(
                isOn: config.sendUnreachableAlerts,
                onLabel: 'Unreachable alerts',
                offLabel: 'Unreachable alerts',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: config.sendCpuAlerts,
                onLabel: 'CPU alerts',
                offLabel: 'CPU alerts',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: config.sendMemAlerts,
                onLabel: 'Memory alerts',
                offLabel: 'Memory alerts',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: config.sendDiskAlerts,
                onLabel: 'Disk alerts',
                offLabel: 'Disk alerts',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: config.sendVersionMismatchAlerts,
                onLabel: 'Version mismatch',
                offLabel: 'Version mismatch',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Thresholds',
          icon: AppIcons.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CPU',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ValuePill(
                    label: 'Warn',
                    value: '${config.cpuWarning.toStringAsFixed(0)}%',
                  ),
                  ValuePill(
                    label: 'Crit',
                    value: '${config.cpuCritical.toStringAsFixed(0)}%',
                  ),
                ],
              ),
              const Gap(10),
              Text(
                'Memory',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ValuePill(
                    label: 'Warn',
                    value: '${config.memWarning.toStringAsFixed(1)} GB',
                  ),
                  ValuePill(
                    label: 'Crit',
                    value: '${config.memCritical.toStringAsFixed(1)} GB',
                  ),
                ],
              ),
              const Gap(10),
              Text(
                'Disk',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ValuePill(
                    label: 'Warn',
                    value: '${config.diskWarning.toStringAsFixed(1)} GB',
                  ),
                  ValuePill(
                    label: 'Crit',
                    value: '${config.diskCritical.toStringAsFixed(1)} GB',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (config.maintenanceWindows.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Maintenance',
            icon: AppIcons.maintenance,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final window in config.maintenanceWindows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill.onOff(
                          isOn: window.enabled,
                          onLabel: 'Enabled',
                          offLabel: 'Disabled',
                          onIcon: AppIcons.ok,
                          offIcon: AppIcons.close,
                        ),
                        ValuePill(label: 'Name', value: window.name),
                        ValuePill(
                          label: 'Type',
                          value: window.scheduleType.name,
                        ),
                        ValuePill(
                          label: 'At',
                          value:
                              '${window.hour.toString().padLeft(2, '0')}:${window.minute.toString().padLeft(2, '0')}',
                        ),
                        ValuePill(label: 'TZ', value: window.timezone),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

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
    _diskCritical = TextEditingController(text: _initial.diskCritical.toString());

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
    widget.onDirtyChanged?.call(false);
  }

  void _notifyDirtyIfChanged() {
    if (_suppressDirtyNotify) return;
    final dirty = buildPartialConfigParams().isNotEmpty;
    if (dirty == _lastDirty) return;
    _lastDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
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
      params['maintenance_windows'] =
          _maintenanceWindows.map((w) => w.toJson()).toList();
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
          title: 'Security',
          icon: AppIcons.lock,
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
                    for (final (index, controller) in _ignoreMounts.indexed) ...[
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
          title: 'Links',
          icon: AppIcons.plug,
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
          title: 'Alerts',
          icon: AppIcons.notifications,
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
          title: 'Thresholds',
          icon: AppIcons.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CPU (%)',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cpuWarning,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Warn',
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: TextFormField(
                      controller: _cpuCritical,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Crit',
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Text(
                'Memory (GB)',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _memWarning,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Warn',
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: TextFormField(
                      controller: _memCritical,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Crit',
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Text(
                'Disk (GB)',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _diskWarning,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Warn',
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: TextFormField(
                      controller: _diskCritical,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Crit',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Maintenance',
          icon: AppIcons.maintenance,
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

class ServerMessageCard extends StatelessWidget {
  const ServerMessageCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      child: Text(message),
    );
  }
}

class ServerLoadingCard extends StatelessWidget {
  const ServerLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonCard();
  }
}

class StatsSample {
  const StatsSample({
    required this.ts,
    required this.cpuPercent,
    required this.memPercent,
    required this.diskPercent,
    required this.ingressBytesPerSecond,
    required this.egressBytesPerSecond,
  });

  final DateTime ts;
  final double cpuPercent;
  final double memPercent;
  final double diskPercent;
  final double ingressBytesPerSecond;
  final double egressBytesPerSecond;
}

class StatsHistoryContent extends StatefulWidget {
  const StatsHistoryContent({
    required this.history,
    required this.latestStats,
    super.key,
  });

  final List<StatsSample> history;
  final SystemStats? latestStats;

  @override
  State<StatsHistoryContent> createState() => _StatsHistoryContentState();
}

class _StatsHistoryContentState extends State<StatsHistoryContent> {
  bool _useFixedPercentScale = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latestStats = widget.latestStats;

    final uiRefreshSeconds = _estimateUiRefreshSeconds(widget.history);
    final cpu = latestStats?.cpuPercent;
    final mem = latestStats?.memPercent;
    final disk = latestStats?.diskPercent;

    const windowSamples = 60; // ~2.5 min @ 2.5s refresh
    final visibleHistory = widget.history.length > windowSamples
        ? widget.history.sublist(widget.history.length - windowSamples)
        : widget.history;

    final cpuSeries = visibleHistory
        .map((e) => e.cpuPercent)
        .toList(growable: false);
    final memSeries = visibleHistory
        .map((e) => e.memPercent)
        .toList(growable: false);
    final diskSeries = visibleHistory
        .map((e) => e.diskPercent)
        .toList(growable: false);
    final ingressSeries = visibleHistory
        .map((e) => e.ingressBytesPerSecond)
        .toList(growable: false);
    final egressSeries = visibleHistory
        .map((e) => e.egressBytesPerSecond)
        .toList(growable: false);

    final textTheme = Theme.of(context).textTheme;
    final percentMin = _useFixedPercentScale ? 0.0 : null;
    final percentMax = _useFixedPercentScale ? 100.0 : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ValuePill(
              label: 'CPU',
              value: cpu != null ? '${cpu.toStringAsFixed(0)}%' : '—',
            ),
            ValuePill(
              label: 'Mem',
              value: mem != null ? '${mem.toStringAsFixed(0)}%' : '—',
            ),
            ValuePill(
              label: 'Disk',
              value: disk != null ? '${disk.toStringAsFixed(0)}%' : '—',
            ),
            if (latestStats?.loadAverage?.one != null)
              ValuePill(
                label: 'Load',
                value: latestStats!.loadAverage!.one.toStringAsFixed(2),
              ),
          ],
        ),
        const Gap(8),
        Row(
          children: [
            Text(
              'Scale',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              _useFixedPercentScale ? '0-100%' : 'Auto',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            Switch.adaptive(
              value: _useFixedPercentScale,
              onChanged: (value) {
                setState(() => _useFixedPercentScale = value);
              },
            ),
          ],
        ),
        const Gap(12),
        if (cpuSeries.isNotEmpty)
          DetailHistoryRow(
            label: 'CPU',
            value: cpu != null ? '${cpu.toStringAsFixed(0)}%' : '—',
            child: SparklineChart(
              values: cpuSeries,
              color: scheme.primary,
              capMinY: percentMin,
              capMaxY: percentMax,
            ),
          )
        else
          Text(
            'Not enough data to chart CPU usage',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const Gap(12),
        if (memSeries.isNotEmpty)
          DetailHistoryRow(
            label: 'Memory',
            value: mem != null ? '${mem.toStringAsFixed(0)}%' : '—',
            child: SparklineChart(
              values: memSeries,
              color: scheme.secondary,
              capMinY: percentMin,
              capMaxY: percentMax,
            ),
          )
        else
          Text(
            'Not enough data to chart memory usage',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const Gap(12),
        if (diskSeries.isNotEmpty)
          DetailHistoryRow(
            label: 'Disk',
            value: disk != null ? '${disk.toStringAsFixed(0)}%' : '—',
            child: SparklineChart(
              values: diskSeries,
              color: scheme.tertiary,
              capMinY: percentMin,
              capMaxY: percentMax,
            ),
          )
        else
          Text(
            'Not enough data to chart disk usage',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const Gap(12),
        DetailHistoryRow(
          label: 'In / Out',
          value: widget.history.isNotEmpty
              ? '${formatBytesPerSecond(widget.history.last.ingressBytesPerSecond)} / ${formatBytesPerSecond(widget.history.last.egressBytesPerSecond)}'
              : '—',
          child: DualSparklineChart(
            aValues: ingressSeries,
            bValues: egressSeries,
            aColor: scheme.primary,
            bColor: scheme.secondary,
          ),
        ),
        const Gap(12),
        DetailKeyValueRow(
          label: 'UI refresh',
          value: uiRefreshSeconds != null
              ? '~${uiRefreshSeconds.toStringAsFixed(1)} s'
              : '—',
        ),
        if (latestStats?.pollingRate?.isNotEmpty ?? false)
          DetailKeyValueRow(
            label: 'Server polling',
            value: latestStats!.pollingRate!,
            bottomPadding: 0,
          ),
      ],
    );
  }

  double? _estimateUiRefreshSeconds(List<StatsSample> history) {
    if (history.length < 2) return null;

    final startIndex = (history.length - 6).clamp(0, history.length - 2);
    var sumSeconds = 0.0;
    var count = 0;

    for (var i = startIndex; i < history.length - 1; i++) {
      final dtMs = history[i + 1].ts.difference(history[i].ts).inMilliseconds;
      if (dtMs <= 0) continue;
      sumSeconds += dtMs / 1000.0;
      count++;
    }

    if (count == 0) return null;
    return sumSeconds / count;
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_code_block.dart';
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
    final shortId = item.id.length <= 6 ? item.id : item.id.substring(0, 6);

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
                    case _AlerterAction.viewJson:
                      await _showJson(context, ref, item.id);
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
                    value: _AlerterAction.viewJson,
                    child: Row(
                      children: [
                        Icon(AppIcons.package, color: scheme.primary, size: 18),
                        const Gap(10),
                        const Text('View JSON'),
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
              ValuePill(label: 'ID', value: shortId),
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

  Future<void> _showJson(BuildContext context, WidgetRef ref, String id) async {
    final jsonAsync = await ref.read(alerterJsonProvider(id).future);
    if (!context.mounted) return;

    final pretty = jsonAsync == null
        ? '{}'
        : const JsonEncoder.withIndent('  ').convert(jsonAsync);

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Alerter JSON',
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
            const Gap(12),
            DetailCodeBlock(code: pretty, maxHeight: 520),
            const Gap(12),
          ],
        ),
      ),
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

enum _AlerterAction { editConfig, test, viewJson, rename, delete }

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
  late final _EndpointShape _endpoint;

  late final TextEditingController _urlController;
  late final TextEditingController _emailController;
  late bool _enabled;
  late final Set<String> _alertTypes;

  @override
  void initState() {
    super.initState();

    final rawConfig = widget.alerterJson['config'];
    _config = rawConfig is Map<String, dynamic>
        ? rawConfig
        : <String, dynamic>{};

    _enabled = _toBool(_config['enabled']) ?? false;
    _endpoint = _parseEndpoint(_config['endpoint']);
    _urlController = TextEditingController(text: _endpoint.url ?? '');
    _emailController = TextEditingController(text: _endpoint.email ?? '');

    _alertTypes = _readStringList(_config['alert_types']).toSet();
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

    final resourcesCount = _readList(_config['resources']).length;
    final exceptResourcesCount = _readList(_config['except_resources']).length;
    final maintenanceCount = _readList(_config['maintenance_windows']).length;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.alerterName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
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
              if (_endpoint.variant != null)
                TextPill(label: _endpoint.variant!),
              ValuePill(label: 'Types', value: _alertTypes.length.toString()),
              ValuePill(label: 'Targets', value: resourcesCount.toString()),
              ValuePill(
                label: 'Except',
                value: exceptResourcesCount.toString(),
              ),
              ValuePill(
                label: 'Maintenance',
                value: maintenanceCount.toString(),
              ),
            ],
          ),
          const Gap(14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const Gap(8),
          if (_endpoint.variant == null) ...[
            Text(
              'Endpoint format not supported yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ] else ...[
            TextField(
              controller: _urlController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Endpoint URL',
                prefixIcon: Icon(AppIcons.network),
              ),
            ),
            if (_endpoint.variant == 'Ntfy') ...[
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
          ],
          const Gap(14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Alert types',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in _knownAlertTypes)
                FilterChip(
                  selected: _alertTypes.contains(type),
                  label: Text(_humanizeEnum(type)),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _alertTypes.add(type);
                      } else {
                        _alertTypes.remove(type);
                      }
                    });
                  },
                ),
            ],
          ),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _onSave, child: const Text('Save')),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  void _onSave() {
    final next = <String, dynamic>{
      'enabled': _enabled,
      'alert_types': _alertTypes.toList()..sort(),
    };

    if (_endpoint.variant != null) {
      next['endpoint'] = _endpoint.updated(
        url: _urlController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      );
    }

    Navigator.of(context).pop(AlerterConfigEditorResult(config: next));
  }
}

enum _EndpointEncoding { externalTagged, map }

class _EndpointShape {
  const _EndpointShape({
    required this.raw,
    required this.variant,
    required this.url,
    required this.email,
    required this.encoding,
  });

  final Object? raw;
  final String? variant;
  final String? url;
  final String? email;
  final _EndpointEncoding encoding;

  Object updated({required String url, String? email}) {
    final v = variant;
    if (v == null) return raw ?? <String, dynamic>{};

    return switch (encoding) {
      _EndpointEncoding.externalTagged => <String, dynamic>{
        v: <String, dynamic>{
          ..._endpointInnerMap(raw),
          'url': url,
          if (v == 'Ntfy') 'email': email,
        }..removeWhere((k, v) => v == null),
      },
      _EndpointEncoding.map => <String, dynamic>{
        ...(_endpointRawMap(raw)),
        'url': url,
        if (v == 'Ntfy') 'email': email,
      }..removeWhere((k, v) => v == null),
    };
  }
}

_EndpointShape _parseEndpoint(Object? raw) {
  if (raw is Map<String, dynamic>) {
    if (raw.length == 1) {
      final entry = raw.entries.first;
      if (entry.value is Map) {
        final inner = Map<String, dynamic>.from(entry.value as Map);
        return _EndpointShape(
          raw: raw,
          variant: entry.key,
          url: inner['url']?.toString(),
          email: inner['email']?.toString(),
          encoding: _EndpointEncoding.externalTagged,
        );
      }
    }

    final type = (raw['type'] ?? raw['variant'])?.toString().trim();
    return _EndpointShape(
      raw: raw,
      variant: type?.isNotEmpty ?? false ? type : null,
      url: raw['url']?.toString(),
      email: raw['email']?.toString(),
      encoding: _EndpointEncoding.map,
    );
  }

  return const _EndpointShape(
    raw: null,
    variant: null,
    url: null,
    email: null,
    encoding: _EndpointEncoding.map,
  );
}

Map<String, dynamic> _endpointRawMap(Object? raw) {
  return raw is Map<String, dynamic>
      ? Map<String, dynamic>.from(raw)
      : <String, dynamic>{};
}

Map<String, dynamic> _endpointInnerMap(Object? raw) {
  if (raw is Map<String, dynamic> && raw.length == 1) {
    final entry = raw.entries.first;
    if (entry.value is Map) {
      return Map<String, dynamic>.from(entry.value as Map);
    }
  }
  return <String, dynamic>{};
}

List<Object?> _readList(Object? v) => v is List ? v : const <Object?>[];

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

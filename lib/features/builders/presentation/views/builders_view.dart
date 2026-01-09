import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/detail/detail_surface.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';

class BuildersView extends ConsumerWidget {
  const BuildersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildersAsync = ref.watch(buildersProvider);
    final actionsState = ref.watch(builderActionsProvider);

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Builders',
        icon: AppIcons.factory,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(buildersProvider.notifier).refresh(),
            child: buildersAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) =>
                      _BuilderTile(item: items[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(buildersProvider),
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

class _BuilderTile extends ConsumerWidget {
  const _BuilderTile({required this.item});

  final BuilderListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final info = item.info;
    final instanceType = info.instanceType?.trim();
    final showInstanceType =
        instanceType != null &&
        instanceType.isNotEmpty &&
        !_looksLikeSensitiveId(instanceType);

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
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(AppIcons.factory, color: scheme.primary, size: 18),
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
                      info.instanceType?.trim().isNotEmpty ?? false
                          ? (showInstanceType
                                ? '${info.builderType} • $instanceType'
                                : info.builderType)
                          : info.builderType,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_BuilderAction>(
                onSelected: (action) async {
                  switch (action) {
                    case _BuilderAction.editConfig:
                      await _editConfig(context, ref);
                    case _BuilderAction.rename:
                      await _rename(context, ref);
                    case _BuilderAction.delete:
                      await _delete(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _BuilderAction.editConfig,
                    child: Row(
                      children: [
                        Icon(AppIcons.edit, color: scheme.primary, size: 18),
                        const Gap(10),
                        const Text('Edit config'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _BuilderAction.rename,
                    child: Row(
                      children: [
                        Icon(AppIcons.edit, color: scheme.primary, size: 18),
                        const Gap(10),
                        const Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _BuilderAction.delete,
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
              if (info.builderType.trim().isNotEmpty)
                TextPill(label: info.builderType),
              if (showInstanceType)
                ValuePill(label: 'Instance', value: instanceType),
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
    final json = await ref.read(builderJsonProvider(item.id).future);
    if (!context.mounted) return;

    if (json == null) {
      AppSnackBar.show(
        context,
        'Failed to load builder config',
        tone: AppSnackBarTone.error,
      );
      return;
    }

    final result = await BuilderConfigEditorSheet.show(
      context,
      builderName: item.name,
      builderType: item.info.builderType,
      builderJson: json,
    );

    if (!context.mounted) return;
    if (result == null) return;

    final ok = await ref
        .read(builderActionsProvider.notifier)
        .updateConfig(id: item.id, config: result.config);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Builder updated' : 'Failed to update builder',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: item.name);
    final nextName = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename builder'),
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
        .read(builderActionsProvider.notifier)
        .rename(id: item.id, name: nextName);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Builder renamed' : 'Failed to rename builder',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete builder'),
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
        .read(builderActionsProvider.notifier)
        .delete(id: item.id);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Builder deleted' : 'Failed to delete builder',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  bool _looksLikeSensitiveId(String value) {
    final v = value.trim();
    if (v.length < 12) return false;

    // UUID
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    );
    if (uuid.hasMatch(v)) return true;

    // Long hex string (typical for internal IDs)
    final hex = RegExp(r'^[0-9a-fA-F]+$');
    if (hex.hasMatch(v) && v.length >= 16) return true;

    return false;
  }
}

enum _BuilderAction { editConfig, rename, delete }

class BuilderConfigEditorResult {
  const BuilderConfigEditorResult({required this.config});

  final Map<String, dynamic> config;
}

class BuilderConfigEditorSheet extends StatefulWidget {
  const BuilderConfigEditorSheet({
    required this.builderName,
    required this.builderType,
    required this.builderJson,
    super.key,
  });

  final String builderName;
  final String builderType;
  final Map<String, dynamic> builderJson;

  static Future<BuilderConfigEditorResult?> show(
    BuildContext context, {
    required String builderName,
    required String builderType,
    required Map<String, dynamic> builderJson,
  }) {
    return showModalBottomSheet<BuilderConfigEditorResult>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => BuilderConfigEditorSheet(
        builderName: builderName,
        builderType: builderType,
        builderJson: builderJson,
      ),
    );
  }

  @override
  State<BuilderConfigEditorSheet> createState() =>
      _BuilderConfigEditorSheetState();
}

class _BuilderConfigEditorSheetState extends State<BuilderConfigEditorSheet> {
  late final _BuilderConfigShape _shape;

  late final TextEditingController _addressController;
  late final TextEditingController _passkeyController;
  late final TextEditingController _serverIdController;

  late final TextEditingController _awsRegionController;
  late final TextEditingController _awsInstanceTypeController;
  late final TextEditingController _awsVolumeGbController;
  late final TextEditingController _awsPortController;
  bool _awsUseHttps = false;
  bool _awsAssignPublicIp = false;
  bool _awsUsePublicIp = false;

  bool _showPasskey = false;

  @override
  void initState() {
    super.initState();

    _shape = _parseBuilderConfig(
      widget.builderJson['config'],
      fallbackType: widget.builderType,
    );

    final inner = _shape.inner;
    _addressController = TextEditingController(
      text: (inner['address'] ?? '').toString(),
    );
    _passkeyController = TextEditingController(
      text: (inner['passkey'] ?? '').toString(),
    );
    _serverIdController = TextEditingController(
      text: (inner['server_id'] ?? '').toString(),
    );

    _awsRegionController = TextEditingController(
      text: (inner['region'] ?? '').toString(),
    );
    _awsInstanceTypeController = TextEditingController(
      text: (inner['instance_type'] ?? '').toString(),
    );
    _awsVolumeGbController = TextEditingController(
      text: (inner['volume_gb'] ?? '').toString(),
    );
    _awsPortController = TextEditingController(
      text: (inner['port'] ?? '').toString(),
    );

    _awsUseHttps = _toBool(inner['use_https']) ?? false;
    _awsAssignPublicIp = _toBool(inner['assign_public_ip']) ?? false;
    _awsUsePublicIp = _toBool(inner['use_public_ip']) ?? false;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _passkeyController.dispose();
    _serverIdController.dispose();
    _awsRegionController.dispose();
    _awsInstanceTypeController.dispose();
    _awsVolumeGbController.dispose();
    _awsPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.builderJson['config'];
    final description = (widget.builderJson['description'] ?? '')
        .toString()
        .trim();
    final template = _toBool(widget.builderJson['template']) ?? false;

    final scheme = Theme.of(context).colorScheme;

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
                'Edit builder',
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
              widget.builderName,
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
              TextPill(label: _shape.variant),
              if (template) const TextPill(label: 'Template'),
              if (description.isNotEmpty)
                const TextPill(label: 'Has description'),
            ],
          ),
          const Gap(14),
          if (config is! Map<String, dynamic>)
            Text(
              'Builder config format not supported yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            _buildConfigForm(context),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: config is Map<String, dynamic> ? _onSave : null,
              child: const Text('Save'),
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  Widget _buildConfigForm(BuildContext context) {
    return switch (_shape.variant) {
      'Url' => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(AppIcons.network),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _passkeyController,
            textInputAction: TextInputAction.done,
            obscureText: !_showPasskey,
            decoration: InputDecoration(
              labelText: 'Passkey',
              prefixIcon: const Icon(AppIcons.lock),
              suffixIcon: IconButton(
                tooltip: _showPasskey ? 'Hide' : 'Show',
                icon: Icon(
                  _showPasskey ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _showPasskey = !_showPasskey),
              ),
            ),
          ),
        ],
      ),
      'Server' => TextField(
        controller: _serverIdController,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Server ID',
          prefixIcon: Icon(AppIcons.server),
        ),
      ),
      'Aws' => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _awsRegionController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Region',
              prefixIcon: Icon(Icons.public),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _awsInstanceTypeController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Instance type',
              prefixIcon: Icon(AppIcons.factory),
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _awsVolumeGbController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Volume (GB)',
                    prefixIcon: Icon(Icons.storage_outlined),
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: TextField(
                  controller: _awsPortController,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    prefixIcon: Icon(Icons.settings_ethernet),
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use HTTPS'),
            value: _awsUseHttps,
            onChanged: (v) => setState(() => _awsUseHttps = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Assign public IP'),
            value: _awsAssignPublicIp,
            onChanged: (v) => setState(() => _awsAssignPublicIp = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use public IP'),
            value: _awsUsePublicIp,
            onChanged: (v) => setState(() => _awsUsePublicIp = v),
          ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _onSave() {
    final next = _shape.updated((inner) {
      return switch (_shape.variant) {
        'Url' => <String, dynamic>{
          ...inner,
          'address': _addressController.text.trim(),
          'passkey': _passkeyController.text,
        },
        'Server' => <String, dynamic>{
          ...inner,
          'server_id': _serverIdController.text.trim(),
        },
        'Aws' => <String, dynamic>{
          ...inner,
          'region': _awsRegionController.text.trim(),
          'instance_type': _awsInstanceTypeController.text.trim(),
          'volume_gb': int.tryParse(_awsVolumeGbController.text.trim()),
          'port': int.tryParse(_awsPortController.text.trim()),
          'use_https': _awsUseHttps,
          'assign_public_ip': _awsAssignPublicIp,
          'use_public_ip': _awsUsePublicIp,
        }..removeWhere((k, v) => v == null),
        _ => inner,
      };
    });

    Navigator.of(context).pop(BuilderConfigEditorResult(config: next));
  }
}

enum _ConfigEncoding { externalTagged, map }

class _BuilderConfigShape {
  const _BuilderConfigShape({
    required this.variant,
    required this.raw,
    required this.inner,
    required this.encoding,
  });

  final String variant;
  final Map<String, dynamic> raw;
  final Map<String, dynamic> inner;
  final _ConfigEncoding encoding;

  Map<String, dynamic> updated(
    Map<String, dynamic> Function(Map<String, dynamic> inner) updateInner,
  ) {
    final nextInner = updateInner(Map<String, dynamic>.from(inner));
    return switch (encoding) {
      _ConfigEncoding.externalTagged => <String, dynamic>{variant: nextInner},
      _ConfigEncoding.map => <String, dynamic>{...raw, ...nextInner},
    };
  }
}

_BuilderConfigShape _parseBuilderConfig(
  Object? raw, {
  required String fallbackType,
}) {
  if (raw is Map<String, dynamic>) {
    if (raw.length == 1) {
      final entry = raw.entries.first;
      if (entry.value is Map) {
        final inner = Map<String, dynamic>.from(entry.value as Map);
        return _BuilderConfigShape(
          variant: entry.key,
          raw: raw,
          inner: inner,
          encoding: _ConfigEncoding.externalTagged,
        );
      }
    }

    final inner = Map<String, dynamic>.from(raw);
    final type = (inner['type'] ?? inner['variant'])?.toString().trim();
    return _BuilderConfigShape(
      variant: (type?.isNotEmpty ?? false) ? type! : fallbackType,
      raw: inner,
      inner: inner,
      encoding: _ConfigEncoding.map,
    );
  }

  return _BuilderConfigShape(
    variant: fallbackType,
    raw: const <String, dynamic>{},
    inner: const <String, dynamic>{},
    encoding: _ConfigEncoding.map,
  );
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
          AppIcons.factory,
          size: 64,
          color: scheme.primary.withValues(alpha: 0.5),
        ),
        const Gap(16),
        Text(
          'No builders found',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          'Create and configure builders in the Komodo web interface.',
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
          'Failed to load builders',
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

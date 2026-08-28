import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';

class AdvancedSyncSection extends ConsumerStatefulWidget {
  const AdvancedSyncSection({
    required this.syncResource,
    required this.onUpdated,
    super.key,
  });

  final KomodoResourceSync syncResource;
  final ValueChanged<KomodoResourceSync> onUpdated;

  @override
  ConsumerState<AdvancedSyncSection> createState() =>
      _AdvancedSyncSectionState();
}

class _AdvancedSyncSectionState extends ConsumerState<AdvancedSyncSection> {
  final _selected = <String>{};
  late KomodoResourceSync _preview;

  @override
  void initState() {
    super.initState();
    _preview = widget.syncResource;
  }

  @override
  void didUpdateWidget(covariant AdvancedSyncSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncResource.info.pendingHash !=
            widget.syncResource.info.pendingHash ||
        oldWidget.syncResource.info.resourceUpdates.length !=
            widget.syncResource.info.resourceUpdates.length) {
      _preview = widget.syncResource;
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _preview.info;
    final diffs = info.resourceUpdates;
    final selectedDiffs = [
      for (final diff in diffs)
        if (_selected.contains(_key(diff))) diff,
    ];
    return DetailSection(
      title: 'Proposed sync plan',
      icon: Icons.account_tree_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Refresh the pending state, inspect every change, then apply only '
            'the resources you approve.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (info.pendingHash?.isNotEmpty ?? false) ...[
            const Gap(10),
            Text('Commit ${info.pendingHash}'),
          ],
          if (info.pendingMessage?.isNotEmpty ?? false)
            Text(info.pendingMessage!),
          const Gap(14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('refresh_sync_plan'),
                onPressed: _refreshPlan,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh plan'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('edit_sync_file'),
                onPressed: _editFile,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Edit sync file'),
              ),
              if (widget.syncResource.config.managed)
                OutlinedButton.icon(
                  key: const ValueKey('commit_sync'),
                  onPressed: _commit,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Commit managed sync'),
                ),
            ],
          ),
          const Gap(14),
          if (diffs.isEmpty)
            const Text('No resource changes are currently pending.')
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selected.length} of ${diffs.length} selected',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == diffs.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(diffs.map(_key));
                    }
                  }),
                  child: Text(
                    _selected.length == diffs.length
                        ? 'Clear all'
                        : 'Select all',
                  ),
                ),
              ],
            ),
            for (final diff in diffs)
              _DiffTile(
                diff: diff,
                selected: _selected.contains(_key(diff)),
                onChanged: (selected) => setState(() {
                  if (selected) {
                    _selected.add(_key(diff));
                  } else {
                    _selected.remove(_key(diff));
                  }
                }),
              ),
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('run_selected_sync'),
                  onPressed: selectedDiffs.isEmpty
                      ? null
                      : () => _runSelected(selectedDiffs),
                  icon: const Icon(AppIcons.play),
                  label: Text('Apply ${selectedDiffs.length} selected'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('export_selected_toml'),
                  onPressed:
                      selectedDiffs.any(
                        (diff) => diff.target.id.isNotEmpty,
                      )
                      ? () => _export(selectedDiffs)
                      : null,
                  icon: const Icon(Icons.code),
                  label: const Text('Export selected TOML'),
                ),
              ],
            ),
          ],
          if (info.variableUpdates.isNotEmpty ||
              info.userGroupUpdates.isNotEmpty) ...[
            const Gap(16),
            Text(
              '${info.variableUpdates.length} variable changes · '
              '${info.userGroupUpdates.length} user-group changes',
            ),
          ],
          if (info.pendingDeploys.isNotEmpty) ...[
            const Gap(16),
            Text(
              'Deploy after sync',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Gap(6),
            for (final deploy in info.pendingDeploys)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rocket_launch_outlined),
                title: Text('${deploy.target.type} ${deploy.target.id}'),
                subtitle: Text(deploy.reason),
              ),
          ],
          if (info.pendingDeployError?.isNotEmpty ?? false) ...[
            const Gap(10),
            Text(
              info.pendingDeployError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (info.remoteErrors.isNotEmpty) ...[
            const Gap(10),
            for (final error in info.remoteErrors)
              Text(
                '${error.resourcePath}/${error.path}: ${error.contents}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ],
      ),
    );
  }

  String _key(ResourceSyncDiff diff) =>
      '${diff.target.type}:${diff.target.id}:${diff.name}:${diff.data.label}';

  Future<void> _refreshPlan() async {
    final updated = await ref
        .read(syncActionsProvider.notifier)
        .refreshPending(widget.syncResource.id);
    if (!mounted) return;
    if (updated == null) {
      _show('Failed to refresh the sync plan.', error: true);
      return;
    }
    setState(() {
      _preview = updated;
      _selected.clear();
    });
    widget.onUpdated(updated);
    _show('Sync plan refreshed.');
  }

  Future<void> _runSelected(List<ResourceSyncDiff> diffs) async {
    if (!await _confirm(
      title: 'Apply selected changes?',
      message:
          '${diffs.length} selected resource changes will be applied. '
          'Review the TOML differences before continuing.',
      confirmLabel: 'Apply changes',
    )) {
      return;
    }
    final success = await ref
        .read(syncActionsProvider.notifier)
        .runSelected(widget.syncResource.id, diffs);
    if (!mounted) return;
    _show(
      success ? 'Selected sync changes started.' : 'Failed to start sync.',
      error: !success,
    );
    if (success) widget.onUpdated(_preview);
  }

  Future<void> _commit() async {
    if (!await _confirm(
      title: 'Commit managed sync?',
      message:
          'Komodo will export matching resources and write them to the '
          'configured sync file.',
      confirmLabel: 'Commit',
    )) {
      return;
    }
    final success = await ref
        .read(syncActionsProvider.notifier)
        .commit(widget.syncResource.id);
    if (!mounted) return;
    _show(
      success ? 'Sync commit started.' : 'Failed to commit sync.',
      error: !success,
    );
    if (success) widget.onUpdated(_preview);
  }

  Future<void> _export(List<ResourceSyncDiff> diffs) async {
    final targets = [
      for (final diff in diffs)
        if (diff.target.id.isNotEmpty) diff.target,
    ];
    final toml = await ref
        .read(syncActionsProvider.notifier)
        .exportResourcesToToml(targets);
    if (!mounted) return;
    if (toml == null) {
      _show('Failed to export selected resources.', error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exported TOML'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: SelectableText(
              toml,
              key: const ValueKey('exported_toml'),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editFile() async {
    final initial = _preview.info.remoteContents.firstOrNull;
    final draft = await showDialog<_SyncFileDraft>(
      context: context,
      builder: (_) => _SyncFileEditorDialog(
        initial: _SyncFileDraft(
          resourcePath:
              initial?.resourcePath ??
              widget.syncResource.config.resourcePath.firstOrNull ??
              '',
          filePath: initial?.path ?? '',
          contents:
              initial?.contents ?? widget.syncResource.config.fileContents,
        ),
      ),
    );
    if (draft == null || !mounted) return;
    final success = await ref
        .read(syncActionsProvider.notifier)
        .writeFileContents(
          syncIdOrName: widget.syncResource.id,
          resourcePath: draft.resourcePath,
          filePath: draft.filePath,
          contents: draft.contents,
        );
    if (!mounted) return;
    _show(
      success ? 'Sync file write started.' : 'Failed to write sync file.',
      error: !success,
    );
    if (success) await _refreshPlan();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  void _show(String message, {bool error = false}) {
    AppSnackBar.show(
      context,
      message,
      tone: error ? AppSnackBarTone.error : AppSnackBarTone.success,
    );
  }
}

class _DiffTile extends StatelessWidget {
  const _DiffTile({
    required this.diff,
    required this.selected,
    required this.onChanged,
  });

  final ResourceSyncDiff diff;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final data = diff.data;
    return Card(
      child: ExpansionTile(
        key: ValueKey('sync_diff_${diff.target.type}_${diff.name}'),
        leading: Checkbox(
          value: selected,
          onChanged: (value) => onChanged(value ?? false),
        ),
        title: Text('${data.label} ${diff.target.type}'),
        subtitle: Text(diff.name),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (data.current.isNotEmpty)
            _TomlBlock(title: 'Current', contents: data.current),
          if (data.current.isNotEmpty && data.proposed.isNotEmpty)
            const Gap(10),
          if (data.proposed.isNotEmpty)
            _TomlBlock(title: 'Proposed', contents: data.proposed),
        ],
      ),
    );
  }
}

class _TomlBlock extends StatelessWidget {
  const _TomlBlock({required this.title, required this.contents});

  final String title;
  final String contents;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.labelLarge),
      const Gap(4),
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            contents,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ),
    ],
  );
}

class _SyncFileDraft {
  const _SyncFileDraft({
    required this.resourcePath,
    required this.filePath,
    required this.contents,
  });

  final String resourcePath;
  final String filePath;
  final String contents;
}

class _SyncFileEditorDialog extends StatefulWidget {
  const _SyncFileEditorDialog({required this.initial});

  final _SyncFileDraft initial;

  @override
  State<_SyncFileEditorDialog> createState() => _SyncFileEditorDialogState();
}

class _SyncFileEditorDialogState extends State<_SyncFileEditorDialog> {
  late final TextEditingController _resourcePath;
  late final TextEditingController _filePath;
  late final TextEditingController _contents;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resourcePath = TextEditingController(text: widget.initial.resourcePath);
    _filePath = TextEditingController(text: widget.initial.filePath);
    _contents = TextEditingController(text: widget.initial.contents);
  }

  @override
  void dispose() {
    _resourcePath.dispose();
    _filePath.dispose();
    _contents.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit sync file'),
    content: SizedBox(
      width: 720,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('sync_resource_path'),
              controller: _resourcePath,
              decoration: const InputDecoration(labelText: 'Resource path'),
            ),
            const Gap(12),
            TextField(
              key: const ValueKey('sync_file_path'),
              controller: _filePath,
              decoration: const InputDecoration(labelText: 'File path'),
            ),
            const Gap(12),
            TextField(
              key: const ValueKey('sync_file_contents'),
              controller: _contents,
              minLines: 10,
              maxLines: 18,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'TOML contents',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const Gap(8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('save_sync_file'),
        onPressed: () {
          if (_resourcePath.text.trim().isEmpty ||
              _filePath.text.trim().isEmpty) {
            setState(() => _error = 'Both paths are required.');
            return;
          }
          Navigator.pop(
            context,
            _SyncFileDraft(
              resourcePath: _resourcePath.text.trim(),
              filePath: _filePath.text.trim(),
              contents: _contents.text,
            ),
          );
        },
        child: const Text('Write file'),
      ),
    ],
  );
}

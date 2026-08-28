import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/shared/resources/data/resource_batch_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_batch.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';

Future<void> showResourceBatchSheet(
  BuildContext context, {
  required ResourceKind kind,
  required List<ResourceBatchItem> items,
  VoidCallback? onCompleted,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ResourceBatchSheet(
      kind: kind,
      items: items,
      onCompleted: onCompleted,
    ),
  );
}

class ResourceListActionsMenu extends StatelessWidget {
  const ResourceListActionsMenu({
    required this.kind,
    required this.onRefresh,
    this.items = const [],
    this.onCreate,
    this.onBatchCompleted,
    super.key,
  });

  final ResourceKind kind;
  final List<ResourceBatchItem> items;
  final Future<void> Function() onRefresh;
  final VoidCallback? onCreate;
  final VoidCallback? onBatchCompleted;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_ResourceListAction>(
    key: ValueKey('resource_operations_${kind.name}'),
    tooltip: 'More actions',
    icon: const Icon(Icons.more_vert),
    onSelected: (action) async {
      switch (action) {
        case _ResourceListAction.refresh:
          await onRefresh();
        case _ResourceListAction.create:
          onCreate?.call();
        case _ResourceListAction.batch:
          await showResourceBatchSheet(
            context,
            kind: kind,
            items: items,
            onCompleted: onBatchCompleted,
          );
      }
    },
    itemBuilder: (context) => [
      const PopupMenuItem(
        value: _ResourceListAction.refresh,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.refresh),
          title: Text('Refresh'),
        ),
      ),
      if (onCreate != null)
        PopupMenuItem(
          value: _ResourceListAction.create,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add),
            title: Text('Create ${kind.singularLabel}'),
          ),
        ),
      if (onBatchCompleted != null && kind.batchActions.isNotEmpty)
        PopupMenuItem(
          value: _ResourceListAction.batch,
          enabled: items.isNotEmpty,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.library_add_check_outlined),
            title: Text('Batch operations'),
          ),
        ),
    ],
  );
}

enum _ResourceListAction { refresh, create, batch }

class _ResourceBatchSheet extends ConsumerStatefulWidget {
  const _ResourceBatchSheet({
    required this.kind,
    required this.items,
    this.onCompleted,
  });

  final ResourceKind kind;
  final List<ResourceBatchItem> items;
  final VoidCallback? onCompleted;

  @override
  ConsumerState<_ResourceBatchSheet> createState() =>
      _ResourceBatchSheetState();
}

class _ResourceBatchSheetState extends ConsumerState<_ResourceBatchSheet> {
  final _selected = <String>{};
  ResourceBatchAction? _action;
  List<ResourceBatchResult>? _results;
  String? _error;
  var _running = false;

  @override
  void initState() {
    super.initState();
    _action = widget.kind.batchActions.first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = _results;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Gap(18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    results == null ? 'Batch operations' : 'Batch results',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _running ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (results == null) ...[
              const Gap(12),
              DropdownButtonFormField<ResourceBatchAction>(
                key: const ValueKey('batch_action'),
                initialValue: _action,
                decoration: const InputDecoration(labelText: 'Operation'),
                items: [
                  for (final action in widget.kind.batchActions)
                    DropdownMenuItem(
                      value: action,
                      child: Row(
                        children: [
                          Icon(action.icon, size: 20),
                          const Gap(10),
                          Text(action.label),
                        ],
                      ),
                    ),
                ],
                onChanged: _running
                    ? null
                    : (value) => setState(() => _action = value),
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selected.length} of ${widget.items.length} selected',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _running
                        ? null
                        : () => setState(() {
                            if (_selected.length == widget.items.length) {
                              _selected.clear();
                            } else {
                              _selected
                                ..clear()
                                ..addAll(widget.items.map((item) => item.id));
                            }
                          }),
                    child: Text(
                      _selected.length == widget.items.length
                          ? 'Clear all'
                          : 'Select all',
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return CheckboxListTile(
                      key: ValueKey('batch_item_${item.id}'),
                      value: _selected.contains(item.id),
                      title: Text(item.name),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: _running
                          ? null
                          : (value) => setState(() {
                              if (value ?? false) {
                                _selected.add(item.id);
                              } else {
                                _selected.remove(item.id);
                              }
                            }),
                    );
                  },
                ),
              ),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: scheme.error)),
                const Gap(8),
              ],
              FilledButton.icon(
                key: const ValueKey('run_batch'),
                onPressed: _running || _selected.isEmpty || _action == null
                    ? null
                    : _run,
                icon: _running
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_action!.icon),
                label: Text(
                  _running
                      ? 'Running…'
                      : '${_action!.label} ${_selected.length}',
                ),
              ),
            ] else ...[
              Text(
                '${results.where((item) => item.success).length} succeeded, '
                '${results.where((item) => !item.success).length} failed',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Gap(12),
              Expanded(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return ListTile(
                      key: ValueKey('batch_result_${result.item.id}'),
                      leading: Icon(
                        result.success
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: result.success ? scheme.primary : scheme.error,
                      ),
                      title: Text(result.item.name),
                      subtitle: Text(
                        result.success
                            ? result.updateAvailable != null
                                  ? result.updateAvailable!
                                        ? 'Update available'
                                        : 'Up to date'
                                  : result.updateId == null
                                  ? 'Started successfully'
                                  : 'Update ${result.updateId}'
                            : result.error ?? 'Unknown error',
                      ),
                    );
                  },
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _run() async {
    final repository = ref.read(resourceBatchRepositoryProvider);
    if (repository == null) {
      setState(() => _error = 'No active Komodo connection.');
      return;
    }
    setState(() {
      _running = true;
      _error = null;
    });
    final result = await repository.execute(
      kind: widget.kind,
      action: _action!,
      items: [
        for (final item in widget.items)
          if (_selected.contains(item.id)) item,
      ],
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _running = false;
        _error = failure.displayMessage;
      }),
      (items) {
        setState(() {
          _running = false;
          _results = items;
        });
        widget.onCompleted?.call();
      },
    );
  }
}

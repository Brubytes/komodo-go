import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:komodo_go/shared/logs/server_log_controller.dart';

Future<void> showServerLogFilterSheet(
  BuildContext context, {
  required ServerLogController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ServerLogFilterSheet(controller: controller),
  );
}

/// Every log setting in one place. Changes apply immediately.
class ServerLogFilterSheet extends StatelessWidget {
  const ServerLogFilterSheet({required this.controller, super.key});

  final ServerLogController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log filters', style: textTheme.titleLarge),
            const Gap(20),
            const _SectionLabel('Lines'),
            SegmentedButton<int>(
              key: const ValueKey('server_log_tail'),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                for (final value in ServerLogController.tails)
                  ButtonSegment(value: value, label: Text('$value')),
              ],
              selected: {controller.tail},
              onSelectionChanged: (value) => controller.setTail(value.first),
            ),
            const Gap(20),
            const _SectionLabel('Matching'),
            SegmentedButton<LogSearchCombinator>(
              key: const ValueKey('server_log_combinator'),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(
                  value: LogSearchCombinator.and,
                  label: Text('All terms'),
                ),
                ButtonSegment(
                  value: LogSearchCombinator.or,
                  label: Text('Any term'),
                ),
              ],
              selected: {controller.combinator},
              onSelectionChanged: (value) =>
                  controller.setCombinator(value.first),
            ),
            SwitchListTile(
              key: const ValueKey('server_log_invert'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude matches'),
              subtitle: const Text('Show lines that do not match'),
              value: controller.invert,
              onChanged: (value) => controller.setInvert(value: value),
            ),
            const _SectionLabel('Display'),
            SwitchListTile(
              key: const ValueKey('server_log_timestamps'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Timestamps'),
              value: controller.timestamps,
              onChanged: (value) => controller.setTimestamps(value: value),
            ),
            SwitchListTile(
              key: const ValueKey('server_log_wrap'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Wrap lines'),
              subtitle: const Text('Off scrolls sideways, handy in landscape'),
              value: controller.wrapLines,
              onChanged: (value) =>
                  unawaited(controller.setWrapLines(value: value)),
            ),
            SwitchListTile(
              key: const ValueKey('server_log_raw'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Raw text'),
              subtitle: const Text('Plain text you can select across lines'),
              value: controller.rawText,
              onChanged: (value) => controller.setRawText(value: value),
            ),
            const Gap(8),
            _SavedFilters(controller: controller),
            const Gap(20),
            Text(
              'Separate multiple search terms with commas, e.g. '
              '"error, timeout". All terms shows lines containing every '
              'term, any term shows lines containing at least one. Exclude '
              'matches reverses the condition.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedFilters extends StatelessWidget {
  const _SavedFilters({required this.controller});

  final ServerLogController controller;

  @override
  Widget build(BuildContext context) {
    final filters = controller.savedFilters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('Saved filters')),
            TextButton.icon(
              key: const ValueKey('server_log_save_filter'),
              onPressed: controller.isSearching
                  ? () => _saveCurrent(context)
                  : null,
              icon: const Icon(AppIcons.bookmarkAdd, size: 16),
              label: const Text('Save current'),
            ),
          ],
        ),
        if (filters.isEmpty)
          Text(
            'Search for something, then save it here for quick reuse.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final filter in filters)
            Dismissible(
              key: ValueKey('saved_log_filter_${filter.name}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Icon(
                  AppIcons.delete,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              onDismissed: (_) => unawaited(controller.deleteFilter(filter)),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.bookmark, size: 18),
                title: Text(filter.name),
                subtitle: Text(
                  filter.terms.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  controller.applyFilter(filter);
                  Navigator.pop(context);
                },
              ),
            ),
      ],
    );
  }

  Future<void> _saveCurrent(BuildContext context) async {
    var filterName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save log filter'),
        content: TextField(
          key: const ValueKey('saved_log_filter_name'),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Filter name'),
          onChanged: (value) => filterName = value.trim(),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, filterName),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await controller.saveCurrentFilter(name);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

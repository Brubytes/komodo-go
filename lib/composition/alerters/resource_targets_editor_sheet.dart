import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_catalog_provider.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_surface.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';
import 'package:komodo_go/shared/resources/models/resource_option.dart';

class ResourceTargetsEditorSheet extends ConsumerStatefulWidget {
  const ResourceTargetsEditorSheet({
    required this.title,
    required this.subtitle,
    required this.modeLabel,
    required this.initial,
    super.key,
  });

  final String title;
  final String subtitle;
  final String modeLabel;
  final List<AlerterResourceTarget> initial;

  static Future<List<AlerterResourceTarget>?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String modeLabel,
    required List<AlerterResourceTarget> initial,
  }) {
    return showModalBottomSheet<List<AlerterResourceTarget>>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ResourceTargetsEditorSheet(
        title: title,
        subtitle: subtitle,
        modeLabel: modeLabel,
        initial: initial,
      ),
    );
  }

  @override
  ConsumerState<ResourceTargetsEditorSheet> createState() =>
      _ResourceTargetsEditorSheetState();
}

class _ResourceTargetsEditorSheetState
    extends ConsumerState<ResourceTargetsEditorSheet> {
  late List<AlerterResourceTarget> _items;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _items = List<AlerterResourceTarget>.from(widget.initial);
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

    final optionsAsync = ref.watch(resourceOptionsProvider);
    final options = optionsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <ResourceOption>[],
    );

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

    final hasErrors = optionsAsync.hasError;
    final isLoading = optionsAsync.isLoading;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => Stack(
        children: [
          ListView(
            controller: controller,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom + 72,
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
                    const AppInlineSkeleton(),
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
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
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
                                  child: Switch.adaptive(
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
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
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
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom - 16,
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_items),
                child: const Text('Confirm'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleOption(ResourceOption option, bool next) {
    final nextItems = List<AlerterResourceTarget>.from(_items);
    final index = nextItems.indexWhere((item) => item.key == option.key);
    if (next) {
      if (index == -1) {
        nextItems.add(
          AlerterResourceTarget(
            variant: option.variant,
            value: option.ref.id,
            name: option.name,
          ),
        );
      }
    } else {
      if (index != -1) nextItems.removeAt(index);
    }
    setState(() => _items = nextItems);
  }

  void _removeUnknown(AlerterResourceTarget entry) {
    final nextItems = List<AlerterResourceTarget>.from(_items)
      ..removeWhere((item) => item.key == entry.key);
    setState(() => _items = nextItems);
  }
}

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_surface.dart';

class TagOption {
  const TagOption({required this.id, required this.name});

  final String id;
  final String name;
}

class TagFilterSheet extends StatefulWidget {
  const TagFilterSheet({
    required this.availableTags,
    required this.initial,
    this.resourceName = 'items',
    super.key,
  });

  final List<TagOption> availableTags;
  final Set<String> initial;
  final String resourceName;

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<TagOption> availableTags,
    required Set<String> selected,
    String resourceName = 'items',
  }) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => TagFilterSheet(
        availableTags: availableTags,
        initial: selected,
        resourceName: resourceName,
      ),
    );
  }

  @override
  State<TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends State<TagFilterSheet> {
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

  void _toggleTag(String tag, bool next) {
    setState(() {
      if (next) {
        _selected.add(tag);
      } else {
        _selected.remove(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final query = _searchController.text.trim().toLowerCase();
    final sorted = [...widget.availableTags]
      ..sort((a, b) => a.name.compareTo(b.name));
    final filtered = query.isEmpty
        ? sorted
        : sorted
            .where((tag) => tag.name.toLowerCase().contains(query))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => Stack(
        children: [
          ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).padding.bottom + 72,
            ),
            children: [
              Row(
                children: [
                  Text(
                    'Tag filter',
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
                'Select tags to filter ${widget.resourceName}. '
                'Matching any tag will include an item.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Gap(12),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search tags',
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
                    '${widget.availableTags.length} tags',
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
                          'No tags match your search.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (final (index, tag) in filtered.indexed) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            color: scheme.outlineVariant.withValues(alpha: .35),
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
                                  tag.name,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _selected.contains(tag.id),
                                onChanged: (next) => _toggleTag(tag.id, next),
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
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom - 16,
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Confirm'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

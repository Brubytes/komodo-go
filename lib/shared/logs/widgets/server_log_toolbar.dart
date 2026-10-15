import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:komodo_go/shared/logs/server_log_controller.dart';
import 'package:komodo_go/shared/logs/widgets/server_log_filter_sheet.dart';

/// Search field, filter button and live toggle, followed by chips that
/// summarise every non-default setting.
class ServerLogToolbar extends StatefulWidget {
  const ServerLogToolbar({
    required this.controller,
    this.onAutoRefreshChanged,
    this.trailing = const [],
    super.key,
  });

  final ServerLogController controller;
  final ValueChanged<bool>? onAutoRefreshChanged;

  /// Extra buttons appended after the live toggle (e.g. refresh).
  final List<Widget> trailing;

  @override
  State<ServerLogToolbar> createState() => _ServerLogToolbarState();
}

class _ServerLogToolbarState extends State<ServerLogToolbar> {
  late final _searchController = TextEditingController(
    text: widget.controller.query,
  );

  ServerLogController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncQuery);
  }

  @override
  void didUpdateWidget(covariant ServerLogToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncQuery);
      widget.controller.addListener(_syncQuery);
      _syncQuery();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncQuery);
    _searchController.dispose();
    super.dispose();
  }

  /// Keeps the field in sync when the query changes elsewhere (saved filter,
  /// chip reset, or the other explorer surface).
  void _syncQuery() {
    if (_searchController.text != _controller.query) {
      _searchController.text = _controller.query;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildSearchField()),
              const Gap(6),
              _FilterButton(
                count: _controller.activeFilterCount,
                onPressed: () {
                  // Keep the keyboard from covering the sheet.
                  FocusScope.of(context).unfocus();
                  unawaited(
                    showServerLogFilterSheet(context, controller: _controller),
                  );
                },
              ),
              _WrapToggle(
                wrapped: _controller.wrapLines,
                onPressed: () => unawaited(
                  _controller.setWrapLines(value: !_controller.wrapLines),
                ),
              ),
              _LiveToggle(
                enabled: _controller.autoRefresh,
                onPressed: () {
                  final next = !_controller.autoRefresh;
                  _controller.setAutoRefresh(value: next);
                  widget.onAutoRefreshChanged?.call(next);
                },
              ),
              ...widget.trailing,
            ],
          ),
          _ActiveFilterChips(controller: _controller),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return TextField(
      key: const ValueKey('server_log_search'),
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search logs',
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: border,
        enabledBorder: border,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        prefixIcon: const Icon(AppIcons.search, size: 18),
        suffixIcon: _controller.query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _controller.clearSearch,
                icon: const Icon(AppIcons.close, size: 18),
              ),
      ),
      onChanged: _controller.setQuery,
      onSubmitted: (_) => _controller.submitSearch(),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('server_log_filters'),
      tooltip: 'Log filters',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(AppIcons.filters, size: 20),
      ),
    );
  }
}

class _WrapToggle extends StatelessWidget {
  const _WrapToggle({required this.wrapped, required this.onPressed});

  final bool wrapped;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('server_log_wrap_toggle'),
      tooltip: wrapped ? 'Scroll long lines' : 'Wrap long lines',
      onPressed: onPressed,
      isSelected: wrapped,
      icon: Icon(wrapped ? Icons.wrap_text : Icons.short_text, size: 20),
    );
  }
}

class _LiveToggle extends StatelessWidget {
  const _LiveToggle({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      key: const ValueKey('server_log_live'),
      tooltip: enabled ? 'Pause auto refresh' : 'Resume auto refresh',
      onPressed: onPressed,
      isSelected: enabled,
      style: IconButton.styleFrom(
        backgroundColor: enabled ? scheme.secondaryContainer : null,
        foregroundColor: enabled ? scheme.onSecondaryContainer : null,
      ),
      icon: enabled ? const _LiveDot() : const Icon(AppIcons.pause, size: 18),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 20,
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// One chip per non-default setting; tapping a chip resets that setting.
class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({required this.controller});

  final ServerLogController controller;

  @override
  Widget build(BuildContext context) {
    final searching = controller.isSearching;
    final chips = <Widget>[
      if (searching && controller.combinator == LogSearchCombinator.or)
        _chip(
          context,
          'Any term',
          () => controller.setCombinator(LogSearchCombinator.and),
        ),
      if (searching && controller.invert)
        _chip(
          context,
          'Excluding matches',
          () => controller.setInvert(value: false),
        ),
      if (controller.tail != ServerLogController.defaultTail)
        _chip(
          context,
          '${controller.tail} lines',
          () => controller.setTail(ServerLogController.defaultTail),
        ),
      if (!controller.timestamps)
        _chip(
          context,
          'No timestamps',
          () => controller.setTimestamps(value: true),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback onReset) {
    return InputChip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      deleteIcon: const Icon(AppIcons.close, size: 14),
      deleteButtonTooltipMessage: 'Reset',
      onDeleted: onReset,
      onPressed: onReset,
    );
  }
}

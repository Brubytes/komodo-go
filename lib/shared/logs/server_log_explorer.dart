import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ServerLogLoader =
    Future<ServerLogSnapshot> Function(ServerLogRequest request);

enum _LogOption { invert, timestamps, autoRefresh }

class ServerLogExplorer extends StatefulWidget {
  const ServerLogExplorer({
    required this.loader,
    this.title = 'Server logs',
    this.autoRefresh = true,
    super.key,
  });

  final ServerLogLoader loader;
  final String title;
  final bool autoRefresh;

  @override
  State<ServerLogExplorer> createState() => _ServerLogExplorerState();
}

class _ServerLogExplorerState extends State<ServerLogExplorer> {
  static const _savedFiltersKey = 'komodo.saved_log_filters.v1';
  static const _tails = [100, 200, 500, 1000, 5000];

  final _searchController = TextEditingController();
  final _savedFilters = <SavedLogFilter>[];
  ServerLogSnapshot? _log;
  Object? _error;
  Timer? _timer;
  var _loading = true;
  var _tail = 200;
  var _timestamps = true;
  var _invert = false;
  LogSearchCombinator _combinator = LogSearchCombinator.and;
  late bool _autoRefresh = widget.autoRefresh;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreFilters());
    unawaited(_load());
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant ServerLogExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoRefresh != widget.autoRefresh) {
      _autoRefresh = widget.autoRefresh;
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DetailSection(
      title: widget.title,
      icon: AppIcons.logs,
      trailing: IconButton(
        tooltip: 'Refresh logs',
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('server_log_search'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search logs',
              hintText: 'error, timeout',
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'How log search works',
                    onPressed: _showSearchHelp,
                    icon: const Icon(Icons.info_outline),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _load(),
          ),
          const Gap(8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PopupMenuButton<int>(
                  key: const ValueKey('server_log_tail'),
                  tooltip: 'Tail lines',
                  onSelected: (value) {
                    setState(() => _tail = value);
                    if (!_isSearching) unawaited(_load());
                  },
                  itemBuilder: (context) => [
                    for (final value in _tails)
                      CheckedPopupMenuItem(
                        value: value,
                        checked: value == _tail,
                        child: Text('$value lines'),
                      ),
                  ],
                  child: _LogToolbarButton(
                    icon: Icons.format_list_numbered,
                    label: '$_tail lines',
                    dropdown: true,
                  ),
                ),
                PopupMenuButton<LogSearchCombinator>(
                  tooltip: 'Term matching',
                  onSelected: (value) => setState(() => _combinator = value),
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem(
                      value: LogSearchCombinator.and,
                      checked: _combinator == LogSearchCombinator.and,
                      child: const Text('Match all terms'),
                    ),
                    CheckedPopupMenuItem(
                      value: LogSearchCombinator.or,
                      checked: _combinator == LogSearchCombinator.or,
                      child: const Text('Match any term'),
                    ),
                  ],
                  child: _LogToolbarButton(
                    icon: Icons.rule,
                    label: _combinator == LogSearchCombinator.and
                        ? 'Match all'
                        : 'Match any',
                    dropdown: true,
                  ),
                ),
                PopupMenuButton<_LogOption>(
                  tooltip: 'Log options',
                  onSelected: _toggleOption,
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem(
                      value: _LogOption.invert,
                      checked: _invert,
                      child: const Text('Exclude matches'),
                    ),
                    CheckedPopupMenuItem(
                      value: _LogOption.timestamps,
                      checked: _timestamps,
                      child: const Text('Timestamps'),
                    ),
                    CheckedPopupMenuItem(
                      value: _LogOption.autoRefresh,
                      checked: _autoRefresh,
                      child: const Text('Auto refresh'),
                    ),
                  ],
                  child: const _LogToolbarButton(
                    icon: Icons.tune,
                    label: 'Options',
                    dropdown: true,
                  ),
                ),
                IconButton(
                  tooltip: 'Save filter',
                  visualDensity: VisualDensity.compact,
                  onPressed: _searchController.text.trim().isEmpty
                      ? null
                      : _saveCurrentFilter,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                ),
                if (_savedFilters.isNotEmpty)
                  PopupMenuButton<SavedLogFilter>(
                    tooltip: 'Saved filters',
                    onSelected: _applyFilter,
                    itemBuilder: (context) => [
                      for (final filter in _savedFilters)
                        PopupMenuItem(
                          value: filter,
                          child: Text(filter.name),
                        ),
                    ],
                    icon: const Icon(Icons.bookmarks_outlined, size: 20),
                  ),
                FilledButton.icon(
                  key: const ValueKey('run_server_log_search'),
                  onPressed: _loading || _searchController.text.trim().isEmpty
                      ? null
                      : _load,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                ),
              ],
            ),
          ),
          const Gap(14),
          if (_loading && _log == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Text(
              'Logs unavailable: $_error',
              style: TextStyle(color: scheme.error),
            )
          else
            DetailCodeBlock(
              code: _log?.combined.isNotEmpty ?? false
                  ? _log!.combined
                  : _isSearching
                  ? 'No matching log lines.'
                  : 'No log output.',
              tabletMaxHeight: 620,
            ),
          if (_loading && _log != null) ...[
            const Gap(8),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  ServerLogRequest get _request => ServerLogRequest(
    terms: _terms,
    combinator: _combinator,
    invert: _invert,
    tail: _tail,
    timestamps: _timestamps,
  );

  List<String> get _terms => _searchController.text
      .split(',')
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .toList();

  Future<void> _load() async {
    if (!mounted) return;
    final request = _request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.loader(request);
      if (!mounted) return;
      setState(() => _log = value.capped(tail: request.tail));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    if (!_autoRefresh) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_loading) unawaited(_load());
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _invert = false;
      _combinator = LogSearchCombinator.and;
    });
    unawaited(_load());
  }

  Future<void> _showSearchHelp() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How log search works'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Separate multiple search terms with commas.'),
            Gap(12),
            Text(
              'error, timeout',
              style: TextStyle(fontFamily: 'monospace'),
            ),
            Gap(12),
            Text('Match all shows lines containing every term.'),
            Gap(6),
            Text('Match any shows lines containing at least one term.'),
            Gap(6),
            Text('Exclude matches reverses the selected condition.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _toggleOption(_LogOption option) {
    switch (option) {
      case _LogOption.invert:
        setState(() => _invert = !_invert);
      case _LogOption.timestamps:
        setState(() => _timestamps = !_timestamps);
        unawaited(_load());
      case _LogOption.autoRefresh:
        setState(() => _autoRefresh = !_autoRefresh);
        _syncTimer();
    }
  }

  Future<void> _restoreFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedFiltersKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as List<dynamic>;
      final filters = json
          .whereType<Map<String, dynamic>>()
          .map(SavedLogFilter.fromJson)
          .where((filter) => filter.name.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _savedFilters
          ..clear()
          ..addAll(filters);
      });
    } on Object {
      // Ignore malformed legacy preferences.
    }
  }

  Future<void> _saveCurrentFilter() async {
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
    if (name == null || name.isEmpty || !mounted) return;
    final filter = SavedLogFilter(
      name: name,
      terms: _terms,
      combinator: _combinator,
      invert: _invert,
      timestamps: _timestamps,
    );
    setState(() {
      _savedFilters
        ..removeWhere((item) => item.name == name)
        ..add(filter);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedFiltersKey,
      jsonEncode(_savedFilters.map((item) => item.toJson()).toList()),
    );
  }

  void _applyFilter(SavedLogFilter filter) {
    _searchController.text = filter.terms.join(', ');
    setState(() {
      _combinator = filter.combinator;
      _invert = filter.invert;
      _timestamps = filter.timestamps;
    });
    unawaited(_load());
  }
}

class _LogToolbarButton extends StatelessWidget {
  const _LogToolbarButton({
    required this.icon,
    required this.label,
    this.dropdown = false,
  });

  final IconData icon;
  final String label;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const Gap(6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color),
          ),
          if (dropdown) ...[
            const Gap(2),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ],
      ),
    );
  }
}

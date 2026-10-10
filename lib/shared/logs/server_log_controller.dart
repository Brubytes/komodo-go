import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ServerLogLoader =
    Future<ServerLogSnapshot> Function(ServerLogRequest request);

/// Holds the log query, latest snapshot, and refresh timer so the inline
/// explorer and the full-screen viewer stay in sync.
class ServerLogController extends ChangeNotifier {
  ServerLogController({
    required this.loader,
    this._autoRefresh = true,
    this.refreshInterval = const Duration(seconds: 3),
  });

  static const savedFiltersKey = 'komodo.saved_log_filters.v1';
  static const wrapLinesKey = 'komodo.log_wrap_lines.v1';
  static const tails = [100, 200, 500, 1000, 5000];
  static const defaultTail = 200;

  ServerLogLoader loader;
  final Duration refreshInterval;

  final _savedFilters = <SavedLogFilter>[];
  ServerLogSnapshot? _log;
  Object? _error;
  DateTime? _updatedAt;
  Timer? _timer;
  var _loading = false;
  var _disposed = false;
  var _query = '';
  int _tail = defaultTail;
  var _timestamps = true;
  var _invert = false;
  LogSearchCombinator _combinator = LogSearchCombinator.and;
  bool _autoRefresh;
  var _wrapLines = true;
  var _queryVersion = 0;
  var _logVersion = 0;

  ServerLogSnapshot? get log => _log;
  Object? get error => _error;
  DateTime? get updatedAt => _updatedAt;
  bool get loading => _loading;
  String get query => _query;
  int get tail => _tail;
  bool get timestamps => _timestamps;
  bool get invert => _invert;
  LogSearchCombinator get combinator => _combinator;
  bool get autoRefresh => _autoRefresh;
  bool get wrapLines => _wrapLines;

  /// Query version the current [log] was loaded for. It changes when the
  /// search or filters change, but not on a plain refresh of the same query.
  int get logVersion => _logVersion;
  List<SavedLogFilter> get savedFilters => List.unmodifiable(_savedFilters);

  /// Comma-separated search terms from the current query.
  List<String> get terms => _query
      .split(',')
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .toList();

  bool get isSearching => terms.isNotEmpty;

  /// Number of settings that differ from their defaults.
  int get activeFilterCount => [
    _tail != defaultTail,
    !_timestamps,
    isSearching && _invert,
    isSearching && _combinator != LogSearchCombinator.and,
  ].where((changed) => changed).length;

  ServerLogRequest get request => ServerLogRequest(
    terms: terms,
    combinator: _combinator,
    invert: _invert,
    tail: _tail,
    timestamps: _timestamps,
  );

  Future<void> start() async {
    unawaited(restoreFilters());
    unawaited(_restoreWrapLines());
    _syncTimer();
    await load();
  }

  Future<void> load() async {
    if (_disposed) return;
    final request = this.request;
    final version = _queryVersion;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final value = await loader(request);
      if (_disposed) return;
      // A newer query may have started while this one was in flight.
      if (version != _queryVersion) return;
      _log = value.capped(tail: request.tail);
      _logVersion = version;
      _updatedAt = DateTime.now();
    } on Object catch (error) {
      if (_disposed || version != _queryVersion) return;
      _error = error;
    } finally {
      // Leave the spinner to the newer request if one superseded this one.
      if (!_disposed && version == _queryVersion) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Updates the query text without loading; searches run on submit.
  void setQuery(String value) {
    if (value == _query) return;
    final wasSearching = isSearching;
    _query = value;
    if (wasSearching && !isSearching) _queryVersion++;
    notifyListeners();
    // Clearing the field returns to the plain tail immediately.
    if (wasSearching && !isSearching) unawaited(load());
  }

  void submitSearch() {
    _queryVersion++;
    unawaited(load());
  }

  void clearSearch() {
    _query = '';
    _invert = false;
    _combinator = LogSearchCombinator.and;
    _queryVersion++;
    unawaited(load());
  }

  void setTail(int value) {
    if (value == _tail) return;
    _tail = value;
    _queryVersion++;
    // Search endpoints ignore tail, the cap is applied client-side on load.
    unawaited(load());
  }

  void setTimestamps({required bool value}) {
    if (value == _timestamps) return;
    _timestamps = value;
    _queryVersion++;
    unawaited(load());
  }

  void setInvert({required bool value}) {
    if (value == _invert) return;
    _invert = value;
    _reloadIfSearching();
  }

  void setCombinator(LogSearchCombinator value) {
    if (value == _combinator) return;
    _combinator = value;
    _reloadIfSearching();
  }

  void setAutoRefresh({required bool value}) {
    if (value == _autoRefresh) return;
    _autoRefresh = value;
    _syncTimer();
    notifyListeners();
  }

  Future<void> setWrapLines({required bool value}) async {
    if (value == _wrapLines) return;
    _wrapLines = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(wrapLinesKey, value);
  }

  Future<void> _restoreWrapLines() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(wrapLinesKey);
    if (value == null || _disposed || value == _wrapLines) return;
    _wrapLines = value;
    notifyListeners();
  }

  void _reloadIfSearching() {
    if (isSearching) {
      _queryVersion++;
      unawaited(load());
    } else {
      notifyListeners();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_autoRefresh || _disposed) return;
    _timer = Timer.periodic(refreshInterval, (_) {
      if (!_loading) unawaited(load());
    });
  }

  Future<void> restoreFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(savedFiltersKey);
    if (raw == null || _disposed) return;
    try {
      final json = jsonDecode(raw) as List<dynamic>;
      final filters = json
          .whereType<Map<String, dynamic>>()
          .map(SavedLogFilter.fromJson)
          .where((filter) => filter.name.isNotEmpty);
      _savedFilters
        ..clear()
        ..addAll(filters);
      notifyListeners();
    } on Object {
      // Ignore malformed legacy preferences.
    }
  }

  Future<void> saveCurrentFilter(String name) async {
    final filter = SavedLogFilter(
      name: name,
      terms: terms,
      combinator: _combinator,
      invert: _invert,
      timestamps: _timestamps,
    );
    _savedFilters
      ..removeWhere((item) => item.name == name)
      ..add(filter);
    notifyListeners();
    await _persistFilters();
  }

  Future<void> deleteFilter(SavedLogFilter filter) async {
    _savedFilters.removeWhere((item) => item.name == filter.name);
    notifyListeners();
    await _persistFilters();
  }

  void applyFilter(SavedLogFilter filter) {
    _query = filter.terms.join(', ');
    _combinator = filter.combinator;
    _invert = filter.invert;
    _timestamps = filter.timestamps;
    _queryVersion++;
    unawaited(load());
  }

  Future<void> _persistFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      savedFiltersKey,
      jsonEncode(_savedFilters.map((item) => item.toJson()).toList()),
    );
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

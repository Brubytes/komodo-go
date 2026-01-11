import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ConnectionDraft {
  const ConnectionDraft({
    this.name = '',
    this.baseUrl = '',
    this.apiKey = '',
    this.apiSecret = '',
  });

  final String name;
  final String baseUrl;
  final String apiKey;
  final String apiSecret;

  ConnectionDraft copyWith({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? apiSecret,
  }) {
    return ConnectionDraft(
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
    );
  }
}

class ConnectionDraftNotifier extends Notifier<ConnectionDraft> {
  @override
  ConnectionDraft build() => const ConnectionDraft();

  void update({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? apiSecret,
  }) {
    state = state.copyWith(
      name: name,
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
    );
  }

  void reset() {
    state = const ConnectionDraft();
  }
}

final connectionDraftProvider =
    NotifierProvider<ConnectionDraftNotifier, ConnectionDraft>(
      ConnectionDraftNotifier.new,
    );

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komodo_go/core/api/custom_header.dart';

@immutable
class ConnectionDraft {
  const ConnectionDraft({
    this.name = '',
    this.baseUrl = '',
    this.apiKey = '',
    this.apiSecret = '',
    this.proxyAuthEnabled = false,
    this.proxyAuthUsername = '',
    this.proxyAuthPassword = '',
    this.customHeaders = const [],
  });

  final String name;
  final String baseUrl;
  final String apiKey;
  final String apiSecret;
  final bool proxyAuthEnabled;
  final String proxyAuthUsername;
  final String proxyAuthPassword;
  final List<CustomHeader> customHeaders;

  ConnectionDraft copyWith({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? apiSecret,
    bool? proxyAuthEnabled,
    String? proxyAuthUsername,
    String? proxyAuthPassword,
    List<CustomHeader>? customHeaders,
  }) {
    return ConnectionDraft(
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      proxyAuthEnabled: proxyAuthEnabled ?? this.proxyAuthEnabled,
      proxyAuthUsername: proxyAuthUsername ?? this.proxyAuthUsername,
      proxyAuthPassword: proxyAuthPassword ?? this.proxyAuthPassword,
      customHeaders: customHeaders ?? this.customHeaders,
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
    bool? proxyAuthEnabled,
    String? proxyAuthUsername,
    String? proxyAuthPassword,
    List<CustomHeader>? customHeaders,
  }) {
    state = state.copyWith(
      name: name,
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
      proxyAuthEnabled: proxyAuthEnabled,
      proxyAuthUsername: proxyAuthUsername,
      proxyAuthPassword: proxyAuthPassword,
      customHeaders: customHeaders,
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

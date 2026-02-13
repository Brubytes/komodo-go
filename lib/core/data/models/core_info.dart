class CoreInfo {
  const CoreInfo({required this.webhookBaseUrl});

  factory CoreInfo.fromJson(Map<String, dynamic> json) {
    return CoreInfo(
      webhookBaseUrl: (json['webhook_base_url'] as String?)?.trim() ?? '',
    );
  }

  final String webhookBaseUrl;
}

class CoreInfo {
  const CoreInfo({required this.webhookBaseUrl});

  final String webhookBaseUrl;

  factory CoreInfo.fromJson(Map<String, dynamic> json) {
    return CoreInfo(
      webhookBaseUrl: (json['webhook_base_url'] as String?)?.trim() ?? '',
    );
  }
}

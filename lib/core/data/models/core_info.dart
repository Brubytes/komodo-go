class CoreInfo {
  const CoreInfo({
    required this.webhookBaseUrl,
    this.defaultPaginationLimit = 50,
  });

  factory CoreInfo.fromJson(Map<String, dynamic> json) {
    return CoreInfo(
      webhookBaseUrl: (json['webhook_base_url'] as String?)?.trim() ?? '',
      defaultPaginationLimit:
          (json['default_pagination_limit'] as num?)?.toInt() ?? 50,
    );
  }

  final String webhookBaseUrl;
  final int defaultPaginationLimit;
}

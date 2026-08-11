/// The Core version reported by Komodo's `GetVersion` read request.
final class KomodoCoreVersion {
  KomodoCoreVersion._({
    required this.raw,
    required this.major,
    required this.minor,
    required this.patch,
  });

  factory KomodoCoreVersion.parse(String value) {
    final raw = value.trim();
    final match = RegExp(r'^[vV]?(\d+)\.(\d+)\.(\d+)').firstMatch(raw);

    return KomodoCoreVersion._(
      raw: raw,
      major: int.tryParse(match?.group(1) ?? ''),
      minor: int.tryParse(match?.group(2) ?? ''),
      patch: int.tryParse(match?.group(3) ?? ''),
    );
  }

  final String raw;
  final int? major;
  final int? minor;
  final int? patch;

  bool get isParsed => major != null && minor != null && patch != null;

  String get display => raw.toLowerCase().startsWith('v') ? raw : 'v$raw';

  bool isAtLeast(int targetMajor, int targetMinor, int targetPatch) {
    final currentMajor = major;
    final currentMinor = minor;
    final currentPatch = patch;
    if (currentMajor == null || currentMinor == null || currentPatch == null) {
      return false;
    }

    if (currentMajor != targetMajor) return currentMajor > targetMajor;
    if (currentMinor != targetMinor) return currentMinor > targetMinor;
    return currentPatch >= targetPatch;
  }
}

enum KomodoApiGeneration { v22, v23AndNewer }

/// Central compatibility boundary for Komodo Core API generations.
///
/// Keep every 2.2 branch behind this type. When 2.2 support is retired, remove
/// [KomodoApiGeneration.v22], its getters' legacy branches, and the tests that
/// use [v22].
final class KomodoApiCapabilities {
  const KomodoApiCapabilities._(this.generation);

  factory KomodoApiCapabilities.fromVersion(KomodoCoreVersion version) {
    return version.isAtLeast(2, 3, 0) ? v23AndNewer : v22;
  }

  static const v22 = KomodoApiCapabilities._(KomodoApiGeneration.v22);
  static const v23AndNewer = KomodoApiCapabilities._(
    KomodoApiGeneration.v23AndNewer,
  );

  final KomodoApiGeneration generation;

  bool get isLegacyV22 => generation == KomodoApiGeneration.v22;
  bool get supportsPaginatedResourceLists => !isLegacyV22;
  bool get supportsMultipleServerBuilders => !isLegacyV22;
  bool get supportsImageRegistryNaming => !isLegacyV22;
  bool get supportsDeploymentCustomName => !isLegacyV22;
  bool get supportsActionCancellation => !isLegacyV22;

  /// Komodo declares ResourceTarget with Serde's adjacent tagging:
  /// `#[serde(tag = "type", content = "id")]` in every supported generation.
  Map<String, dynamic> encodeResourceTarget({
    required String type,
    required String id,
  }) => <String, dynamic>{'type': type, 'id': id};

  String get listContainersRpc =>
      isLegacyV22 ? 'ListDockerContainers' : 'ListContainers';
  String get listNetworksRpc =>
      isLegacyV22 ? 'ListDockerNetworks' : 'ListNetworks';
  String get listRegistryAccountsRpc =>
      isLegacyV22 ? 'ListDockerRegistryAccounts' : 'ListImageRegistryAccounts';
  String get createRegistryAccountRpc => isLegacyV22
      ? 'CreateDockerRegistryAccount'
      : 'CreateImageRegistryAccount';
  String get updateRegistryAccountRpc => isLegacyV22
      ? 'UpdateDockerRegistryAccount'
      : 'UpdateImageRegistryAccount';
  String get deleteRegistryAccountRpc => isLegacyV22
      ? 'DeleteDockerRegistryAccount'
      : 'DeleteImageRegistryAccount';
}

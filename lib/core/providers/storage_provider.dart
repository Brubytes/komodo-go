import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_provider.g.dart';

/// App-wide secure storage configuration.
///
/// On iOS the keychain items use `first_unlock_this_device`
/// (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) so stored API
/// credentials never migrate to another device via backups or iCloud
/// keychain sync.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

/// Provides the FlutterSecureStorage instance.
@riverpod
FlutterSecureStorage flutterSecureStorage(Ref ref) {
  return appSecureStorage;
}

/// Provides the SecureStorageService for storing credentials.
@riverpod
SecureStorageService secureStorage(Ref ref) {
  return SecureStorageService(ref.watch(flutterSecureStorageProvider));
}

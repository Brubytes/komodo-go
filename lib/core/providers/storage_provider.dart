import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_storage_service.dart';

part 'storage_provider.g.dart';

/// Provides the FlutterSecureStorage instance.
@riverpod
FlutterSecureStorage flutterSecureStorage(Ref ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
}

/// Provides the SecureStorageService for storing credentials.
@riverpod
SecureStorageService secureStorage(Ref ref) {
  return SecureStorageService(ref.watch(flutterSecureStorageProvider));
}

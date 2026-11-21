import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ISecureKeyStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyStorage implements ISecureKeyStorage {
  final FlutterSecureStorage _storage;

  FlutterSecureKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Service responsible for managing 256-bit Data Encryption Keys (DEK)
/// securely backed by Android Keystore and iOS Keychain.
class DatabaseKeyService {
  final ISecureKeyStorage _secureStorage;

  DatabaseKeyService({ISecureKeyStorage? secureStorage})
      : _secureStorage = secureStorage ?? FlutterSecureKeyStorage();

  String _getKeyName(String localAccountKey) => 'eva_dek_$localAccountKey';

  /// Retrieves an existing DEK or generates a cryptographically secure 256-bit random key.
  Future<String> getOrCreateKey(String localAccountKey) async {
    final keyName = _getKeyName(localAccountKey);
    final existingKey = await _secureStorage.read(keyName);
    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    final newKey = _generateSecureRandomKey();
    await _secureStorage.write(keyName, newKey);
    return newKey;
  }

  /// Deletes the DEK associated with the local account key.
  Future<void> deleteKey(String localAccountKey) async {
    final keyName = _getKeyName(localAccountKey);
    await _secureStorage.delete(keyName);
  }

  /// Generates a cryptographically strong 32-byte (256-bit) hex-encoded key.
  String _generateSecureRandomKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}

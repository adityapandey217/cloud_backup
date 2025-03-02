import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Keys
  static const String accessKeyKey = 'access_key';
  static const String secretKeyKey = 'secret_key';
  static const String bucketNameKey = 'bucket_name';
  static const String regionKey = 'region';
  static const String folderNameKey = 'folder_name';

  // Getters
  static Future<String?> getAccessKey() => _storage.read(key: accessKeyKey);
  static Future<String?> getSecretKey() => _storage.read(key: secretKeyKey);
  static Future<String?> getBucketName() => _storage.read(key: bucketNameKey);
  static Future<String?> getRegion() => _storage.read(key: regionKey);
  static Future<String?> getFolderName() async {
    final value = await _storage.read(key: folderNameKey);
    return value ?? 'cloud_backup';
  }

  // Setters
  static Future<void> setAccessKey(String value) =>
      _storage.write(key: accessKeyKey, value: value);
  static Future<void> setSecretKey(String value) =>
      _storage.write(key: secretKeyKey, value: value);
  static Future<void> setBucketName(String value) =>
      _storage.write(key: bucketNameKey, value: value);
  static Future<void> setRegion(String value) =>
      _storage.write(key: regionKey, value: value);
  static Future<void> setFolderName(String value) =>
      _storage.write(key: folderNameKey, value: value);

  // Check if credentials exist
  static Future<bool> hasCredentials() async {
    final accessKey = await getAccessKey();
    final secretKey = await getSecretKey();
    final bucketName = await getBucketName();
    final region = await getRegion();

    return accessKey != null &&
        secretKey != null &&
        bucketName != null &&
        region != null;
  }

  // Clear all secure storage
  static Future<void> clearAll() => _storage.deleteAll();
}

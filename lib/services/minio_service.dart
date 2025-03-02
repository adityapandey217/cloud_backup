import 'dart:io';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'package:minio/models.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:cloud_backup/services/secure_storage_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_backup/models/media_item.dart';
import 'package:http/http.dart' as http;

class MinioService {
  static final MinioService _instance = MinioService._internal();
  factory MinioService() => _instance;
  MinioService._internal();

  Minio? _minio;
  bool _initialized = false;
  String? _bucketName;
  String? _folderName;

  // Initialize the Minio client with credentials from secure storage
  Future<bool> initialize() async {
    if (_initialized && _minio != null) return true;

    try {
      final accessKey = await SecureStorageService.getAccessKey();
      final secretKey = await SecureStorageService.getSecretKey();
      final bucketName = await SecureStorageService.getBucketName();
      final region = await SecureStorageService.getRegion();
      final folderName = await SecureStorageService.getFolderName();

      if (accessKey == null ||
          secretKey == null ||
          bucketName == null ||
          region == null) {
        debugPrint('MinioService: Missing credentials');
        return false;
      }

      _bucketName = bucketName;
      _folderName = folderName ?? 'cloud_backup';

      final endpoint = '$region.digitaloceanspaces.com';

      _minio = Minio(
        endPoint: endpoint,
        accessKey: accessKey,
        secretKey: secretKey,
        useSSL: true,
        region: region,
      );

      // Check if the bucket exists
      try {
        await _minio!.bucketExists(_bucketName!);
        _initialized = true;
        return true;
      } catch (e) {
        debugPrint('MinioService: Bucket check failed: $e');
        return false;
      }
    } catch (e) {
      debugPrint('MinioService: Initialization failed: $e');
      return false;
    }
  }

  // Updated method to organize by album
  Future<UploadResult?> uploadFile(File file,
      {String? customKey, String? albumName}) async {
    if (!await initialize()) {
      return null;
    }

    try {
      // Generate a unique key for the file
      final fileName = path.basename(file.path);

      // Use custom key if provided, otherwise generate a key based on file name and timestamp
      String objectKey = customKey ?? _generateObjectKey(fileName);

      // If albumName is provided, use it as a folder
      if (albumName != null && albumName.isNotEmpty) {
        albumName = _sanitizeFolderName(albumName);
        objectKey = '$albumName/$objectKey';
      }

      // Full path in bucket including the folder
      final fullObjectKey = '$_folderName/$objectKey';

      debugPrint('Uploading file to $fullObjectKey');

      // Start upload
      final etag = await _minio!.fPutObject(
        _bucketName!,
        fullObjectKey,
        file.path,
      );

      // Construct the public URL
      // Note: This assumes your bucket is configured for public access
      final region = await SecureStorageService.getRegion();
      final publicUrl =
          'https://$_bucketName.$region.digitaloceanspaces.com/$fullObjectKey';

      return UploadResult(
        etag: etag,
        objectKey: fullObjectKey,
        publicUrl: publicUrl,
      );
    } catch (e) {
      debugPrint('MinioService: Upload failed: $e');
      return null;
    }
  }

  // Check if an object exists
  Future<bool> objectExists(String objectKey) async {
    if (!await initialize()) {
      return false;
    }

    try {
      final fullObjectKey = '$_folderName/$objectKey';
      await _minio!.statObject(_bucketName!, fullObjectKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Download a file from the bucket
  Future<File?> downloadFile(String objectKey) async {
    if (!await initialize()) {
      return null;
    }

    try {
      // Create a temporary file to store the downloaded content
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(objectKey);
      final localFile = File('${tempDir.path}/$fileName');

      final fullObjectKey = '$_folderName/$objectKey';

      await _minio!.fGetObject(_bucketName!, fullObjectKey, localFile.path);

      return localFile;
    } catch (e) {
      debugPrint('MinioService: Download failed: $e');
      return null;
    }
  }

  // List objects in the bucket with pagination support
  Future<ObjectListResult> listObjects({
    int maxKeys = 1000,
    String? prefix,
    String? continuationToken,
  }) async {
    if (!await initialize()) {
      return ObjectListResult(items: [], hasMore: false);
    }

    try {
      final folderPrefix = prefix ?? '$_folderName/';
      final List<Map<String, dynamic>> objects = [];
      bool hasMore = false;
      String? nextContinuationToken;

      // This is where the real pagination would happen with the Minio SDK
      final stream = _minio!.listObjects(
        _bucketName!,
        prefix: folderPrefix,
        recursive: true,
        // Remove the delimiter parameter, as it's not supported in this context
      );

      int count = 0;

      await for (var events in stream) {
        for (var obj in events.objects) {
          // Skip if this is a directory
          if (obj.key?.endsWith('/') ?? false) continue;

          objects.add({
            'key': obj.key ?? '',
            'size': obj.size ?? 0,
            'etag': obj.eTag ?? '',
            'lastModified': obj.lastModified?.toIso8601String() ??
                DateTime.now().toIso8601String(),
          });

          count++;
          if (count >= maxKeys) {
            hasMore = true;
            break;
          }
        }

        if (count >= maxKeys) break;
      }

      return ObjectListResult(
        items: objects,
        hasMore: hasMore,
        nextContinuationToken: nextContinuationToken,
      );
    } catch (e) {
      debugPrint('MinioService: List objects failed: $e');
      return ObjectListResult(items: [], hasMore: false);
    }
  }

  // Download an object to a specific file path
  Future<File> downloadObject(String objectKey, String filePath) async {
    if (!await initialize()) {
      throw Exception('Failed to initialize Minio service');
    }

    try {
      // Make sure the directory exists
      final dir = Directory(path.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await _minio!.fGetObject(_bucketName!, objectKey, filePath);
      return File(filePath);
    } catch (e) {
      debugPrint('MinioService: Download failed: $e');
      throw Exception('Failed to download object: $e');
    }
  }

  // List folders (albums) in the bucket
  Future<List<String>> listFolders() async {
    if (!await initialize()) {
      return [];
    }

    try {
      final Set<String> folders = {};

      // First approach: list objects with prefix to determine folder structure
      final stream = _minio!.listObjects(
        _bucketName!,
        prefix: _folderName!,
        recursive: false,
      );

      await for (var events in stream) {
        // Instead of using commonPrefixes (which doesn't exist),
        // we'll infer the folders from the keys of objects
        for (var obj in events.objects) {
          final key = obj.key;
          if (key == null) continue;

          // Skip the main folder itself
          if (key == _folderName || key == '$_folderName/') continue;

          // Check if this looks like a directory marker
          if (key.endsWith('/')) {
            final parts = key.split('/');
            if (parts.length >= 2) {
              // Get the folder name (second-to-last part)
              final folderIndex = parts.length - 2;
              if (folderIndex >= 0 && parts[folderIndex].isNotEmpty) {
                folders.add(parts[folderIndex]);
              }
            }
            continue;
          }

          // Check if this is a file within a subfolder
          final parts = key.split('/');
          if (parts.length >= 3) {
            // bucket/folderName/albumName/file
            folders.add(parts[parts.length - 2]);
          }
        }
      }

      // Second approach: list objects recursively to find all folders
      final recursiveStream = _minio!.listObjects(
        _bucketName!,
        prefix: _folderName!,
        recursive: true,
      );

      await for (var events in recursiveStream) {
        for (var obj in events.objects) {
          final key = obj.key;
          if (key == null) continue;

          // Extract folders from the path
          final parts = key.split('/');
          if (parts.length >= 3) {
            // At least bucket/folderName/albumName
            // The folder is the part after _folderName
            int folderIndex = -1;
            for (int i = 0; i < parts.length; i++) {
              if (parts[i] == _folderName && i < parts.length - 1) {
                folderIndex = i + 1;
                break;
              }
            }

            if (folderIndex >= 0 && folderIndex < parts.length) {
              final folderName = parts[folderIndex];
              if (folderName.isNotEmpty) {
                folders.add(folderName);
              }
            }
          }
        }
      }

      return folders.toList();
    } catch (e) {
      debugPrint('MinioService: List folders failed: $e');
      return [];
    }
  }

  // Delete an object from the bucket
  Future<bool> deleteObject(String objectKey) async {
    if (!await initialize()) {
      return false;
    }

    try {
      final fullObjectKey = '$_folderName/$objectKey';
      await _minio!.removeObject(_bucketName!, fullObjectKey);
      return true;
    } catch (e) {
      debugPrint('MinioService: Delete failed: $e');
      return false;
    }
  }

  // Generate a unique object key for a file
  String _generateObjectKey(String fileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = md5.convert(utf8.encode(timestamp + fileName)).toString();
    final extension = path.extension(fileName);
    return '$random$extension';
  }

  // Sanitize folder name to be safe for S3 keys
  String _sanitizeFolderName(String folderName) {
    // Replace spaces, special chars that might cause issues
    return folderName.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w\s-]'), '');
  }

  // Test the connection to the bucket
  Future<bool> testConnection() async {
    return await initialize();
  }
}

class UploadResult {
  final String etag;
  final String objectKey;
  final String publicUrl;

  UploadResult({
    required this.etag,
    required this.objectKey,
    required this.publicUrl,
  });
}

class ObjectListResult {
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final String? nextContinuationToken;

  ObjectListResult({
    required this.items,
    required this.hasMore,
    this.nextContinuationToken,
  });
}

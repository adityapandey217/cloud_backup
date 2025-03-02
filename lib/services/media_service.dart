import 'dart:io';
import 'package:cloud_backup/models/cloud_media_item.dart';
import 'package:cloud_backup/models/media_item.dart';
import 'package:cloud_backup/services/album_service.dart';
import 'package:cloud_backup/services/minio_service.dart';
import 'package:cloud_backup/services/secure_storage_service.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final AlbumService _albumService = AlbumService();
  final MinioService _minioService = MinioService();

  Map<String, String> _backedUpFileMap = {}; // Map of local ID -> cloud key
  bool _hasLoadedBackupData = false;

  // Initialize and load backed up file references
  Future<void> _initBackupData() async {
    if (_hasLoadedBackupData) return;

    final prefs = await SharedPreferences.getInstance();
    final backedUpMapJson = prefs.getString('backed_up_file_map') ?? '{}';
    try {
      final Map<String, dynamic> jsonMap = json.decode(backedUpMapJson);
      _backedUpFileMap = jsonMap.map((k, v) => MapEntry(k, v.toString()));
      _hasLoadedBackupData = true;
    } catch (e) {
      debugPrint('Error loading backup data: $e');
      _backedUpFileMap = {};
    }
  }

  // Save the backed up file references
  Future<void> _saveBackupData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backed_up_file_map', json.encode(_backedUpFileMap));
  }

  // Mark a file as backed up
  Future<bool> markFileAsBackedUp(String localId, String cloudKey) async {
    await _initBackupData();
    _backedUpFileMap[localId] = cloudKey;
    await _saveBackupData();
    return true;
  }

  // Check if a file is backed up
  Future<bool> isFileBackedUp(String localId) async {
    await _initBackupData();
    return _backedUpFileMap.containsKey(localId);
  }

  // Mark a file as backed up with actual S3 upload
  Future<bool> backupFile(MediaItem item) async {
    try {
      // Get the actual file from the asset
      final file = await item.getFile();
      if (file == null) {
        debugPrint('MediaService: Failed to get file for asset ${item.id}');
        return false;
      }

      // Upload to S3
      final uploadResult = await _minioService.uploadFile(
        file,
        customKey: 'media_${item.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (uploadResult == null) {
        debugPrint('MediaService: Upload failed for asset ${item.id}');
        return false;
      }

      // Mark as backed up locally with the cloud key
      await markFileAsBackedUp(item.id, uploadResult.objectKey);

      debugPrint(
          'MediaService: Backed up ${item.id} to ${uploadResult.objectKey}');
      return true;
    } catch (e) {
      debugPrint('MediaService: Error backing up file: $e');
      return false;
    }
  }

  // Backup multiple files in sequence
  Future<Map<String, bool>> backupMultipleFiles(List<MediaItem> items) async {
    final Map<String, bool> results = {};

    for (final item in items) {
      // Skip if already backed up
      if (item.isBackedUp) {
        results[item.id] = true;
        continue;
      }

      final success = await backupFile(item);
      results[item.id] = success;
    }

    return results;
  }

  // Load all media items from device (paginated)
  Future<List<MediaItem>> loadAllMedia(
      {int page = 0, int pageSize = 50}) async {
    // Check permissions first
    final permitted = await _albumService.requestPermission();
    if (!permitted) return [];

    try {
      // Get the "All" album that includes both photos and videos
      final allAlbum = await PhotoManager.getAssetPathList(
          type: RequestType.all, // Use common to get both images and videos
          hasAll: true);

      if (allAlbum.isEmpty) return [];

      final recentAlbum = allAlbum.first;
      final assets =
          await recentAlbum.getAssetListPaged(page: page, size: pageSize);

      // Initialize backup data
      await _initBackupData();

      return assets.map((asset) {
        final isBackedUp = _backedUpFileMap.containsKey(asset.id);
        final cloudKey = isBackedUp ? _backedUpFileMap[asset.id] : null;

        return MediaItem(
          asset: asset,
          isBackedUp: isBackedUp,
          cloudKey: cloudKey,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading all media: $e');
      return [];
    }
  }

  // Load media items from a specific album
  Future<List<MediaItem>> loadAlbumMedia(String albumId,
      {int page = 0, int pageSize = 50}) async {
    try {
      final assets =
          await _albumService.getPhotos(albumId, page: page, limit: pageSize);

      // Initialize backup data
      await _initBackupData();

      return assets.map((asset) {
        final isBackedUp = _backedUpFileMap.containsKey(asset.id);
        final cloudKey = isBackedUp ? _backedUpFileMap[asset.id] : null;

        return MediaItem(
          asset: asset,
          isBackedUp: isBackedUp,
          cloudKey: cloudKey,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading album media: $e');
      return [];
    }
  }

  // Group media items by date
  Map<String, List<MediaItem>> groupMediaByDate(List<MediaItem> media) {
    final Map<String, List<MediaItem>> grouped = {};

    for (final item in media) {
      final dateKey = item.dateKey;
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(item);
    }

    return grouped;
  }

  // For demonstration purposes - set some items as backed up
  Future<void> simulateBackupStatus() async {
    final allMedia = await loadAllMedia(pageSize: 200);

    // Mark random items as backed up for demonstration
    for (var i = 0; i < allMedia.length; i++) {
      if (i % 3 == 0) {
        // Mark roughly a third of items as backed up
        final item = allMedia[i];
        await markFileAsBackedUp(item.id, 'simulated_cloud_key_${item.id}');
      }
    }
  }

  // Add new methods for handling cloud-only media

  // Load media that exists only in cloud (not local)
  Future<CloudMediaResult> loadCloudOnlyMedia(
      {String? continuationToken}) async {
    try {
      // First, get all cloud objects
      final objects = await _minioService.listObjects(
          maxKeys: 1000, continuationToken: continuationToken);

      // Get all local media IDs for comparison
      await _initBackupData();
      final localMediaIds = _backedUpFileMap.values.toSet();

      // Get region and bucket for URL generation
      final region = await SecureStorageService.getRegion() ?? '';
      final bucket = await SecureStorageService.getBucketName() ?? '';

      // Filter objects that don't have a corresponding local file
      final List<CloudMediaItem> cloudOnlyItems = [];

      for (final obj in objects.items) {
        // Skip if this object has a local counterpart
        if (localMediaIds.contains(obj['key'])) {
          continue;
        }

        // Create CloudMediaItem
        cloudOnlyItems.add(CloudMediaItem.fromMinioObject(obj, bucket, region));
      }

      return CloudMediaResult(
        items: cloudOnlyItems,
        hasMore: objects.hasMore,
        nextContinuationToken: objects.nextContinuationToken,
      );
    } catch (e) {
      debugPrint('Error loading cloud-only media: $e');
      return CloudMediaResult(items: [], hasMore: false);
    }
  }

  // Download a cloud item to local storage
  Future<File?> downloadCloudItem(CloudMediaItem item) async {
    try {
      // Create downloads directory if it doesn't exist
      final downloadsDir = await getApplicationDocumentsDirectory();
      final cloudBackupDir =
          Directory('${downloadsDir.path}/cloud_backup_downloads');
      if (!await cloudBackupDir.exists()) {
        await cloudBackupDir.create(recursive: true);
      }

      // Download the file
      final file = File('${cloudBackupDir.path}/${item.fileName}');

      // First try using MinioService
      try {
        return await _minioService.downloadObject(item.objectKey, file.path);
      } catch (e) {
        // If that fails, try direct HTTP download from public URL
        final response = await http.get(Uri.parse(item.fullUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
          return file;
        }
      }
    } catch (e) {
      debugPrint('Error downloading cloud item: $e');
    }
    return null;
  }

  // Delete a cloud item
  Future<bool> deleteCloudItem(CloudMediaItem item) async {
    try {
      return await _minioService.deleteObject(item.objectKey);
    } catch (e) {
      debugPrint('Error deleting cloud item: $e');
      return false;
    }
  }
}

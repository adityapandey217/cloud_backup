import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class AlbumService {
  // Singleton instance
  static final AlbumService _instance = AlbumService._internal();
  factory AlbumService() => _instance;
  AlbumService._internal();

  // Cache for album data
  List<AssetPathEntity>? _albums;
  List<AlbumData> _albumData = [];
  DateTime _lastFetched = DateTime(1970);

  // Check and request permissions
  Future<bool> requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      return true;
    }

    // For Android 13+, request specific photo permissions
    if (Platform.isAndroid) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }

    // For iOS, we already tried with PhotoManager
    return false;
  }

  // Get all albums with photos and videos
  Future<List<AlbumData>> getAlbums({bool forceRefresh = false}) async {
    // Check if we need to refresh the data
    final now = DateTime.now();
    final cacheExpired = now.difference(_lastFetched).inMinutes > 5;

    if (_albumData.isNotEmpty && !forceRefresh && !cacheExpired) {
      return _albumData;
    }

    final permitted = await requestPermission();
    if (!permitted) {
      return [];
    }

    // Get all albums with both images and videos
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // Use common to get both images and videos
      hasAll: true,
    );

    _albums = albums;
    _albumData = [];

    // Convert to our model
    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count > 0) {
        _albumData.add(AlbumData(
          id: album.id,
          name: album.name,
          count: count,
        ));
      }
    }

    _lastFetched = now;
    return _albumData;
  }

  // Get photos from a specific album
  Future<List<AssetEntity>> getPhotos(String albumId,
      {int limit = 50, int page = 0}) async {
    if (_albums == null) {
      await getAlbums();
    }

    final album = _albums?.firstWhere((album) => album.id == albumId);

    if (album == null) {
      return [];
    }

    final assets = await album.getAssetListPaged(page: page, size: limit);
    return assets;
  }

  // Get the number of photos in an album
  Future<int> getPhotoCount(String albumId) async {
    if (_albums == null) {
      await getAlbums();
    }

    final album = _albums?.firstWhere((album) => album.id == albumId,
        orElse: () => null as AssetPathEntity);

    if (album == null) {
      return 0;
    }

    return await album.assetCountAsync;
  }
}

// Simple model for album data
class AlbumData {
  final String id;
  final String name;
  final int count;

  AlbumData({required this.id, required this.name, required this.count});

  @override
  String toString() => name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'count': count,
      };

  static AlbumData fromJson(Map<String, dynamic> json) => AlbumData(
        id: json['id'],
        name: json['name'],
        count: json['count'],
      );
}

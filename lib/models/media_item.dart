import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class MediaItem {
  final AssetEntity asset;
  final bool isBackedUp;
  final String? cloudKey;

  MediaItem({
    required this.asset,
    this.isBackedUp = false,
    this.cloudKey,
  });

  DateTime get createDateTime => asset.createDateTime;
  String get id => asset.id;
  bool get isVideo => asset.type == AssetType.video;
  bool get isImage => asset.type == AssetType.image;

  // Get album name from path
  String get albumName {
    final path = asset.relativePath;
    if (path == null || path.isEmpty) return 'Unknown';

    // Extract album name from path
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.last : 'Unknown';
  }

  // For grouping by date (YYYY-MM-DD)
  String get dateKey {
    final date = createDateTime;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // For displaying the date
  String get formattedDate {
    final date = createDateTime;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return '${_getMonth(date.month)} ${date.day}, ${date.year}';
    }
  }

  // Helper method to get thumbnail image
  Widget thumbnailWidget({
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    int thumbSize = 300,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image(
        image: AssetEntityImageProvider(
          asset,
          isOriginal: false,
          thumbnailSize: ThumbnailSize.square(thumbSize),
          thumbnailFormat: ThumbnailFormat.jpeg,
        ),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          // Show a more descriptive error icon based on media type
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: Icon(
              isVideo ? Icons.video_library : Icons.broken_image,
              color: Colors.grey[600],
              size: 40,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }

  // Get the actual file
  Future<File?> getFile() async {
    return await asset.file;
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}

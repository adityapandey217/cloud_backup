import 'package:intl/intl.dart';

class CloudMediaItem {
  final String id;
  final String fileName;
  final String folderName;
  final String objectKey;
  final String fullUrl;
  final String thumbnailUrl;
  final bool isVideo;
  final int size;
  final DateTime uploadDate;

  CloudMediaItem({
    required this.id,
    required this.fileName,
    required this.folderName,
    required this.objectKey,
    required this.fullUrl,
    required this.thumbnailUrl,
    required this.isVideo,
    required this.size,
    required this.uploadDate,
  });

  // Factory method to create from Minio object response
  factory CloudMediaItem.fromMinioObject(
      Map<String, dynamic> obj, String bucketName, String region) {
    // Extract folder and file name from key
    final key = obj['key'] as String;
    final keyParts = key.split('/');
    final fileName = keyParts.length > 1 ? keyParts.last : key;
    final folderName =
        keyParts.length > 1 ? keyParts[keyParts.length - 2] : 'Root';

    // Determine if it's a video by file extension
    final isVideo = _isVideoFile(fileName);

    // Generate URLs
    final fullUrl = 'https://$bucketName.$region.digitaloceanspaces.com/$key';

    // For thumbnail, if it's an image, we can use the same URL
    // For videos, we'd need to generate a thumbnail or use a placeholder
    final thumbnailUrl = isVideo
        ? 'https://$bucketName.$region.digitaloceanspaces.com/thumbnails/$key.jpg'
        : fullUrl;

    // Parse the date string to DateTime
    DateTime uploadDate;
    try {
      final lastModified = obj['lastModified'] as String?;
      if (lastModified != null) {
        uploadDate = DateTime.parse(lastModified);
      } else {
        uploadDate = DateTime.now();
      }
    } catch (e) {
      uploadDate = DateTime.now();
    }

    return CloudMediaItem(
      id: key,
      fileName: fileName,
      folderName: folderName,
      objectKey: key,
      fullUrl: fullUrl,
      thumbnailUrl: thumbnailUrl,
      isVideo: isVideo,
      size: obj['size'] as int? ?? 0,
      uploadDate: uploadDate,
    );
  }

  // Format file size to human-readable format
  String get formattedSize {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double s = size.toDouble();
    while (s >= 1024 && i < suffixes.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Format upload date for display
  String get uploadDateFormatted {
    return DateFormat('MMM d, yyyy').format(uploadDate);
  }

  // Determine if file is a video by extension
  static bool _isVideoFile(String fileName) {
    if (fileName == null) return false;

    final videoExtensions = [
      '.mp4',
      '.mov',
      '.avi',
      '.wmv',
      '.flv',
      '.mkv',
      '.webm',
      '.m4v',
      '.3gp'
    ];
    final lowerCaseName = fileName.toLowerCase();
    return videoExtensions.any((ext) => lowerCaseName.endsWith(ext));
  }
}

class CloudMediaResult {
  final List<CloudMediaItem> items;
  final bool hasMore;
  final String? nextContinuationToken;

  CloudMediaResult({
    required this.items,
    required this.hasMore,
    this.nextContinuationToken,
  });
}

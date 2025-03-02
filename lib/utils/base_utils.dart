import 'package:flutter/foundation.dart';

class BaseUtils {
  // Singleton pattern
  static final BaseUtils _instance = BaseUtils._internal();
  factory BaseUtils() => _instance;
  BaseUtils._internal();

  // Format duration for displaying video length
  String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final hours = duration.inHours;
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return '$hours:$minutes:$seconds';
    } else {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return '$minutes:$seconds';
    }
  }

  // Safe conversion of video duration
  String safeFormatVideoDuration(Duration? duration) {
    if (duration == null) {
      return '00:00';
    }
    return formatDuration(duration);
  }

  // Safely get the type of asset as string
  String getAssetTypeString(int? type) {
    switch (type) {
      case 1:
        return 'Image';
      case 2:
        return 'Video';
      case 3:
        return 'Audio';
      default:
        return 'Unknown';
    }
  }

  // Log error safely
  void logError(String message, [dynamic error]) {
    try {
      debugPrint('ERROR: $message');
      if (error != null) {
        debugPrint(error.toString());
      }
    } catch (e) {
      // Fallback if even logging fails
    }
  }
}

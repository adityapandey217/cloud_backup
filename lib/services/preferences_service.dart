import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PreferencesService {
  static late SharedPreferences _prefs;

  // Keys
  static const String autoBackupKey = 'auto_backup';
  static const String wifiOnlyKey = 'wifi_only';
  static const String includeVideosKey = 'include_videos';
  static const String backupIntervalKey = 'backup_interval';
  static const String selectedAlbumIdsKey = 'selected_album_ids';
  static const String albumNamesMapKey = 'album_names_map';
  static const String lastBackupTimeKey = 'last_backup_time';
  static const String keyRecentBackups = 'recent_backups';

  // Initialize shared preferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Getters
  static bool getAutoBackup() => _prefs.getBool(autoBackupKey) ?? true;
  static bool getWifiOnly() => _prefs.getBool(wifiOnlyKey) ?? true;
  static bool getIncludeVideos() => _prefs.getBool(includeVideosKey) ?? false;
  static int getBackupInterval() => _prefs.getInt(backupIntervalKey) ?? 24;

  static List<String> getSelectedAlbumIds() =>
      _prefs.getStringList(selectedAlbumIdsKey) ?? [];

  static Map<String, String> getAlbumNamesMap() {
    final String? jsonString = _prefs.getString(albumNamesMapKey);
    if (jsonString == null) return {};

    try {
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      return jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return {};
    }
  }

  static DateTime? getLastBackupTime() {
    final long = _prefs.getInt(lastBackupTimeKey);
    return long != null ? DateTime.fromMillisecondsSinceEpoch(long) : null;
  }

  static List<Map<String, dynamic>> getRecentBackups() {
    final jsonStr = _prefs.getString(keyRecentBackups);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> data = json.decode(jsonStr);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // Setters
  static Future<bool> setAutoBackup(bool value) =>
      _prefs.setBool(autoBackupKey, value);
  static Future<bool> setWifiOnly(bool value) =>
      _prefs.setBool(wifiOnlyKey, value);
  static Future<bool> setIncludeVideos(bool value) =>
      _prefs.setBool(includeVideosKey, value);
  static Future<bool> setBackupInterval(int hours) =>
      _prefs.setInt(backupIntervalKey, hours);

  static Future<bool> setSelectedAlbumIds(List<String> albumIds) =>
      _prefs.setStringList(selectedAlbumIdsKey, albumIds);

  static Future<bool> setAlbumNamesMap(Map<String, String> albumNamesMap) =>
      _prefs.setString(albumNamesMapKey, json.encode(albumNamesMap));

  static Future<bool> setLastBackupTime(DateTime time) =>
      _prefs.setInt(lastBackupTimeKey, time.millisecondsSinceEpoch);

  static Future<void> addRecentBackup(Map<String, dynamic> backup) async {
    final backups = getRecentBackups();

    // Add new backup at the beginning
    backups.insert(0, backup);

    // Limit to 20 most recent backups
    if (backups.length > 20) {
      backups.removeRange(20, backups.length);
    }

    // Save back to prefs
    await _prefs.setString(keyRecentBackups, json.encode(backups));
  }

  static Future<void> clearRecentBackups() async {
    await _prefs.remove(keyRecentBackups);
  }

  // Keep backward compatibility with old apps
  static List<String> getSelectedAlbums() {
    final ids = getSelectedAlbumIds();
    if (ids.isEmpty) {
      return ['Camera', 'Screenshots', 'Downloads']; // Default
    }

    final namesMap = getAlbumNamesMap();
    return ids.map((id) => namesMap[id] ?? id).toList();
  }

  static Future<bool> setSelectedAlbums(List<String> albums) {
    // This is just a stub for backward compatibility
    // In the new version, we store IDs instead of names
    return Future.value(true);
  }

  // Clear all preferences
  static Future<bool> clearAll() => _prefs.clear();
}

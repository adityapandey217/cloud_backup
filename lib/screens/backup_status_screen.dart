import 'package:flutter/material.dart';
import 'package:cloud_backup/services/preferences_service.dart';
import 'package:cloud_backup/services/album_service.dart';
import 'package:cloud_backup/services/secure_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_backup/models/media_item.dart';
import 'package:cloud_backup/services/media_service.dart';

class BackupStatusScreen extends StatefulWidget {
  const BackupStatusScreen({super.key});

  @override
  State<BackupStatusScreen> createState() => _BackupStatusScreenState();
}

class _BackupStatusScreenState extends State<BackupStatusScreen> {
  bool _isBackupRunning = false;
  int _totalFiles = 0;
  int _uploadedFiles = 0;
  List<Map<String, dynamic>> _recentBackups = [];
  bool _isLoading = true;
  List<AlbumData> _selectedAlbums = [];
  DateTime? _lastBackupTime;
  final MediaService _mediaService = MediaService();

  @override
  void initState() {
    super.initState();
    _loadBackupStatus();
  }

  Future<void> _loadBackupStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load last backup time
      _lastBackupTime = PreferencesService.getLastBackupTime();

      // Load recent backups from preferences
      _recentBackups = PreferencesService.getRecentBackups();

      // Check if we have credentials
      final hasCredentials = await SecureStorageService.hasCredentials();
      if (!hasCredentials) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Load selected albums
      final selectedAlbumIds = PreferencesService.getSelectedAlbumIds();
      if (selectedAlbumIds.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get all available albums
      final albumService = AlbumService();
      final albums = await albumService.getAlbums();

      // Filter to get only selected albums
      _selectedAlbums =
          albums.where((album) => selectedAlbumIds.contains(album.id)).toList();

      // Calculate total files
      _totalFiles =
          _selectedAlbums.fold(0, (prev, album) => prev + album.count);
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load backup status: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startBackup() async {
    // Check if selected albums exist and have photos
    if (_selectedAlbums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select albums to backup in Settings')),
      );
      return;
    }

    setState(() {
      _isBackupRunning = true;
      _uploadedFiles = 0;
    });

    try {
      // Load all media to backup from selected albums
      final selectedAlbumIds = PreferencesService.getSelectedAlbumIds();
      List<MediaItem> allMedia = [];
      int processedAlbums = 0;

      // Loop through each selected album
      for (final album in _selectedAlbums) {
        if (!_isBackupRunning) break; // Check if canceled

        // Load media from this album
        final albumMedia = await _mediaService.loadAlbumMedia(
          album.id,
          pageSize: 1000, // A larger size to load more at once
        );

        allMedia.addAll(albumMedia.where((item) => !item.isBackedUp));
        processedAlbums++;

        // Update progress
        setState(() {
          _uploadedFiles =
              (processedAlbums / _selectedAlbums.length * 20).round();
        });
      }

      // Calculate total files to backup
      _totalFiles = allMedia.length;

      if (_totalFiles == 0) {
        setState(() {
          _isBackupRunning = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All files are already backed up')),
          );
        }
        return;
      }

      // Start actual backups
      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < allMedia.length; i++) {
        if (!_isBackupRunning) break; // Check if canceled

        final item = allMedia[i];
        final success = await _mediaService.backupFile(item);

        if (success) {
          successCount++;
        } else {
          failCount++;
        }

        // Update progress
        setState(() {
          _uploadedFiles = ((i + 1) / _totalFiles * 100).round();
        });
      }

      // Backup complete
      if (mounted && _isBackupRunning) {
        final now = DateTime.now();
        // Create backup record
        final backupRecord = {
          'album': _selectedAlbums.length > 1
              ? 'Multiple Albums'
              : _selectedAlbums[0].name,
          'date': DateFormat('MMM d, yyyy').format(now),
          'files': successCount,
          'timestamp': now.millisecondsSinceEpoch
        };

        setState(() {
          _uploadedFiles = _totalFiles;
          _isBackupRunning = false;
          _lastBackupTime = now;

          // Add to recent backups
          _recentBackups.insert(0, backupRecord);
        });

        // Save the backup time
        await PreferencesService.setLastBackupTime(now);

        // Save backup record to history
        await PreferencesService.addRecentBackup(backupRecord);

        // Show results
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Backup completed: $successCount successful, $failCount failed'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      // Handle error
      debugPrint('BackupStatusScreen: Error during backup: $e');

      if (mounted) {
        setState(() {
          _isBackupRunning = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup error: ${e.toString()}')),
        );
      }
    }
  }

  void _cancelBackup() {
    setState(() {
      _isBackupRunning = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup cancelled')),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackupStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBackupStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Backup Status Section
                      _buildStatusCard(),

                      const SizedBox(height: 24),

                      // Albums Ready for Backup Section (only when not backing up)
                      if (!_isBackupRunning && _selectedAlbums.isNotEmpty)
                        _buildAlbumsCard(),

                      const SizedBox(height: 24),

                      // Recent Backups Section
                      _buildRecentBackupsCard(),

                      // Extra space at bottom for better scrolling
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
      // Bottom Action Button
      floatingActionButton:
          (!_isLoading && !_isBackupRunning && _selectedAlbums.isNotEmpty)
              ? FloatingActionButton.extended(
                  onPressed: _startBackup,
                  icon: const Icon(Icons.backup),
                  label: const Text('START BACKUP'),
                )
              : null,
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child:
                      const Icon(Icons.cloud_upload, color: Colors.deepPurple),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Backup Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isBackupRunning)
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: _cancelBackup,
                    tooltip: 'Cancel Backup',
                  ),
              ],
            ),
            const Divider(height: 24),
            if (_isBackupRunning) ...[
              // Show progress during backup
              LinearProgressIndicator(
                value: _totalFiles > 0 ? _uploadedFiles / _totalFiles : 0,
                backgroundColor: Colors.grey.shade200,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Uploading: $_uploadedFiles of $_totalFiles files',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    '${(_totalFiles > 0 ? _uploadedFiles / _totalFiles * 100 : 0).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ] else if (_lastBackupTime != null) ...[
              // Show last backup time when not backing up
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Last Backup'),
                        Text(
                          _formatTimeAgo(_lastBackupTime!),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('HISTORY'),
                    onPressed: () {
                      // Scroll to history section
                      // Would be better implemented with proper scroll controller
                      // For now we'll just show a hint
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Scroll down to see backup history')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // No backups yet
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text('No backups performed yet'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.photo_library, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ready for Backup',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$_totalFiles files in ${_selectedAlbums.length} ${_selectedAlbums.length == 1 ? 'album' : 'albums'}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAlbums.map((album) {
                return Chip(
                  label: Text(album.name),
                  avatar: const Icon(Icons.photo_album, size: 16),
                  labelStyle: const TextStyle(fontSize: 13),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.grey.shade100,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBackupsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.history, color: Colors.blueAccent),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Backup History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_recentBackups.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showClearHistoryDialog(),
                    tooltip: 'Clear History',
                  )
              ],
            ),
          ),
          const Divider(height: 1),
          _recentBackups.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('No backup history found'),
                  ),
                )
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _recentBackups.length,
                  itemBuilder: (context, index) {
                    final backup = _recentBackups[index];

                    // Get date for timestamp to show relative date
                    final backupTime = DateTime.fromMillisecondsSinceEpoch(
                        backup['timestamp'] as int);
                    final timeAgo = _formatTimeAgo(backupTime);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        child: const Icon(Icons.cloud_done,
                            color: Colors.blueAccent),
                      ),
                      title: Text(backup['album'] as String),
                      subtitle: Text(
                          '${backup['date']} • ${backup['files']} files • $timeAgo'),
                      trailing: const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                    );
                  },
                ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Backup History'),
        content: const Text(
            'Are you sure you want to clear all backup history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PreferencesService.clearRecentBackups();
              if (mounted) {
                setState(() {
                  _recentBackups = [];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup history cleared')),
                );
              }
            },
            child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_backup/services/preferences_service.dart';
import 'package:cloud_backup/services/album_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoBackup = true;
  bool _wifiOnly = true;
  bool _includeVideos = false;
  List<String> _selectedAlbumIds = [];
  Map<String, String> _albumNameMap = {}; // Map album ID to album name
  int _backupInterval = 24; // hours
  bool _isLoading = true;
  bool _loadingAlbums = true;
  List<AlbumData> _availableAlbums = [];
  bool _allAlbumsSelected = false;
  bool _settingsChanged = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _loadingAlbums = true;
    });

    try {
      final albumService = AlbumService();
      final albums = await albumService.getAlbums(forceRefresh: true);

      setState(() {
        _availableAlbums = albums;
        _albumNameMap = {for (var album in albums) album.id: album.name};
        _loadingAlbums = false;

        // Check if all albums are selected
        _updateAllAlbumsSelectedState();
      });
    } catch (e) {
      setState(() {
        _loadingAlbums = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load albums: ${e.toString()}')),
        );
      }
    }
  }

  void _loadSettings() {
    setState(() {
      _isLoading = true;
      _settingsChanged = false; // Reset settings changed flag

      _autoBackup = PreferencesService.getAutoBackup();
      _wifiOnly = PreferencesService.getWifiOnly();
      _includeVideos = PreferencesService.getIncludeVideos();
      _backupInterval = PreferencesService.getBackupInterval();
      _selectedAlbumIds = PreferencesService.getSelectedAlbumIds();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    await PreferencesService.setAutoBackup(_autoBackup);
    await PreferencesService.setWifiOnly(_wifiOnly);
    await PreferencesService.setIncludeVideos(_includeVideos);
    await PreferencesService.setBackupInterval(_backupInterval);
    await PreferencesService.setSelectedAlbumIds(_selectedAlbumIds);

    // Also save album names map for reference
    final Map<String, String> albumMap = {};
    for (var album in _availableAlbums) {
      albumMap[album.id] = album.name;
    }
    await PreferencesService.setAlbumNamesMap(albumMap);

    setState(() {
      _isLoading = false;
      _settingsChanged = false; // Reset settings changed flag after saving
    });

    // Show a snackbar to confirm save
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _updateAllAlbumsSelectedState() {
    if (_availableAlbums.isEmpty) {
      _allAlbumsSelected = false;
      return;
    }

    // Check if all album IDs are in _selectedAlbumIds
    _allAlbumsSelected =
        _availableAlbums.every((album) => _selectedAlbumIds.contains(album.id));
  }

  void _toggleSelectAll(bool? value) {
    if (value == null) return;

    setState(() {
      if (value) {
        // Select all albums
        _selectedAlbumIds = _availableAlbums.map((album) => album.id).toList();
      } else {
        // Deselect all albums
        _selectedAlbumIds = [];
      }
      _allAlbumsSelected = value;
      _settingsChanged = true;
    });
  }

  // Called when any setting is changed to update the UI state
  void _markSettingsChanged() {
    setState(() {
      _settingsChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlbums,
            tooltip: 'Refresh Albums',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Auto Backup'),
                  subtitle: const Text('Automatically backup new photos'),
                  value: _autoBackup,
                  onChanged: (bool value) {
                    setState(() {
                      _autoBackup = value;
                      _settingsChanged = true;
                    });
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('WiFi Only'),
                  subtitle: const Text('Backup only when connected to WiFi'),
                  value: _wifiOnly,
                  onChanged: (bool value) {
                    setState(() {
                      _wifiOnly = value;
                      _settingsChanged = true;
                    });
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Include Videos'),
                  subtitle: const Text('Also backup video files'),
                  value: _includeVideos,
                  onChanged: (bool value) {
                    setState(() {
                      _includeVideos = value;
                      _settingsChanged = true;
                    });
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Backup Interval'),
                  subtitle: Text('Every $_backupInterval hours'),
                  trailing: DropdownButton<int>(
                    value: _backupInterval,
                    items: const [
                      DropdownMenuItem(value: 6, child: Text('6 hours')),
                      DropdownMenuItem(value: 12, child: Text('12 hours')),
                      DropdownMenuItem(value: 24, child: Text('24 hours')),
                      DropdownMenuItem(value: 48, child: Text('48 hours')),
                    ],
                    onChanged: (int? value) {
                      if (value != null) {
                        setState(() {
                          _backupInterval = value;
                          _settingsChanged = true;
                        });
                      }
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Albums to Backup'),
                  subtitle: const Text('Select which albums to include'),
                  trailing: _loadingAlbums
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                if (_loadingAlbums)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Loading albums...'),
                    ),
                  )
                else if (_availableAlbums.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child:
                          Text('No albums found. Tap refresh to scan again.'),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      child: CheckboxListTile(
                        title: const Text('Select All Albums'),
                        subtitle:
                            Text('${_availableAlbums.length} albums available'),
                        value: _allAlbumsSelected,
                        onChanged: _toggleSelectAll,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...buildAlbumCheckboxes(),
                ],
                const SizedBox(height: 80), // Space for FAB at the bottom
              ],
            ),
      // Add a floating action button for saving settings
      floatingActionButton: _settingsChanged
          ? FloatingActionButton.extended(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('SAVE'),
              backgroundColor: Theme.of(context).primaryColor,
            )
          : null,
    );
  }

  List<Widget> buildAlbumCheckboxes() {
    return _availableAlbums.map((album) {
      final isSelected = _selectedAlbumIds.contains(album.id);

      return CheckboxListTile(
        title: Text(album.name),
        subtitle: Text('${album.count} items'),
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              if (!_selectedAlbumIds.contains(album.id)) {
                _selectedAlbumIds.add(album.id);
              }
            } else {
              _selectedAlbumIds.remove(album.id);
            }
            _updateAllAlbumsSelectedState();
            _settingsChanged = true;
          });
        },
      );
    }).toList();
  }
}

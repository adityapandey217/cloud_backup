import 'package:cloud_backup/models/cloud_media_item.dart';
import 'package:cloud_backup/utils/base_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_backup/screens/account_setup_screen.dart';
import 'package:cloud_backup/screens/backup_status_screen.dart';
import 'package:cloud_backup/screens/settings_screen.dart';
import 'package:cloud_backup/screens/album_page.dart';
import 'package:cloud_backup/services/secure_storage_service.dart';
import 'package:cloud_backup/services/preferences_service.dart';
import 'package:cloud_backup/services/album_service.dart';
import 'package:cloud_backup/services/media_service.dart';
import 'package:cloud_backup/models/media_item.dart';
import 'package:photo_manager/photo_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    const HomePage(),
    const AccountSetupScreen(),
    const BackupStatusScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backup),
            label: 'Backup',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _hasCredentials = false;
  bool _isLoading = true;
  DateTime? _lastBackupTime;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this); // Changed from 2 to 3 tabs
    _checkCredentials();

    // For demonstration purposes - simulate some backed up items
    MediaService().simulateBackupStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkCredentials() async {
    final hasCredentials = await SecureStorageService.hasCredentials();
    final lastBackupTime = PreferencesService.getLastBackupTime();

    if (mounted) {
      setState(() {
        _hasCredentials = hasCredentials;
        _lastBackupTime = lastBackupTime;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasCredentials) {
      return _buildSetupAccountPrompt();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Backup'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Media'),
            Tab(text: 'Albums'),
            Tab(text: 'Cloud Only'), // Added new tab
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AllMediaTab(),
          AlbumsTab(),
          CloudOnlyTab(), // Added new tab content
        ],
      ),
    );
  }

  Widget _buildSetupAccountPrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Backup'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Cloud Backup',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sync your photos to DigitalOcean Spaces',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            const Text(
              'Please set up your DigitalOcean account first',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate to account setup tab
                (context.findAncestorStateOfType<_HomeScreenState>()
                        as _HomeScreenState)
                    ._onItemTapped(1);
              },
              child: const Text('Set Up Account'),
            ),
          ],
        ),
      ),
    );
  }
}

class AllMediaTab extends StatefulWidget {
  const AllMediaTab({Key? key}) : super(key: key);

  @override
  State<AllMediaTab> createState() => _AllMediaTabState();
}

class _AllMediaTabState extends State<AllMediaTab>
    with AutomaticKeepAliveClientMixin {
  final MediaService _mediaService = MediaService();
  final List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 80;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500 &&
        !_isLoading &&
        _hasMore) {
      _loadMoreMedia();
    }
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final media = await _mediaService.loadAllMedia(
          page: _currentPage, pageSize: _pageSize);

      setState(() {
        _mediaItems.clear();
        _mediaItems.addAll(media);
        _isLoading = false;
        _hasMore = media.length == _pageSize;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load media: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadMoreMedia() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _currentPage++;
    });

    try {
      final media = await _mediaService.loadAllMedia(
          page: _currentPage, pageSize: _pageSize);

      setState(() {
        _mediaItems.addAll(media);
        _isLoading = false;
        _hasMore = media.length == _pageSize;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _mediaItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mediaItems.isEmpty) {
      return const Center(child: Text('No media found'));
    }

    // Group media by date
    final groupedMedia = _mediaService.groupMediaByDate(_mediaItems);
    final dateKeys = groupedMedia.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _loadMedia,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: dateKeys.length + (_isLoading && _hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= dateKeys.length) {
            // Loading indicator at the bottom
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final dateKey = dateKeys[index];
          final mediaList = groupedMedia[dateKey]!;
          final firstItem = mediaList.first;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  firstItem.formattedDate,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                ),
                itemCount: mediaList.length,
                itemBuilder: (context, i) {
                  final item = mediaList[i];
                  return _buildMediaTile(item);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMediaTile(MediaItem item) {
    return GestureDetector(
      onTap: () {
        _showMediaDetails(item);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media thumbnail
          item.thumbnailWidget(),

          // Video duration indicator
          if (item.isVideo)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      BaseUtils().formatDuration(item.asset.videoDuration),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // Backup status indicator
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isBackedUp ? Colors.green : Colors.red,
              ),
              child: Center(
                child: Icon(
                  item.isBackedUp ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaDetails(MediaItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media preview
                Container(
                  height: 300,
                  width: double.infinity,
                  color: Colors.black,
                  child: item.thumbnailWidget(
                    fit: BoxFit.contain,
                    thumbSize: 800,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        item.asset.title ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Details
                      _buildDetailRow('Date:', item.formattedDate),
                      _buildDetailRow('Size:',
                          '${(item.asset.size.width.toInt())} × ${(item.asset.size.height.toInt())}'),
                      _buildDetailRow(
                          'Type:', item.isVideo ? 'Video' : 'Image'),

                      if (item.isVideo)
                        _buildDetailRow(
                            'Duration:',
                            BaseUtils()
                                .formatDuration(item.asset.videoDuration)),

                      _buildDetailRow('Album:', item.albumName),
                      _buildDetailRow('Backup Status:',
                          item.isBackedUp ? 'Backed up' : 'Not backed up'),

                      const SizedBox(height: 24),

                      // Actions
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final success = await _mediaService.markFileAsBackedUp(
                                item.id,
                                'manual_backup_${DateTime.now().millisecondsSinceEpoch}');

                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'File marked as backed up'
                                      : 'Failed to mark file as backed up'),
                                ),
                              );
                              _loadMedia();
                            }
                          },
                          icon: const Icon(Icons.cloud_upload),
                          label: Text(item.isBackedUp
                              ? 'Backed up'
                              : 'Mark as backed up'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
}

class AlbumsTab extends StatefulWidget {
  const AlbumsTab({Key? key}) : super(key: key);

  @override
  State<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<AlbumsTab>
    with AutomaticKeepAliveClientMixin {
  final AlbumService _albumService = AlbumService();
  List<AlbumData> _albums = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final albums = await _albumService.getAlbums(forceRefresh: true);
      setState(() {
        _albums = albums;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load albums: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_albums.isEmpty) {
      return const Center(child: Text('No albums found'));
    }

    return RefreshIndicator(
      onRefresh: _loadAlbums,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final album = _albums[index];
          return _buildAlbumTile(album);
        },
      ),
    );
  }

  Widget _buildAlbumTile(AlbumData album) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumPage(
              albumId: album.id,
              albumName: album.name,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<List<AssetEntity>>(
                future: _albumService.getPhotos(album.id, limit: 1),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Icon(Icons.photo_album, color: Colors.grey),
                    );
                  }

                  // Create a MediaItem from the asset to use our helper method
                  return MediaItem(asset: snapshot.data![0])
                      .thumbnailWidget(thumbSize: 500);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${album.count} items',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class CloudOnlyTab extends StatefulWidget {
  const CloudOnlyTab({Key? key}) : super(key: key);

  @override
  State<CloudOnlyTab> createState() => _CloudOnlyTabState();
}

class _CloudOnlyTabState extends State<CloudOnlyTab>
    with AutomaticKeepAliveClientMixin {
  final MediaService _mediaService = MediaService();
  final List<CloudMediaItem> _cloudMedia = [];
  bool _isLoading = true;
  bool _hasMore = true;
  String? _nextContinuationToken;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCloudMedia();
  }

  Future<void> _loadCloudMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _mediaService.loadCloudOnlyMedia();

      setState(() {
        _cloudMedia.clear();
        _cloudMedia.addAll(result.items);
        _isLoading = false;
        _hasMore = result.hasMore;
        _nextContinuationToken = result.nextContinuationToken;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load cloud media: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadMoreCloudMedia() async {
    if (_isLoading || !_hasMore || _nextContinuationToken == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _mediaService.loadCloudOnlyMedia(
          continuationToken: _nextContinuationToken);

      setState(() {
        _cloudMedia.addAll(result.items);
        _isLoading = false;
        _hasMore = result.hasMore;
        _nextContinuationToken = result.nextContinuationToken;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _cloudMedia.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cloudMedia.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No cloud-only media found',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Items backed up but deleted locally will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCloudMedia,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // Group media by album (folder structure in cloud)
    final groupedByAlbum = _groupCloudMediaByAlbum();
    final albums = groupedByAlbum.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadCloudMedia,
      child: ListView.builder(
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          final mediaList = groupedByAlbum[album]!;

          return ExpansionTile(
            title: Text(album),
            leading: const Icon(Icons.folder),
            subtitle: Text('${mediaList.length} items'),
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: mediaList.length,
                itemBuilder: (context, i) {
                  return _buildCloudMediaTile(mediaList[i]);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // Group cloud media by album
  Map<String, List<CloudMediaItem>> _groupCloudMediaByAlbum() {
    final result = <String, List<CloudMediaItem>>{};

    for (final item in _cloudMedia) {
      final album = item.folderName;
      if (!result.containsKey(album)) {
        result[album] = [];
      }
      result[album]!.add(item);
    }

    return result;
  }

  Widget _buildCloudMediaTile(CloudMediaItem item) {
    return GestureDetector(
      onTap: () => _showCloudMediaDetails(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.thumbnailUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
                );
              },
            ),
          ),

          // Cloud indicator
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.8),
              ),
              child: const Center(
                child: Icon(
                  Icons.cloud,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),

          // If it's a video, show indicator
          if (item.isVideo)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.play_arrow, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Show details of a cloud media item
  void _showCloudMediaDetails(CloudMediaItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media preview
                Container(
                  height: 300,
                  width: double.infinity,
                  color: Colors.black,
                  child: Image.network(
                    item.fullUrl,
                    fit: BoxFit.contain,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        item.fileName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Details
                      _buildDetailRow(
                          'Type:', item.isVideo ? 'Video' : 'Image'),
                      _buildDetailRow('Album:', item.folderName),
                      _buildDetailRow('Backed up:', item.uploadDateFormatted),
                      _buildDetailRow('Status:', 'Available in cloud only'),
                      _buildDetailRow('Size:', item.formattedSize),

                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _downloadCloudMediaItem(item),
                              icon: const Icon(Icons.download),
                              label: const Text('Download'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _shareCloudMediaItem(item),
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _deleteCloudMediaItem(item),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('Delete from Cloud',
                              style: TextStyle(color: Colors.red)),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper method for detail rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Download media from cloud
  Future<void> _downloadCloudMediaItem(CloudMediaItem item) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Downloading'),
        content: LinearProgressIndicator(),
      ),
    );

    try {
      final file = await _mediaService.downloadCloudItem(item);

      // Close loading dialog
      Navigator.of(context).pop();

      if (file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File downloaded to ${file.path}'),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () {
                // Open the file using a method that would handle opening the file
                // This could use url_launcher, open_file, etc.
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download file')),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
  }

  // Share media from cloud
  Future<void> _shareCloudMediaItem(CloudMediaItem item) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing: ${item.fileName}')),
    );

    // Implement sharing functionality here
    // This could use url_launcher to share the public URL
    // or download the file first and then use share_plus
  }

  // Delete media from cloud
  Future<void> _deleteCloudMediaItem(CloudMediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cloud Media'),
        content: Text(
          'Are you sure you want to delete ${item.fileName} from the cloud? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _mediaService.deleteCloudItem(item);

      if (success) {
        // Remove from list
        setState(() {
          _cloudMedia.remove(item);
        });

        if (mounted) {
          Navigator.pop(context); // Close the bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File deleted successfully')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete file')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${e.toString()}')),
      );
    }
  }
}

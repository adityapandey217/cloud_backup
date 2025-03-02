import 'package:cloud_backup/utils/base_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_backup/models/media_item.dart';
import 'package:cloud_backup/services/media_service.dart';


class AlbumPage extends StatefulWidget {
  final String albumId;
  final String albumName;

  const AlbumPage({
    Key? key,
    required this.albumId,
    required this.albumName,
  }) : super(key: key);

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final MediaService _mediaService = MediaService();
  final List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 80;
  final ScrollController _scrollController = ScrollController();

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
      final media = await _mediaService.loadAlbumMedia(widget.albumId,
          page: _currentPage, pageSize: _pageSize);

      setState(() {
        _mediaItems.clear();
        _mediaItems.addAll(media);
        _isLoading = false;
        _hasMore = media.length == _pageSize;
        _currentPage = 0;
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
      final media = await _mediaService.loadAlbumMedia(widget.albumId,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albumName),
      ),
      body: _buildMediaGrid(),
    );
  }

  Widget _buildMediaGrid() {
    if (_isLoading && _mediaItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mediaItems.isEmpty) {
      return const Center(child: Text('No media found in this album'));
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
                      BaseUtils()
                          .safeFormatVideoDuration(item.asset.videoDuration),
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
                            BaseUtils().safeFormatVideoDuration(
                                item.asset.videoDuration)),

                      _buildDetailRow('Album:', widget.albumName),
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

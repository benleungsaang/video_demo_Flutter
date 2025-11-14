import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_demo/models/video.dart';
import 'package:video_demo/services/video_service.dart';
import 'dart:io';
import 'package:video_demo/pages/video_player_page.dart';
import 'package:video_demo/services/tag_search_service.dart';

class LocalVideosPage extends StatefulWidget {
  const LocalVideosPage({super.key});

  @override
  State<LocalVideosPage> createState() => _LocalVideosPageState();
}

class _LocalVideosPageState extends State<LocalVideosPage> {
  List<Video> _videos = [];
  List<Video> _filteredVideos = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  int _columnCount = 1;

  // 核心约束配置
  final double _maxImageHeight = 200; // 图片最大高度
  final double _maxSingleColumnWidth = 600; // 单列最大宽度
  final double _innerSpacing = 6; // 卡片内部元素间距
  final double _cardSpacing = 10; // 卡片之间的间距
  final double _cardPadding = 8; // 卡片内边距

  Future<void> _loadThumbnail(Video video) async {
    // 仅在缩略图不存在时生成，不阻塞UI
    if (video.thumbnailPath == null ||
        !await File(video.thumbnailPath!).exists()) {
      await VideoService.generateThumbnail(video);
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    loadVideos();
    VideoService.videosNotifier.addListener(_onVideosChanged);
  }

  void _onVideosChanged() {
    if (mounted) {
      setState(() {
        _videos = VideoService.getAllVideos();
        _filteredVideos = List.from(_videos);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    VideoService.videosNotifier.removeListener(_onVideosChanged);
    super.dispose();
  }

  void loadVideos() async {
    setState(() {
      isLoading = true;
    });

    final videoBox = Hive.box<Video>('videos');
    final videos = videoBox.values.toList();

    setState(() {
      _videos = videos;
      _filteredVideos = List.from(_videos);
      isLoading = false;
    });
  }

  void _performSearch() {
    final query = _searchController.text;
    setState(() {
      _filteredVideos = TagSearchService.searchVideos(query);
    });
  }

  void pickAndAddVideo() async {
    Video? video = await VideoService.pickSingleVideo();
    if (video != null) {
      await VideoService.saveVideo(video);
      loadVideos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加视频成功: ${video.name}')),
        );
      }
    }
  }

  String formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatTags(List<String> tags) {
    if (tags.isEmpty) return '';
    return tags.join('、');
  }

  Widget _buildVideoItem(Video video) {
    // 缩略图生成逻辑（仅触发不等待）
    if (video.thumbnailPath == null ||
        !File(video.thumbnailPath!).existsSync()) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadThumbnail(video));
    }

    // 根据列数动态调整文本大小
    final double titleSize =
        _columnCount == 1 ? 16 : (_columnCount == 2 ? 14 : 12);
    final double infoSize =
        _columnCount == 1 ? 12 : (_columnCount == 2 ? 11 : 10);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.zero, // 清除默认外边距
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerPage(video: video),
                ),
              );
              loadVideos();
            },
            child: Padding(
              padding: EdgeInsets.all(_cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // 高度由内容决定
                children: [
                  // 视频缩略图（居中显示）
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: _maxImageHeight,
                          maxWidth: constraints.maxWidth - _cardPadding * 2,
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: video.thumbnailPath != null &&
                                  File(video.thumbnailPath!).existsSync()
                              ? Image.file(
                                  File(video.thumbnailPath!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : const Center(
                                  child: Text(
                                    '缩略图待生成',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: _innerSpacing),

                  // 标题行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          video.name,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<int>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        padding: EdgeInsets.zero,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 1,
                            child: const Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text("删除"),
                              ],
                            ),
                            onTap: () async {
                              await Future.delayed(Duration.zero);
                              bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('确认删除'),
                                  content: Text('确定要删除视频 "${video.name}" 吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('删除'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await VideoService.deleteVideo(video);
                                loadVideos();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('已删除: ${video.name}')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 信息行（合并显示避免溢出）
                  Padding(
                    padding: EdgeInsets.only(top: _innerSpacing / 2),
                    child: Text(
                      [
                        '时长: ${formatDuration(video.duration)}',
                        '大小: ${_formatFileSize(video)}',
                        if (video.tags.isNotEmpty)
                          '标签: ${_formatTags(video.tags)}'
                      ].join(' | '),
                      style: TextStyle(
                        fontSize: infoSize,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatFileSize(Video video) {
    try {
      final file = File(video.path);
      if (file.existsSync()) {
        final sizeInBytes = file.lengthSync();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        return '${sizeInMB.toStringAsFixed(1)}MB';
      }
      return '未知';
    } catch (e) {
      return '未知';
    }
  }

  Widget _buildColumnSwitcher() {
    return SegmentedButton(
      segments: const [
        ButtonSegment(
          value: 1,
          label: Text('单列'),
          icon: Icon(Icons.view_list),
        ),
        ButtonSegment(
          value: 2,
          label: Text('双列'),
          icon: Icon(Icons.grid_view_rounded),
        ),
        ButtonSegment(
          value: 3,
          label: Text('三列'),
          icon: Icon(Icons.grid_3x3),
        ),
      ],
      selected: {_columnCount},
      onSelectionChanged: (value) {
        setState(() {
          _columnCount = value.first;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地视频'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '搜索视频标题或标签...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(8.0)),
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _performSearch,
                      child: const Text('搜索'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildColumnSwitcher(),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVideos.isEmpty
                    ? const Center(child: Text('没有找到匹配的视频'))
                    : GridView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: _cardSpacing,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _columnCount,
                          crossAxisSpacing: _cardSpacing,
                          mainAxisSpacing: _cardSpacing,
                          // 动态调整宽高比，避免高度冗余
                          childAspectRatio: _columnCount == 1 ? 2.5 : 1,
                        ),
                        itemCount: _filteredVideos.length,
                        itemBuilder: (context, index) {
                          final video = _filteredVideos[index];
                          if (_columnCount == 1) {
                            return Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: _maxSingleColumnWidth,
                                ),
                                child: _buildVideoItem(video),
                              ),
                            );
                          }
                          return _buildVideoItem(video);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickAndAddVideo,
        child: const Icon(Icons.add),
      ),
    );
  }
}

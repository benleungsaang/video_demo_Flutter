import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_demo/models/video.dart';
import 'package:video_demo/services/video_service.dart';
import 'package:video_demo/pages/video_tags_editor.dart';

class LocalVideosPage extends StatefulWidget {
  const LocalVideosPage({super.key});

  @override
  State<LocalVideosPage> createState() => _LocalVideosPageState();
}

class _LocalVideosPageState extends State<LocalVideosPage> {
  // 原始视频列表（存储所有视频）
  List<Video> _videos = [];
  // 过滤后的视频列表（用于展示搜索结果）
  List<Video> _filteredVideos = [];
  // 加载状态标识
  bool isLoading = false;
  // 搜索框控制器，用于获取输入内容
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 页面初始化时加载所有视频
    loadVideos();
  }

  @override
  void dispose() {
    // 释放搜索控制器资源
    _searchController.dispose();
    super.dispose();
  }

  // 加载视频列表
  void loadVideos() async {
    // 显示加载状态
    setState(() {
      isLoading = true;
    });

    // 从数据库获取最新视频列表
    final videoBox = Hive.box<Video>('videos');
    final videos = videoBox.values.toList();

    // 更新视频列表并隐藏加载状态
    setState(() {
      _videos = videos;
      // 初始时显示所有视频
      _filteredVideos = List.from(_videos);
      isLoading = false;
    });
  }

  // 执行搜索逻辑（按回车或点击按钮时调用）
  void _performSearch() {
    // 获取搜索关键词并标准化（转为小写、去除空格）
    final query = _searchController.text.toLowerCase().trim();

    // 如果搜索词为空，显示所有视频
    if (query.isEmpty) {
      setState(() {
        _filteredVideos = List.from(_videos);
      });
      return;
    }

    // 根据搜索词过滤视频
    setState(() {
      _filteredVideos = _videos.where((video) {
        // 检查视频标题是否包含搜索词（不区分大小写）
        final titleMatches = video.name.toLowerCase().contains(query);

        // 检查视频标签是否包含搜索词（不区分大小写）
        final tagMatches =
            video.tags.any((tag) => tag.toLowerCase().contains(query));

        // 标题或标签匹配则保留该视频
        return titleMatches || tagMatches;
      }).toList();
    });
  }

  // 选择并添加视频
  void pickAndAddVideo() async {
    Video? video = await VideoService.pickSingleVideo();
    if (video != null) {
      await VideoService.saveVideo(video);
      // 添加后重新加载列表
      loadVideos();
      if (mounted) {
        // 确保页面还在的情况下显示提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加视频成功: ${video.name}')),
        );
      }
    }
  }

  // 格式化时长显示（将秒转换为分:秒格式）
  String formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 从第n个斜杠开始截取路径（简化路径显示）
  String getPathFromNthSlash(String fullPath, int n) {
    final separator = fullPath.contains('/') ? '/' : '\\';
    List<String> pathParts = fullPath.split(separator);
    // 确保索引不越界
    if (n >= pathParts.length) return fullPath;

    // 从第n个部分开始拼接
    return pathParts.sublist(n).join(separator);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地视频'),
      ),
      body: Column(
        children: [
          // 搜索框区域
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 搜索输入框
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '搜索视频标题或标签...',
                      prefixIcon: Icon(Icons.search), // 搜索图标
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                    ),
                    // 按回车键触发搜索
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8), // 输入框和按钮间距
                // 搜索按钮
                ElevatedButton(
                  onPressed: _performSearch,
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),

          // 视频列表区域
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator()) // 加载中显示进度条
                : _filteredVideos.isEmpty
                    ? const Center(child: Text('没有找到匹配的视频')) // 无结果提示
                    : ListView.builder(
                        itemCount: _filteredVideos.length,
                        itemBuilder: (context, index) {
                          Video video = _filteredVideos[index];
                          return ListTile(
                            title: Text(video.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 视频信息行
                                Text(
                                    '格式: ${video.format} | 时长: ${formatDuration(video.duration)} | ${getPathFromNthSlash(video.path, 6)} '),
                                // 显示视频标签（如果有）
                                if (video.tags.isNotEmpty)
                                  Wrap(
                                    spacing: 4,
                                    children: video.tags
                                        .map((tag) => Chip(
                                              label: Text(tag),
                                              backgroundColor: Colors.blue[100],
                                              labelStyle:
                                                  const TextStyle(fontSize: 12),
                                            ))
                                        .toList(),
                                  ),
                              ],
                            ),
                            // 编辑标签按钮
                            leading: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        VideoTagsEditorPage(video: video),
                                  ),
                                );
                                if (result == true) {
                                  loadVideos(); // 编辑后刷新列表
                                }
                              },
                            ),
                            // 删除视频按钮
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
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
                                  loadVideos(); // 删除后刷新列表
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('已删除: ${video.name}')),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      // 添加视频的浮动按钮
      floatingActionButton: FloatingActionButton(
        onPressed: pickAndAddVideo,
        child: const Icon(Icons.add),
      ),
    );
  }
}

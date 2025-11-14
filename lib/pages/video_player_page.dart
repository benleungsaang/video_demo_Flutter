import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:video_demo/models/video.dart';
import 'package:video_demo/services/tag_search_service.dart';
import 'package:video_demo/models/tag.dart';

class OptimizedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Function(bool) onFullScreenChanged;

  const OptimizedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.onFullScreenChanged,
  });

  @override
  State<OptimizedVideoPlayer> createState() => _OptimizedVideoPlayerState();
}

class _OptimizedVideoPlayerState extends State<OptimizedVideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 1.0;
  bool _showControls = true;
  bool _isFullScreen = false;
  final Duration _controlsFadeDelay = const Duration(seconds: 3);
  late Timer _controlsTimer;
  late Timer _progressUpdateTimer;

  @override
  void initState() {
    super.initState();
    // 初始化视频控制器
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      print('视频初始化完成 - URL: ${widget.videoUrl}');
      // 1. 初始化完成后自动播放
      _controller.play();
      setState(() {
        _isPlaying = true;
      });
      _startControlsTimer();
    });

    _controller.addListener(_videoStatusListener);

    // 初始化控制栏定时器
    _controlsTimer = Timer(_controlsFadeDelay, () {
      if (_isPlaying && mounted) {
        setState(() => _showControls = false);
      }
    });

    // 初始化进度更新定时器
    _progressUpdateTimer =
        Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (_showControls && _isPlaying && mounted) {
        setState(() {});
      }
    });
  }

  void _videoStatusListener() {
    if (_controller.value.isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = _controller.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoStatusListener);
    _controller.dispose();
    _controlsTimer.cancel();
    _progressUpdateTimer.cancel();
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 0) return "00:00";
    return DateFormat('mm:ss').format(
      DateTime.fromMillisecondsSinceEpoch(duration.inMilliseconds, isUtc: true),
    );
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _showControls = true);
    } else {
      _controller.play();
      _startControlsTimer();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : _volume);
    });
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value;
      _controller.setVolume(value);
      _isMuted = value == 0.0;
    });
  }

  void _seekTo(Duration position) {
    _controller.seekTo(position);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      widget.onFullScreenChanged(_isFullScreen);

      if (_isFullScreen) {
        // 进入全屏逻辑保持不变
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        // 退出全屏的修复逻辑 - 不使用延迟刷新
        // 1. 恢复系统UI和方向
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
        );

        // 2. 使用 GlobalKey 强制重建父级页面布局
        // 通过回调通知父组件触发重建
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // 通知父组件刷新
            widget.onFullScreenChanged(_isFullScreen);
          }
        });
      }
    });
  }

  void _startControlsTimer() {
    _controlsTimer.cancel();
    _controlsTimer = Timer(_controlsFadeDelay, () {
      if (_isPlaying && mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls && _isPlaying) {
        _startControlsTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFullScreen ? Colors.black : null,
      body: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return _buildVideoPlayer();
          } else {
            // 加载时显示居中的加载指示器
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // 3. 全屏时点击黑色区域也能触发控制栏显示
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTap: _togglePlayPause,
      child: _isFullScreen ? _buildFullScreenPlayer() : _buildNormalPlayer(),
    );
  }

  Widget _buildFullScreenPlayer() {
    return Stack(
      children: [
        // 全屏模式视频居中并缩小5%
        Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
        // 左上角退出全屏按钮
        Positioned(
          top: 16,
          left: 16,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              size: 24,
              color: Colors.white,
            ),
            onPressed: _toggleFullScreen,
            splashRadius: 24,
          ),
        ),
        // 播放/暂停大按钮
        if (!_isPlaying || _showControls)
          Center(
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 80,
                color: Colors.white54,
              ),
              onPressed: _togglePlayPause,
              splashRadius: 24,
            ),
          ),
        // 底部控制栏
        if (_showControls)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControlsBar(),
          ),
      ],
    );
  }

  Widget _buildNormalPlayer() {
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        children: [
          // 2. 普通模式视频始终居中并缩小3%
          Center(
            child: Container(
              margin: const EdgeInsets.all(16), // 增加边距，实现缩小效果
              // 添加边框和阴影增强视觉效果
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: VideoPlayer(_controller),
            ),
          ),
          // 播放/暂停大按钮
          if (!_isPlaying || _showControls)
            Center(
              child: IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 80,
                  color: Colors.white54,
                ),
                onPressed: _togglePlayPause,
                splashRadius: 24,
              ),
            ),
          // 底部控制栏
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildControlsBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black54,
      child: Column(
        children: [
          Slider(
            value: _controller.value.position.inMilliseconds.toDouble(),
            max: _controller.value.duration.inMilliseconds.toDouble(),
            min: 0,
            activeColor: Colors.red,
            inactiveColor: Colors.white30,
            onChanged: (value) {
              _seekTo(Duration(milliseconds: value.toInt()));
            },
            onChangeStart: (_) {
              _controlsTimer.cancel();
            },
            onChangeEnd: (_) {
              if (_isPlaying) _startControlsTimer();
            },
          ),
          Row(
            children: [
              Text(
                '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                style: const TextStyle(color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _isMuted || _volume == 0
                      ? Icons.volume_off
                      : _volume < 0.5
                          ? Icons.volume_down
                          : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: _toggleMute,
                splashRadius: 24,
              ),
              SizedBox(
                width: 120,
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 1,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                  onChanged: _setVolume,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                ),
                onPressed: _toggleFullScreen,
                splashRadius: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final Video video;
  const VideoPlayerPage({super.key, required this.video});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  bool _isFullScreen = false;
  // 添加一个用于强制重建的key
  final GlobalKey _playerKey = GlobalKey();
  final GlobalKey _pageKey = GlobalKey();

  void _handleFullScreenChange(bool isFull) {
    setState(() {
      _isFullScreen = isFull;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _pageKey,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              if (!_isFullScreen)
                AppBar(
                  title: Text(widget.video.name),
                ),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey(_isFullScreen),
                  child: OptimizedVideoPlayer(
                    key: _playerKey,
                    videoUrl: widget.video.path,
                    onFullScreenChanged: _handleFullScreenChange,
                  ),
                ),
              ),
              // 标签编辑区域（非全屏状态显示）
              if (!_isFullScreen) _buildVideoTagsEditor(),
            ],
          );
        },
      ),
    );
  }

// 标签编辑区域组件（适配TagSearchService）
  Widget _buildVideoTagsEditor() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '视频标签',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 添加新标签的输入框
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: '添加新标签',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addTagToVideo(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addTagToVideo,
                child: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 当前标签展示（支持删除）
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.video.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      backgroundColor: const Color.fromARGB(255, 200, 197, 255),
                      labelStyle: const TextStyle(color: Colors.black87),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () async {
                        // 通过TagSearchService更新视频标签（移除标签）
                        final newTags = List<String>.from(widget.video.tags)
                          ..remove(tag);
                        await TagSearchService.updateVideoTags(
                            widget.video, newTags);
                        setState(() {}); // 刷新UI
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          // 推荐标签（从TagSearchService获取）
          const Text(
            '推荐标签',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Tag>>(
            future: _loadRecommendedTags(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: snapshot.data!
                      .where((tag) => !widget.video.tags.contains(tag.name))
                      .map((tag) => InputChip(
                            // 与当前标签样式完全统一
                            label: Text(tag.name),
                            backgroundColor:
                                const Color.fromARGB(255, 212, 212, 212),
                            labelStyle: const TextStyle(color: Colors.black87),
                            onPressed: () async {
                              // 通过TagSearchService更新视频标签（添加标签）
                              final newTags =
                                  List<String>.from(widget.video.tags)
                                    ..add(tag.name);
                              await TagSearchService.updateVideoTags(
                                  widget.video, newTags);
                              setState(() {}); // 刷新UI
                            },
                          ))
                      .toList(),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }

// 新增相关变量和方法（适配TagSearchService）
  final TextEditingController _tagController = TextEditingController();

// 从服务获取推荐标签（按使用次数排序）
  Future<List<Tag>> _loadRecommendedTags() async {
    return TagSearchService.getAllTags();
  }

// 添加新标签（通过服务处理）
  Future<void> _addTagToVideo() async {
    final tagText = _tagController.text.trim();
    if (tagText.isNotEmpty && !widget.video.tags.contains(tagText)) {
      // 通过TagSearchService统一处理标签添加和视频标签更新
      final newTags = List<String>.from(widget.video.tags)..add(tagText);
      await TagSearchService.updateVideoTags(widget.video, newTags);
      _tagController.clear();
      setState(() {}); // 刷新UI
    }
  }

// 释放资源
  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }
}

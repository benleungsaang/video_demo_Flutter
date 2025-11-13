import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:video_demo/models/video.dart';

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
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        // 修复全屏退出后界面异常
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        // 强制刷新界面尺寸
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
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

  const VideoPlayerPage({
    super.key,
    required this.video,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  bool _isFullScreen = false;
  final GlobalKey<_OptimizedVideoPlayerState> _optimizedVideoPlayerKey =
      GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen ? null : AppBar(title: Text(widget.video.name)),
      // 点击整个页面任意位置都能激活控制栏
      body: GestureDetector(
        onTap: () {
          if (mounted) {
            _optimizedVideoPlayerKey.currentState?._toggleControls();
          }
        },
        child: Container(
          color: _isFullScreen ? Colors.black : null,
          child: OptimizedVideoPlayer(
            key: _optimizedVideoPlayerKey,
            videoUrl: widget.video.path,
            onFullScreenChanged: (isFull) {
              setState(() => _isFullScreen = isFull);
            },
          ),
        ),
      ),
    );
  }
}

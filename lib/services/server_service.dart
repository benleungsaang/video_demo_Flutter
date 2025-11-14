import 'dart:io';
import 'package:flutter/foundation.dart'; // 添加这个导入
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:video_demo/models/video.dart';
import 'package:hive/hive.dart'; // 引入Hive
import 'package:video_demo/utils/path_utils.dart';
// import 'package:video_demo/services/video_service.dart';
import 'package:video_demo/services/tag_search_service.dart';
import 'dart:convert';

// 在文件顶部添加异常定义
class NotFoundException implements Exception {
  final String message;

  NotFoundException([this.message = "资源未找到"]);

  @override
  String toString() => "NotFoundException: $message";
}

class ServerService {
  static HttpServer? _server;
  // 在现有代码基础上添加状态监听功能
  static final ValueNotifier<bool> _serverStatusNotifier = ValueNotifier(false);
  static ValueNotifier<bool> get serverStatusNotifier => _serverStatusNotifier;

  // 获取Hive的videoBox（假设已在全局初始化，名称为"videos"）
  static Box<Video> get videoBox => Hive.box<Video>('videos');

  // 获取视频存储目录（基于Hive中存储的视频）
  static Future<String> get videoStoragePath async {
    return await PathUtils.unifiedVideoDirectory;
  }

  // 视频索引页面处理（适配Hive中的Video类）
  static shelf.Response _videoIndexHandler(shelf.Request request) {
    final query = request.url.queryParameters['q'] ?? '';
    final videos = TagSearchService.searchVideos(query);

    // 卡片式布局的HTML模板
    String html = '''
  <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>视频列表</title>
      <style>
        .container { max-width: 1200px; margin: 0 auto; padding: 16px; }
        .search-bar { margin-bottom: 24px; display: flex; gap: 8px; }
        .search-bar input { flex: 1; padding: 8px; font-size: 16px; }
        .search-bar button { padding: 8px 16px; background: #007bff; color: white; border: none; border-radius: 4px; }
        .video-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 24px; }
        .video-card { border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1); transition: transform 0.2s; }
        .video-card:hover { transform: translateY(-4px); }
        .video-thumbnail { width: 100%; height: 160px; background: #333; position: relative; }
        .video-thumbnail img { width: 100%; height: 100%; object-fit: cover; }
        .duration { position: absolute; bottom: 4px; right: 4px; background: rgba(0,0,0,0.7); color: white; padding: 2px 6px; border-radius: 4px; font-size: 12px; }
        .video-info { padding: 12px; }
        .video-title { font-weight: 500; margin-bottom: 8px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .tag { display: inline-block; background: #e0e0e0; padding: 2px 8px; border-radius: 12px; font-size: 12px; margin: 0 4px 4px 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>视频列表</h1>
        <div class="search-bar">
          <input type="text" id="search-input" placeholder="搜索视频标题或标签..." value="$query">
          <button onclick="performSearch()">搜索</button>
        </div>
        <div class="video-grid">
          ${videos.map((video) => '''
            <div class="video-card">
              <div class="video-thumbnail">
                <a href="${Uri.encodeComponent(video.path.split('/').last)}">
                  <img src="/thumbnails/${Uri.encodeComponent(video.thumbnailPath?.split('/').last ?? '')}" alt="${video.name}">
                  <span class="duration">${_formatDuration(video.duration)}</span>
                </a>
              </div>
              <div class="video-info">
                <div class="video-title">${video.name}</div>
                <div>
                  ${video.tags.map((tag) => '<span class="tag">${tag}</span>').join('')}
                </div>
              </div>
            </div>
          ''').join('')}
        </div>
      </div>
      <script>
        function performSearch() {
          const query = document.getElementById('search-input').value;
          window.location.href = '?q=' + encodeURIComponent(query);
        }
        // 支持回车键搜索
        document.getElementById('search-input').addEventListener('keypress', function(e) {
          if (e.key === 'Enter') performSearch();
        });
      </script>
    </body>
  </html>
  ''';
    return shelf.Response.ok(html, headers: {'Content-Type': 'text/html'});
  }

  // 在 server_service.dart 中添加视频播放页面处理
  static shelf.Response _videoPlayHandler(
      shelf.Request request, String videoName) {
    // 找到对应的视频
    final decodedName = Uri.decodeComponent(videoName);
    final video = videoBox.values.firstWhere(
      (v) => v.path.split('/').last == decodedName,
      orElse: () => throw NotFoundException(),
    );

    return shelf.Response.ok('''
  <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${video.name} - 播放</title>
      <style>
        .container { max-width: 1200px; margin: 0 auto; padding: 16px; }
        .video-container { position: relative; width: 100%; max-width: 800px; margin: 0 auto; }
        video { width: 100%; }
        .tag-section { margin: 24px 0; }
        .tag-input { display: flex; gap: 8px; margin: 16px 0; }
        .tag-input input { flex: 1; padding: 8px; }
        .tag { display: inline-block; background: #e0e0e0; padding: 4px 10px; border-radius: 16px; margin: 0 8px 8px 0; }
        .tag .remove { cursor: pointer; margin-left: 6px; color: #666; }
        .recommended-tags { margin-top: 16px; }
        .chip { display: inline-block; background: #f0f0f0; padding: 4px 10px; border-radius: 16px; margin: 0 8px 8px 0; cursor: pointer; }
      </style>
    </head>
    <body>
      <div class="container">
        <a href="/">← 返回列表</a>
        <h1>${video.name}</h1>
        <div class="video-container">
          <video controls>
            <source src="/videos/$videoName" type="video/mp4">
            您的浏览器不支持视频播放
          </video>
        </div>

        <div class="tag-section">
          <h3>视频标签</h3>
          <div class="tag-input">
            <input type="text" id="new-tag" placeholder="输入新标签">
            <button onclick="addTag()">添加</button>
          </div>

          <div id="current-tags">
            ${video.tags.map((tag) => '''
              <span class="tag">
                $tag
                <span class="remove" onclick="removeTag('$tag')">×</span>
              </span>
            ''').join('')}
          </div>

          <div class="recommended-tags">
            <h4>推荐标签</h4>
            <div id="recommended-tags-container">
              ${TagSearchService.getAllTags().where((t) => !video.tags.contains(t.name)).take(10).map((tag) => '''
                  <span class="chip" onclick="addTag('${tag.name}')">${tag.name}</span>
                ''').join('')}
            </div>
          </div>
        </div>
      </div>

      <script>
        // 标签操作函数
        async function addTag(tagText) {
          const input = document.getElementById('new-tag');
          const tag = tagText || input.value.trim();
          if (!tag) return;

          // 发送添加标签请求
          const response = await fetch('/api/update-tags', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
              videoId: '${video.key}',
              tags: [...${json.encode(video.tags)}, tag]
            })
          });

          if (response.ok) {
            window.location.reload(); // 刷新页面显示更新后的标签
          }
          input.value = '';
        }

        async function removeTag(tagToRemove) {
          // 发送移除标签请求
          const response = await fetch('/api/update-tags', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
              videoId: '${video.key}',
              tags: ${json.encode(video.tags)}.filter(t => t !== tagToRemove)
            })
          });

          if (response.ok) {
            window.location.reload();
          }
        }

        // 支持回车键添加标签
        document.getElementById('new-tag').addEventListener('keypress', function(e) {
          if (e.key === 'Enter') addTag();
        });
      </script>
    </body>
  </html>
  ''', headers: {'Content-Type': 'text/html'});
  }

  // 格式化时长（保持不变）
  static String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 启动服务器
  static Future<String?> startServer(
      String ip, int port, String rootPath) async {
    try {
      // 提前解析路径（关键修复）
      final thumbnailDir = await PathUtils.getThumbnailDirectory();
      final videoDir = await videoStoragePath;
      // 创建处理程序链
      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler((request) {
        final path = request.url.path;

        // 视频播放页面
        if (path.startsWith('/videos/') && !path.endsWith('/')) {
          final videoName = path.substring('/videos/'.length);
          return _videoPlayHandler(request, videoName);
        }

        // 标签更新API
        if (path == '/api/update-tags' && request.method == 'POST') {
          return _handleUpdateTags(request);
        }

        // 缩略图服务
        if (path.startsWith('/thumbnails/')) {
          final thumbName = path.substring('/thumbnails/'.length);
          return createStaticHandler(thumbnailDir)(// 这里不再使用await
              request.change(path: thumbName));
        }

        // 视频文件服务
        if (path.startsWith('/videos/')) {
          return createStaticHandler(videoDir)(// 这里不再使用await
              request.change(path: path.substring(1)));
        }

        // 首页视频列表
        return _videoIndexHandler(request);
      });

      _server = await shelf_io.serve(handler, ip, port);
      _serverStatusNotifier.value = true;
      return 'http://${_server?.address.host}:${_server?.port}';
    } catch (e) {
      print('启动服务器失败: $e');
      return null;
    }
  }

// 添加标签更新处理函数
  static Future<shelf.Response> _handleUpdateTags(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final videoId = data['videoId'];
      final newTags = List<String>.from(data['tags']);

      final video = videoBox.get(videoId);
      if (video == null) {
        return shelf.Response.notFound('视频不存在');
      }

      await TagSearchService.updateVideoTags(video, newTags);
      return shelf.Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      return shelf.Response.internalServerError(
          body: jsonEncode({'success': false, 'error': e.toString()}));
    }
  }

  // 停止服务器
  static Future<String> stopServer() async {
    if (_server != null) {
      await _server?.close();
      _server = null;
      _serverStatusNotifier.value = false; // 通知状态变化
      return '服务器已停止';
    }
    return '服务器未在运行';
  }

  // 检查服务器状态
  static bool isServerRunning() {
    return _server != null && _server!.address != null;
  }
}

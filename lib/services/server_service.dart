import 'dart:io';
import 'package:flutter/foundation.dart'; // 添加这个导入
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:video_demo/models/video.dart';
import 'package:hive/hive.dart'; // 引入Hive
import 'package:video_demo/utils/path_utils.dart';
// import 'package:video_demo/services/video_service.dart';

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
    List<Video> videos = videoBox.values.toList(); // 从Hive获取视频列表
    String html = '''
    <html>
      <head>
        <meta charset="UTF-8">
        <title>视频列表</title>
        <style>
          .tag {
            display: inline-block;
            background-color: #e0e0e0;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 12px;
            margin: 0 4px;
          }
          .video-item {
            margin: 16px 0;
            padding: 8px;
            border-bottom: 1px solid #eee;
          }
        </style>
      </head>
      <body>
        <h1>视频列表</h1>
        <div>
          ${videos.map((video) => '''
            <div class="video-item">
              <a href="${Uri.encodeComponent(video.path.split('/').last)}">${video.name}</a>
              <div>
                格式: ${video.format}, 时长: ${_formatDuration(video.duration)}
              </div>
              <div>
                ${video.tags.isNotEmpty ? '标签: ' : ''}
                ${video.tags.map((tag) => '<span class="tag">${tag}</span>').join('')}
              </div>
            </div>
          ''').join('')}
        </div>
      </body>
    </html>
    ''';
    return shelf.Response.ok(html, headers: {'Content-Type': 'text/html'});
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
    if (_server != null) {
      return '服务器已在运行中';
    }

    try {
      // 创建静态文件处理器
      final handler = shelf.Cascade()
          .add(_videoIndexHandler) // 再处理根路径的视频列表
          .add(createStaticHandler(
            rootPath,
            defaultDocument: null,
            listDirectories: false,
          ))
          // .add(_videoIndexHandler) // 添加这一行，确保根路径显示列表
          .handler;

      // 启动服务器
      _server = await shelf_io.serve(handler, ip, port);

      // 允许跨域访问
      _server?.defaultResponseHeaders.add('Access-Control-Allow-Origin', '*');
      _server?.defaultResponseHeaders
          .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      _server?.defaultResponseHeaders
          .add('Access-Control-Allow-Headers', 'Content-Type');

      _serverStatusNotifier.value = true; // 通知状态变化
      return '服务器启动成功: http://$ip:$port';
    } catch (e) {
      return '服务器启动失败: $e';
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

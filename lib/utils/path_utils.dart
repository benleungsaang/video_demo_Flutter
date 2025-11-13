// lib/utils/path_utils.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PathUtils {
  // 获取统一的视频存储目录
  static Future<String> get unifiedVideoDirectory async {
    final appDocDir = await getExternalStorageDirectory();
    final videoDir = Directory('${appDocDir?.path}/file_picker');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }
    return videoDir.path;
  }
}

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:video_player/video_player.dart';
import 'package:video_demo/models/video.dart';
import 'package:video_demo/utils/path_utils.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'dart:typed_data';

class VideoService {
  // 获取视频数据库表
  static Box<Video> get videoBox => Hive.box<Video>('videos');

  // 选择单个视频文件
  static Future<Video?> pickSingleVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile platformFile = result.files.first;
        if (platformFile.path != null) {
          File originalFile = File(platformFile.path!);
          final targetDir = await PathUtils.unifiedVideoDirectory;
          final targetFile = File('$targetDir/${platformFile.name}');
          if (originalFile.path != targetFile.path) {
            await originalFile.copy(targetFile.path);
          }
          return await _createVideoFromFile(targetFile);
        }
      }
    } catch (e) {
      print('选择视频出错: $e');
    }
    return null;
  }

  // 从文件创建视频对象（内部使用的方法，所以用下划线开头）
  static Future<Video?> _createVideoFromFile(File file) async {
    try {
      // 获取视频元数据
      final videoPlayerController = VideoPlayerController.file(file);
      await videoPlayerController.initialize();

      // 获取文件名和格式
      String fileName = file.path.split('/').last;
      String format = fileName.split('.').last;

      // 创建并返回视频对象
      return Video(
        path: file.path,
        name: fileName,
        duration: videoPlayerController.value.duration.inSeconds,
        format: format,
      );
    } catch (e) {
      print('解析视频出错: $e');
      return null;
    }
  }

  // 保存视频到数据库
  static Future<void> saveVideo(Video video) async {
    await videoBox.add(video);
  }

  // 获取所有视频
  static List<Video> getAllVideos() {
    return videoBox.values.toList();
  }

  // 给视频添加标签
  static Future<void> addTagToVideo(Video video, String tag) async {
    if (!video.tags.contains(tag)) {
      video.tags.add(tag);
      await video.save();
    }
  }

  // 从视频移除标签
  static Future<void> removeTagFromVideo(Video video, String tag) async {
    video.tags.remove(tag);
    await video.save();
  }

  // 添加删除视频的方法
  static Future<void> deleteVideo(Video video) async {
    try {
      // 删除本地文件
      File file = File(video.path);
      if (await file.exists()) {
        await file.delete();
      }
      // 从数据库中删除
      await video.delete();
    } catch (e) {
      print('删除视频出错: $e');
      throw Exception('删除视频失败: $e');
    }
  }

  // 为视频生成缩略图
  static Future<String?> generateThumbnail(Video video) async {
    try {
      // 获取缩略图保存目录（确保目录存在）
      final thumbnailDir = await PathUtils.unifiedVideoDirectory;
      await Directory(thumbnailDir).create(recursive: true); // 确保目录存在

      // 生成唯一的缩略图文件名（基于视频文件名）
      final videoFileName = p.basenameWithoutExtension(video.path);
      final thumbnailPath = '$thumbnailDir/${videoFileName}_thumb.jpg';

      // 检查缩略图是否已存在，避免重复生成
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      // 调用thumbnailData生成内存中的缩略图（使用你提供的代码）
      final Uint8List? uint8list = await VideoThumbnail.thumbnailData(
        video: video.path, // 视频文件路径（参数名是video）
        imageFormat: ImageFormat.JPEG, // 图像格式
        maxWidth: 128, // 缩略图最大宽度（高度自动按比例缩放）
        quality: 25, // 图像质量（0-100，数值越低质量越低）
      );

      if (uint8list != null) {
        // 将内存中的缩略图数据写入本地文件
        await File(thumbnailPath).writeAsBytes(uint8list);

        // 更新视频模型的缩略图路径并保存
        video.thumbnailPath = thumbnailPath;
        await video.save();

        return thumbnailPath;
      }
    } catch (e) {
      print('生成缩略图失败: $e');
    }
    return null;
  }
}

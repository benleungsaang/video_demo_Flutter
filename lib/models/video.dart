import 'package:hive/hive.dart';

part 'video.g.dart'; // 这行很重要，用于生成代码

@HiveType(typeId: 0)
class Video extends HiveObject {
  // 视频路径
  @HiveField(0)
  final String path;

  // 视频名称
  @HiveField(1)
  final String name;

  // 视频时长(秒)
  @HiveField(2)
  final int duration;

  // 视频格式
  @HiveField(3)
  final String format;

  // 标签列表
  @HiveField(4)
  List<String> tags;

  // 缩略图路径
  @HiveField(5)
  String? thumbnailPath;

  // 构造函数，required表示必须传入的参数
  Video({
    required this.path,
    required this.name,
    required this.duration,
    required this.format,
    this.tags = const [],
    this.thumbnailPath,
  });

  // 方便调试时查看视频信息
  @override
  String toString() {
    return 'Video{name: $name, format: $format, duration: $duration, tags: $tags}';
  }
}

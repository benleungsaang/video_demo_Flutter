import 'package:hive/hive.dart';
import 'package:video_demo/models/tag.dart';
import 'package:video_demo/models/video.dart';

class TagService {
  // 获取标签数据库表
  static Box<Tag> get tagBox => Hive.box<Tag>('tags');

  // 初始化标签箱
  static Future<void> init() async {
    if (!Hive.isBoxOpen('tags')) {
      await Hive.openBox<Tag>('tags');
    }
  }

  // 获取所有标签（按使用次数排序）
  static List<Tag> getAllTags() {
    final tags = tagBox.values.toList();
    tags.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return tags;
  }

  // 添加标签（自动标准化）
  static Future<Tag?> addTag(String tagName) async {
    if (!Tag.isValidName(tagName)) return null;

    final normalizedName = Tag.normalizeName(tagName);
    final existingTag = tagBox.values.firstWhere(
      (t) => t.name == normalizedName,
      orElse: () => Tag.normalized(tagName),
    );

    if (existingTag.isInBox) {
      existingTag.usageCount++;
      await existingTag.save();
      return existingTag;
    } else {
      existingTag.usageCount = 1;
      await tagBox.add(existingTag);
      return existingTag;
    }
  }

  // 批量添加标签
  static Future<List<Tag>> addTags(List<String> tagNames) async {
    final addedTags = <Tag>[];
    for (final name in tagNames) {
      final tag = await addTag(name);
      if (tag != null) addedTags.add(tag);
    }
    return addedTags;
  }

  // 删除标签
  static Future<void> deleteTag(Tag tag) async {
    // 先从所有视频中移除该标签
    final videos = Hive.box<Video>('videos').values.toList();
    for (final video in videos) {
      if (video.tags.contains(tag.name)) {
        video.tags.remove(tag.name);
        await video.save();
      }
    }
    // 再删除标签本身
    await tag.delete();
  }

  // 为视频设置标签
  static Future<void> setVideoTags(Video video, List<String> tagNames) async {
    // 1. 处理旧标签（减少使用次数）
    for (final oldTag in video.tags) {
      final tag = tagBox.values.firstWhere(
        (t) => t.name == oldTag,
        orElse: () => Tag(name: ''),
      );

      if (tag.name.isNotEmpty) {
        tag.usageCount = (tag.usageCount - 1).clamp(0, double.infinity).toInt();
        await tag.save(); // 确保保存旧标签的变更
      }
    }

    // 2. 处理新标签（添加或增加使用次数）
    final newTags = await addTags(tagNames);

    // 3. 更新视频的标签列表
    video.tags = newTags.map((t) => t.name).toList();
    await video.save(); // 确保视频对象被保存

    // 4. 额外保险：强制更新视频在数据库中的记录
    final videoBox = Hive.box<Video>('videos');
    if (video.key != null) {
      await videoBox.put(video.key, video);
    } else {
      // 如果是新视频没有key，添加到数据库
      await videoBox.add(video);
    }
  }

  // 搜索标签（支持模糊搜索）
  static List<Tag> searchTags(String query) {
    if (query.isEmpty) return getAllTags();

    final normalizedQuery = Tag.normalizeName(query);
    return tagBox.values
        .where((tag) => tag.name.contains(normalizedQuery))
        .toList();
  }
}

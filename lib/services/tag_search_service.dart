import 'package:hive/hive.dart';
import 'package:video_demo/models/tag.dart';
import 'package:video_demo/models/video.dart';

class TagSearchService {
  // 标签相关操作
  static Box<Tag> get _tagBox => Hive.box<Tag>('tags');
  static Box<Video> get _videoBox => Hive.box<Video>('videos');

  // 获取所有标签（按使用次数排序）
  static List<Tag> getAllTags() {
    final tags = _tagBox.values.toList();
    tags.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return tags;
  }

  // 添加标签
  static Future<Tag?> addTag(String tagName) async {
    if (!Tag.isValidName(tagName)) return null;

    final normalizedName = Tag.normalizeName(tagName);
    final existingTag = _tagBox.values.firstWhere(
      (t) => t.name == normalizedName,
      orElse: () => Tag.normalized(tagName),
    );

    if (existingTag.isInBox) {
      existingTag.usageCount++;
      await existingTag.save();
      return existingTag;
    } else {
      existingTag.usageCount = 1;
      await _tagBox.add(existingTag);
      return existingTag;
    }
  }

  // 删除标签
  static Future<void> deleteTag(Tag tag) async {
    // 从所有视频中移除该标签
    final videos = _videoBox.values.toList();
    for (final video in videos) {
      if (video.tags.contains(tag.name)) {
        video.tags.remove(tag.name);
        await video.save();
      }
    }
    await tag.delete();
  }

  // 视频搜索相关操作
  static List<Video> searchVideos(String query) {
    final normalizedQuery = query.toLowerCase().trim();
    if (normalizedQuery.isEmpty) {
      return _videoBox.values.toList();
    }

    return _videoBox.values.where((video) {
      // 标题匹配
      final titleMatches = video.name.toLowerCase().contains(normalizedQuery);

      // 标签匹配
      final tagMatches =
          video.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));

      return titleMatches || tagMatches;
    }).toList();
  }

  // 更新视频标签
  static Future<void> updateVideoTags(Video video, List<String> newTags) async {
    // 处理旧标签（减少使用次数）
    for (final oldTag in video.tags) {
      final tag = _tagBox.values.firstWhere(
        (t) => t.name == oldTag,
        orElse: () => Tag(name: ''),
      );
      if (tag.name.isNotEmpty) {
        tag.usageCount = (tag.usageCount - 1).clamp(0, double.infinity).toInt();
        await tag.save();
      }
    }

    // 处理新标签（添加或增加使用次数）
    final addedTags = <Tag>[];
    for (final name in newTags) {
      final tag = await addTag(name);
      if (tag != null) addedTags.add(tag);
    }

    // 更新视频标签
    video.tags = addedTags.map((t) => t.name).toList();
    await video.save();
  }

  // 搜索标签（支持模糊搜索）
  static List<Tag> searchTags(String query) {
    if (query.isEmpty) return getAllTags();

    final normalizedQuery = Tag.normalizeName(query);
    return _tagBox.values
        .where((tag) => tag.name.contains(normalizedQuery))
        .toList();
  }
}

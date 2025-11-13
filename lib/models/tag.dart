import 'package:hive/hive.dart';

part 'tag.g.dart';

@HiveType(typeId: 1)
class Tag extends HiveObject {
  @HiveField(0)
  final String name;

  // 记录标签使用次数，用于后续优化
  @HiveField(1)
  int usageCount;

  Tag({
    required this.name,
    this.usageCount = 0,
  });

  // 标准化标签（小写处理，去除空格）
  factory Tag.normalized(String name) {
    return Tag(name: normalizeName(name));
  }

  static String normalizeName(String name) {
    // 去除首尾空格，转换为小写
    return name.trim().toLowerCase();
  }

  // 检查标签名是否有效
  static bool isValidName(String name) {
    // 标签名不能为空且不能包含特殊字符
    final normalized = normalizeName(name);
    return normalized.isNotEmpty &&
        !RegExp(r'[\\/:*?"<>|]').hasMatch(normalized);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return 'Tag{name: $name, usageCount: $usageCount}';
  }
}

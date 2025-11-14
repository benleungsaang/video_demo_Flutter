import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../services/tag_service.dart';
import '../models/tag.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  late List<Tag> _tags;
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  // 加载标签数据
  void _loadTags() {
    setState(() {
      _tags = TagService.getAllTags();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
      ),
      body: _tags.isEmpty
          ? const Center(
              child: Text(
                '暂无标签',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              // 使用分隔线构建器，添加浅色分隔线
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 0.5,
                indent: 16,
                endIndent: 16,
                color: Colors.grey[200], // 浅灰色分隔线
              ),
              itemCount: _tags.length,
              itemBuilder: (context, index) {
                final tag = _tags[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tag.name,
                        style: const TextStyle(fontSize: 16),
                      ),
                      // 显示标签使用次数
                      Text(
                        '使用 ${tag.usageCount} 次',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      // 去除原来的FloatingActionButton（添加按钮）
      // 整合添加功能：可在视频详情页添加，或在标签管理页通过下拉菜单实现
    );
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }
}

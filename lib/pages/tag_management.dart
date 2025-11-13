import 'package:flutter/material.dart';
import 'package:video_demo/models/tag.dart';
import 'package:video_demo/services/tag_service.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  List<Tag> _allTags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  void _loadTags() {
    setState(() {
      _allTags = TagService.getAllTags();
    });
  }

  void addNewTag() async {
    String? tagName = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('添加标签'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '输入标签名称'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );

    if (tagName != null && tagName.isNotEmpty) {
      if (!Tag.isValidName(tagName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('标签名称包含无效字符')),
          );
        }
        return;
      }

      await TagService.addTag(tagName);
      _loadTags();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
      ),
      body: _allTags.isEmpty
          ? const Center(child: Text('暂无标签，请添加标签'))
          : ListView.builder(
              itemCount: _allTags.length,
              itemBuilder: (context, index) {
                Tag tag = _allTags[index];
                return ListTile(
                  title: Text(tag.name),
                  subtitle: Text('使用次数: ${tag.usageCount}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('确认删除'),
                          content: Text('确定要删除标签 "${tag.name}" 吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('删除'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await TagService.deleteTag(tag);
                        _loadTags();
                      }
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: addNewTag,
        child: const Icon(Icons.add),
      ),
    );
  }
}

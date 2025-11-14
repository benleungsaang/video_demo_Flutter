import 'package:flutter/material.dart';
import 'package:video_demo/models/video.dart';
import 'package:video_demo/models/tag.dart';
// import 'package:video_demo/services/tag_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:video_demo/services/tag_search_service.dart';

class VideoTagsEditorPage extends StatefulWidget {
  final Video video;

  const VideoTagsEditorPage({
    super.key,
    required this.video,
  });

  @override
  State<VideoTagsEditorPage> createState() => _VideoTagsEditorPageState();
}

class _VideoTagsEditorPageState extends State<VideoTagsEditorPage> {
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late List<String> _currentTags;
  late List<String> _originalTags; // 保存初始标签用于对比
  List<Tag> _allTags = [];

  @override
  void dispose() {
    _focusNode.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 保存初始标签状态
    _originalTags = List.from(widget.video.tags);
    _currentTags = List.from(_originalTags);
    _loadAllTags();
  }

  void _loadAllTags() {
    setState(() {
      _allTags = TagSearchService.getAllTags();
    });
  }

  void _addTag() {
    final tagText = _tagController.text.trim();
    if (tagText.isNotEmpty && !_currentTags.contains(tagText)) {
      setState(() {
        _currentTags.add(tagText);
        _tagController.clear();
      });
    } else {
      _tagController.clear();
    }
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _removeTag(String tag) {
    setState(() {
      _currentTags.remove(tag);
    });
  }

  Future<void> _saveTags() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await TagSearchService.updateVideoTags(widget.video, _currentTags);

    final videoBox = Hive.box<Video>('videos');
    final savedVideo = videoBox.get(widget.video.key);
    final saveSuccess = listEquals(savedVideo?.tags, _currentTags);

    if (mounted) {
      Navigator.pop(context);
      Navigator.pop(context, saveSuccess);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saveSuccess ? '标签已更新' : '标签保存失败，请重试'),
        ),
      );
    }
  }

  // 检查标签是否有变化
  bool _hasTagChanges() {
    if (_originalTags.length != _currentTags.length) return true;
    for (int i = 0; i < _originalTags.length; i++) {
      if (_originalTags[i] != _currentTags[i]) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 监听返回事件
      onWillPop: () async {
        if (_hasTagChanges()) {
          // 显示确认对话框
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('标签已修改'),
              content: const Text('是否保存标签修改？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false), // 不保存
                  child: const Text('放弃'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true), // 保存
                  child: const Text('保存'),
                ),
              ],
            ),
          );

          if (result == true) {
            // 先保存再返回
            await _saveTags();
            return true;
          } else if (result == false) {
            // 直接放弃返回
            return true;
          } else {
            // 取消返回
            return false;
          }
        }
        // 无变化直接返回
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('编辑视频标签'),
          // 移除原顶部保存按钮，移至底部
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 标签输入框
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        hintText: '输入标签后按添加',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTag,
                        ),
                      ),
                      onSubmitted: (_) => _addTag(),
                      focusNode: _focusNode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addTag,
                    child: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 当前标签
              if (_currentTags.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '当前标签:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _currentTags
                      .map((tag) => Chip(
                            label: Text(tag),
                            deleteIcon: const Icon(Icons.close),
                            onDeleted: () => _removeTag(tag),
                          ))
                      .toList(),
                ),
                const Divider(height: 32),
              ],
              // 推荐标签
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '推荐标签:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Wrap(
                  spacing: 8, // 水平间距（与当前标签一致）
                  runSpacing: 8, // 垂直间距（与当前标签一致）
                  children: _allTags
                      .where((tag) => !_currentTags.contains(tag.name))
                      .map((tag) => InputChip(
                            // 使用InputChip替代ElevatedButton
                            label: Text(
                              tag.name,
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 18),
                            ),
                            backgroundColor:
                                const Color.fromARGB(255, 255, 247, 178),
                            labelStyle: const TextStyle(color: Colors.black87),
                            onPressed: () {
                              setState(() {
                                _currentTags.add(tag.name);
                              });
                            },
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        // 底部保存按钮
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                elevation: 4,
              ),
              onPressed: _saveTags,
              child: const Text(
                '保存标签',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

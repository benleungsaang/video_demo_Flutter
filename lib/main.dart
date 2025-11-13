import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_demo/models/video.dart';
import 'package:video_demo/models/tag.dart';
import 'package:video_demo/pages/local_videos.dart';
import 'package:video_demo/pages/tag_management.dart';
import 'package:video_demo/pages/server_control.dart';
import 'package:video_demo/utils/permission_utils.dart';

void main() async {
  // 初始化Hive数据库
  await Hive.initFlutter();
  // 注册 【 视频 】 适配器
  Hive.registerAdapter(VideoAdapter());
  // 注册 【 标签 】 适配器
  Hive.registerAdapter(TagAdapter());
  // 打开 【 视频 】 数据库表
  await Hive.openBox<Video>('videos');
  // 打开 【 标签 】 数据库表
  await Hive.openBox<Tag>('tags');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '包装机械视频管理',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0; // 当前选中的页面索引

  // 页面列表，和底部导航对应
  final List<Widget> _pages = const [
    LocalVideosPage(),
    TagManagementPage(),
    ServerControlPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 检查权限
    _checkPermissions();
  }

  // 检查并请求权限
  void _checkPermissions() async {
    bool hasPermissions = await PermissionUtils.checkAndRequestAllPermissions();
    if (!hasPermissions && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('权限不足'),
          content: const Text('请授予必要的权限以使用应用功能'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // 显示当前选中的页面
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index), // 切换页面
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: '本地视频',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tag),
            label: '标签管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.computer),
            label: '服务器',
          ),
        ],
      ),
    );
  }
}

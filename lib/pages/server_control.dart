import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
// import 'package:path_provider/path_provider.dart';
import 'package:video_demo/services/server_service.dart';
import 'package:video_demo/utils/path_utils.dart';

class ServerControlPage extends StatefulWidget {
  const ServerControlPage({super.key});

  @override
  State<ServerControlPage> createState() => _ServerControlPageState();
}

class _ServerControlPageState extends State<ServerControlPage> {
  bool isServerRunning = false;
  String? localIp;
  int port = 8080;
  String? _statusMessage;
  String? _rootDirectory;

  @override
  void initState() {
    super.initState();
    getLocalIp();
    _getDefaultRootPath();
    // 监听服务器状态变化
    ServerService.serverStatusNotifier.addListener(_updateServerStatus);
    // 初始化状态
    _updateServerStatus();
  }

  void _updateServerStatus() {
    setState(() {
      isServerRunning = ServerService.isServerRunning();
    });
  }

  @override
  void dispose() {
    // 移除监听器
    ServerService.serverStatusNotifier.removeListener(_updateServerStatus);
    super.dispose();
  }

  Future<void> _getDefaultRootPath() async {
    // 使用统一视频目录作为根目录
    final directory = await PathUtils.unifiedVideoDirectory;
    setState(() {
      _rootDirectory = directory;
    });
  }

  Future<void> getLocalIp() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.wifi) {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            setState(() {
              localIp = addr.address;
            });
            return;
          }
        }
      }
    }
    setState(() {
      localIp = '未连接到WiFi';
    });
  }

  Future<void> toggleServer() async {
    if (isServerRunning) {
      // 停止服务器
      String message = await ServerService.stopServer();
      setState(() {
        isServerRunning = false;
        _statusMessage = message;
      });
    } else {
      // 启动服务器
      if (localIp != null && _rootDirectory != null && localIp != '未连接到WiFi') {
        String? message =
            await ServerService.startServer(localIp!, port, _rootDirectory!);
        setState(() {
          isServerRunning = ServerService.isServerRunning();
          _statusMessage = message;
        });
      } else {
        setState(() {
          _statusMessage = '无法启动服务器: IP地址无效或未设置根目录';
        });
      }
    }

    // 显示状态消息
    if (_statusMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_statusMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器控制'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('服务器状态'),
                Switch(
                  value: isServerRunning,
                  onChanged: (value) => toggleServer(),
                ),
              ],
            ),
            const Divider(),
            Text('本地IP: ${localIp ?? "获取中..."}'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('端口: '),
                SizedBox(
                  width: 100,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: port.toString()),
                    onChanged: (value) {
                      port = int.tryParse(value) ?? 8080;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('根目录: ${_rootDirectory ?? "获取中..."}'),
            const SizedBox(height: 16),
            if (isServerRunning && localIp != null && localIp!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '访问地址:\nhttp://$localIp:$port',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: isServerRunning ? Colors.green : Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

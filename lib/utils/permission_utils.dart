// ignore_for_file: avoid_print

import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  // 请求存储权限（适配Android 13+）
  static Future<bool> requestStoragePermission() async {
    // 检查Android版本，使用对应的权限
    if (await Permission.photos.isGranted ||
        await Permission.videos.isGranted ||
        await Permission.audio.isGranted) {
      return true;
    }

    // 根据需要请求对应的媒体权限
    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,
      Permission.videos,
    ].request();

    return statuses[Permission.photos]!.isGranted ||
           statuses[Permission.videos]!.isGranted;
  }

  // 网络权限不需要主动请求，改为检查网络连接状态
  static Future<bool> checkNetworkConnectivity() async {
    // 实际项目中应使用connectivity_plus检查网络连接
    return true;
  }

  // 检查并请求所有必要权限
  static Future<bool> checkAndRequestAllPermissions() async {
    bool storageGranted = await requestStoragePermission();
    bool networkAvailable = await checkNetworkConnectivity();
    return storageGranted && networkAvailable;
  }

  // 在需要请求权限的地方使用
  static Future<bool> requestStoragePermissionWithCallbacks() async {
    PermissionStatus status = await Permission.videos
      .onDeniedCallback(() {
        print('存储权限被拒绝');
      })
      .onGrantedCallback(() {
        print('存储权限已授予');
      })
      .onPermanentlyDeniedCallback(() {
        print('存储权限被永久拒绝，需要去设置页面开启');
        openAppSettings();
      })
      .request();

    return status.isGranted;
  }
}
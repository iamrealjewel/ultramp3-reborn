import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class PermissionService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Check if storage or media audio permission is already granted.
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Desktop / Web don't require mobile permission APIs
      return true;
    }

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return Permission.audio.isGranted;
      } else {
        return Permission.storage.isGranted;
      }
    } else {
      // iOS usage
      return true; // typically iOS doesn't block local file read if accessed correctly, but we'll return true.
    }
  }

  /// Request the appropriate storage/audio permission.
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        final status = await Permission.audio.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else {
      // For iOS, the standard audio/storage permission doesn't exist, we can return true
      return true;
    }
  }
}

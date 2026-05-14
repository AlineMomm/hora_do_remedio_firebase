//lib\services\alarm_permission_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class AlarmPermissionService {
  Future<bool> isNotificationPermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<void> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;

    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<void> openAppSettingsPage() async {
    await openAppSettings();
  }
}
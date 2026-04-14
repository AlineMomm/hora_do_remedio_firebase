import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

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

  Future<void> openGeneralAppSettings() async {
    await openAppSettings();
  }

  Future<void> openAppNotificationSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;

    const intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
    );

    await intent.launch();
  }

  Future<void> openExactAlarmSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;

    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );

    await intent.launch();
  }
}
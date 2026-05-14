import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_callback.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) { _initialized = true; return; }

    await AndroidAlarmManager.initialize();
    _initialized = true;
  }

  Future<void> scheduleMedicationReminder({
    required int id,
    required String medicationName,
    required DateTime scheduledTime,
    String? observation,
  }) async {
    if (!_initialized) await initialize();
    if (kIsWeb) return;

    final now = DateTime.now();
    final effectiveTime = scheduledTime.isAfter(now)
        ? scheduledTime
        : now.add(const Duration(seconds: 5));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_name_$id', medicationName);
    if (observation != null) {
      await prefs.setString('alarm_note_$id', observation);
    }

    await AndroidAlarmManager.oneShotAt(
      effectiveTime,
      id,
      alarmCallback,
      exact: true,
      wakeup: true,
    );
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await AndroidAlarmManager.cancel(id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('alarm_name_$id');
    await prefs.remove('alarm_note_$id');
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    // cancelamento individual é feito pelo MedicationService
  }

  Future<void> testNotification() async {
    await scheduleMedicationReminder(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      medicationName: 'TESTE',
      scheduledTime: DateTime.now().add(const Duration(seconds: 5)),
      observation: 'Alarme de teste',
    );
  }

  Future<void> dispose() async {
    await cancelAllNotifications();
  }
}
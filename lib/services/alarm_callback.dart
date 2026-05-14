import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void alarmCallback(int id) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  final prefs = await SharedPreferences.getInstance();
  final medName = prefs.getString('alarm_name_$id') ?? 'seu remédio';
  final medNote = prefs.getString('alarm_note_$id');

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'medication_channel',
    'Lembretes de Medicamentos',
    channelDescription: 'Notificações de hora do remédio',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm'),
  );

  await flutterLocalNotificationsPlugin.show(
    id,
    'Hora do Remédio 💊',
    'Está na hora de tomar $medName${medNote != null && medNote.isNotEmpty ? ': $medNote' : ''}',
    const NotificationDetails(android: androidDetails),
  );
}
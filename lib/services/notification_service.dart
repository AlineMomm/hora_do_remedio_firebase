import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('🔔 Inicializando serviço de alarme...');

    if (kIsWeb) {
      debugPrint('🌐 Web desativado neste serviço.');
      _initialized = true;
      return;
    }

    try {
      final notificationStatus = await Permission.notification.status;

      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }

      await Alarm.init();
      _initialized = true;
      debugPrint('✅ Serviço de alarme inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar serviço de alarme: $e');
    }
  }

  Future<void> scheduleMedicationReminder({
    required int id,
    required String medicationName,
    required DateTime scheduledTime,
    String? observation,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    if (kIsWeb) {
      debugPrint('🌐 Agendamento web desativado.');
      return;
    }

    try {
      debugPrint('⏰ scheduleMedicationReminder CHAMADO para $medicationName');
      debugPrint('   ID: $id');
      debugPrint('   Horário original: $scheduledTime');
      debugPrint('   Agora: ${DateTime.now()}');

      final now = DateTime.now();
      DateTime effectiveTime = scheduledTime;

      if (!effectiveTime.isAfter(now)) {
        effectiveTime = now.add(const Duration(seconds: 5));
        debugPrint('⚠️ Horário no passado ou igual ao atual. Ajustado para: $effectiveTime');
      }

      final alarmSettings = AlarmSettings(
        id: id,
        dateTime: effectiveTime,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 3),
          volumeEnforced: false,
        ),
        notificationSettings: NotificationSettings(
          title: 'Hora do Remédio 💊',
          body:
              'Está na hora de tomar $medicationName${observation != null && observation.trim().isNotEmpty ? ': $observation' : ''}',
          stopButton: 'Parar',
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);

      final alarms = await Alarm.getAlarms();
      debugPrint('✅ Alarme agendado com sucesso');
      debugPrint('📌 Alarmes ativos: ${alarms.length}');
    } catch (e) {
      debugPrint('❌ Erro ao agendar alarme: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;

    try {
      await Alarm.stop(id);
      debugPrint('✅ Alarme #$id cancelado');
    } catch (e) {
      debugPrint('❌ Erro ao cancelar alarme #$id: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;

    try {
      await Alarm.stopAll();
      debugPrint('✅ Todos os alarmes foram cancelados');
    } catch (e) {
      debugPrint('❌ Erro ao cancelar todos os alarmes: $e');
    }
  }

  Future<void> testNotification() async {
    debugPrint('🧪 Testando alarme em 5 segundos...');

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
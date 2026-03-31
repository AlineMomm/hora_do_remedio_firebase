// lib/services/notification_service.dart
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _mobileNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ==================== INICIALIZAÇÃO ====================
  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('🔔 Inicializando NotificationService...');

    if (kIsWeb) {
      debugPrint(
        '🌐 Notificações web desativadas nesta versão do serviço. '
        'Use uma implementação separada para web, se necessário.',
      );
      _initialized = true;
      return;
    }

    await _initializeMobileNotifications();
    _initialized = true;
  }

  // ==================== MOBILE ====================
  Future<void> _initializeMobileNotifications() async {
    try {
      debugPrint('📱 Mobile: Inicializando notificações...');

      final permissionStatus = await Permission.notification.status;
      if (permissionStatus.isDenied || permissionStatus.isRestricted) {
        debugPrint('📱 Mobile: Solicitando permissão de notificação...');
        await Permission.notification.request();
      }

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _mobileNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      tz.initializeTimeZones();

      debugPrint('📱 Mobile: Notificações inicializadas com sucesso');
    } catch (e) {
      debugPrint('❌ Mobile: Erro ao inicializar notificações: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('📱 Mobile: Notificação clicada: ${response.payload}');
  }

  // ==================== AGENDAMENTO PRINCIPAL ====================
  Future<void> scheduleMedicationReminder({
    required int id,
    required String medicationName,
    required DateTime scheduledTime,
    String? observation,
  }) async {
    debugPrint('📅 scheduleMedicationReminder CHAMADO para $medicationName');
    debugPrint('   ID: $id');
    debugPrint('   Horário: $scheduledTime');
    debugPrint('   Agora: ${DateTime.now()}');
    debugPrint('   kIsWeb = $kIsWeb');

    if (kIsWeb) {
      debugPrint(
        '🌐 Agendamento web desativado nesta versão do serviço.',
      );
      return;
    }

    await _scheduleMobileNotification(
      id: id,
      medicationName: medicationName,
      scheduledTime: scheduledTime,
      observation: observation,
    );
  }

  // ==================== MOBILE: AGENDAMENTO ====================
  Future<void> _scheduleMobileNotification({
    required int id,
    required String medicationName,
    required DateTime scheduledTime,
    String? observation,
  }) async {
    try {
      debugPrint('📱 Mobile: Agendando $medicationName para $scheduledTime');

      final now = DateTime.now();
      DateTime effectiveTime = scheduledTime;

      // Evita tentar agendar no passado
      if (effectiveTime.isBefore(now)) {
        effectiveTime = DateTime(
          now.year,
          now.month,
          now.day + 1,
          scheduledTime.hour,
          scheduledTime.minute,
          scheduledTime.second,
        );
        debugPrint(
          '⚠️ Horário já passou. Reagendado para: $effectiveTime',
        );
      }

      final scheduledDate = tz.TZDateTime.from(effectiveTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'medication_channel',
        'Lembretes de Medicamentos',
        channelDescription: 'Canal para lembretes de medicamentos',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _mobileNotifications.zonedSchedule(
        id,
        'Hora do Remédio 💊',
        'Está na hora de tomar $medicationName'
            '${observation != null && observation.trim().isNotEmpty ? ': $observation' : ''}',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'medication_$id',
      );

      debugPrint('✅ Mobile: Notificação agendada com sucesso');
    } catch (e) {
      debugPrint('❌ Mobile: Erro ao agendar: $e');
    }
  }

  // ==================== CANCELAMENTO ====================
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) {
      debugPrint('🌐 Cancelamento web desativado nesta versão do serviço.');
      return;
    }

    await _mobileNotifications.cancel(id);
    debugPrint('✅ Notificação #$id cancelada');
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) {
      debugPrint(
        '🌐 Cancelamento web desativado nesta versão do serviço.',
      );
      return;
    }

    await _mobileNotifications.cancelAll();
    debugPrint('✅ Todas as notificações foram canceladas');
  }

  // ==================== TESTE ====================
  Future<void> testNotification() async {
    debugPrint('🧪 Testando notificação em 5 segundos...');

    await scheduleMedicationReminder(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      medicationName: 'TESTE',
      scheduledTime: DateTime.now().add(const Duration(seconds: 5)),
      observation: 'Notificação de teste',
    );
  }

  // ==================== DISPOSE ====================
  Future<void> dispose() async {
    await cancelAllNotifications();
  }
}
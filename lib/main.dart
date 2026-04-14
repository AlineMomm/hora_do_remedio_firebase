import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/medication_list_page.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'package:hora_do_remedio/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase.initializeApp() concluído com sucesso');
  } catch (e) {
    print('❌ Erro ao inicializar Firebase: $e');
    return;
  }

  // INICIALIZAR NOTIFICAÇÕES
  try {
    await NotificationService().initialize();
    print('✅ Notificações inicializadas');
  } catch (e) {
    print('❌ Erro ao inicializar notificações: $e');
  }

  // Carregar configurações
  final settingsService = SettingsService();
  await settingsService.loadSettings();
  print('✅ Configurações carregadas: ${settingsService.currentFontSize.label}');

  runApp(MyApp(settingsService: settingsService));
}


class MyApp extends StatelessWidget {
  final SettingsService settingsService;

  const MyApp({super.key, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settingsService,
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          print(
              '🔄 Reconstruindo tema - Fonte: ${settings.currentFontSize.label}');

          return MaterialApp(
            title: 'Hora do Remédio',
            theme: _buildTheme(settings),
            home: const MedicationListPage(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(SettingsService settings) {
    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF1976D2),
        secondary: const Color(0xFF388E3C),
        error: const Color(0xFFD32F2F),
        background: Colors.white,
        surface: const Color(0xFFF5F5F5),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onBackground: const Color(0xFF212121),
        onSurface: const Color(0xFF212121),
      ),
      scaffoldBackgroundColor: Colors.white,
      fontFamily: 'Roboto',
      useMaterial3: false,
      textTheme: _getTextTheme(settings.currentFontSize),
      appBarTheme: AppBarTheme(
        titleTextStyle: TextStyle(
          fontSize: 20 * _getScaleFactor(settings.currentFontSize),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: TextStyle(
            fontSize: 14 * _getScaleFactor(settings.currentFontSize),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16 * _getScaleFactor(settings.currentFontSize),
            vertical: 12 * _getScaleFactor(settings.currentFontSize),
          ),
        ),
      ),
    );
  }

  TextTheme _getTextTheme(FontSize fontSize) {
    final scaleFactor = _getScaleFactor(fontSize);

    return TextTheme(
      displayLarge:
          TextStyle(fontSize: 96 * scaleFactor, fontWeight: FontWeight.w300),
      displayMedium:
          TextStyle(fontSize: 60 * scaleFactor, fontWeight: FontWeight.w300),
      displaySmall:
          TextStyle(fontSize: 48 * scaleFactor, fontWeight: FontWeight.w400),
      headlineLarge:
          TextStyle(fontSize: 40 * scaleFactor, fontWeight: FontWeight.w400),
      headlineMedium:
          TextStyle(fontSize: 34 * scaleFactor, fontWeight: FontWeight.w400),
      headlineSmall:
          TextStyle(fontSize: 24 * scaleFactor, fontWeight: FontWeight.w400),
      titleLarge:
          TextStyle(fontSize: 20 * scaleFactor, fontWeight: FontWeight.w500),
      titleMedium:
          TextStyle(fontSize: 16 * scaleFactor, fontWeight: FontWeight.w400),
      titleSmall:
          TextStyle(fontSize: 14 * scaleFactor, fontWeight: FontWeight.w500),
      bodyLarge:
          TextStyle(fontSize: 16 * scaleFactor, fontWeight: FontWeight.w400),
      bodyMedium:
          TextStyle(fontSize: 14 * scaleFactor, fontWeight: FontWeight.w400),
      bodySmall:
          TextStyle(fontSize: 12 * scaleFactor, fontWeight: FontWeight.w400),
      labelLarge:
          TextStyle(fontSize: 14 * scaleFactor, fontWeight: FontWeight.w500),
      labelMedium:
          TextStyle(fontSize: 12 * scaleFactor, fontWeight: FontWeight.w400),
      labelSmall:
          TextStyle(fontSize: 11 * scaleFactor, fontWeight: FontWeight.w400),
    ).apply(
      displayColor: const Color(0xFF212121),
      bodyColor: const Color(0xFF212121),
    );
  }

  double _getScaleFactor(FontSize fontSize) {
    switch (fontSize) {
      case FontSize.pequeno:
        return 0.85;
      case FontSize.normal:
        return 1.0;
      case FontSize.grande:
        return 1.15;
      case FontSize.muitoGrande:
        return 1.3;
      case FontSize.enorme:
        return 1.5;
    }
  }
}

// Extensão para SyncService
extension SyncServiceExtension on SyncService {
  Future<String?> getCurrentUserId() async {
    final cloudId = await getCloudUserId();
    if (cloudId != null) return cloudId;
    return await getLocalUserId();
  }
}

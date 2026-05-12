import 'package:flutter/material.dart';
import '../services/alarm_permission_service.dart';
import '../services/notification_service.dart';

class AlarmPermissionsPage extends StatefulWidget {
  const AlarmPermissionsPage({super.key});

  @override
  State<AlarmPermissionsPage> createState() => _AlarmPermissionsPageState();
}

class _AlarmPermissionsPageState extends State<AlarmPermissionsPage> {
  final AlarmPermissionService _permissionService = AlarmPermissionService();

  bool _loading = true;
  bool _testingAlarm = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (!mounted) return;
  
    setState(() {
      _loading = false;
    });
  }

  Future<void> _openAppSettings() async {
  await _permissionService.openAppSettingsPage();
}

  Future<void> _testAlarm() async {
    setState(() {
      _testingAlarm = true;
    });

    try {
      await NotificationService().testNotification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Teste iniciado. O alarme deve tocar em 5 segundos.',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao testar alarme: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _testingAlarm = false;
        });
      }
    }
  }

  Widget _buildStepCard({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
    bool completed = false,
    IconData icon = Icons.settings,
    Color? color,
  }) {
    final cardColor = completed ? Colors.green[50] : Colors.white;
    final borderColor = completed ? Colors.green : (color ?? Colors.blue);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed ? Icons.check_circle : icon,
                  color: completed ? Colors.green : borderColor,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: const TextStyle(
                fontSize: 18,
                height: 1.4,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: completed ? Colors.green : borderColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1976D2), width: 2),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como configurar',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Vamos ativar as permissões para o alarme aparecer certinho.',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF0D47A1),
              height: 1.4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Quando abrir a tela do celular, ative as opções e depois volte para o aplicativo.',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF0D47A1),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _testingAlarm ? null : _testAlarm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _testingAlarm ? 'TESTANDO...' : 'TESTAR ALARME',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _loadStatus,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: const BorderSide(color: Color(0xFF1565C0), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'ATUALIZAR STATUS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
        ),
      ],
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Configurar Alarmes',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 80,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildInstructionBox(),

                  _buildStepCard(
                    title: 'Configurar o App',
                    description:
                        'Na próxima tela, ative tudo:\n\n'
                        '• Notificações\n'
                        '• Alarmes e lembretes\n'
                        '• Mostrar na tela de bloqueio\n'
                        '• Permitir atividade em segundo plano\n\n'
                        'Isso ajuda o alarme a funcionar corretamente.',
                    buttonText: 'ABRIR CONFIGURAÇÕES',
                    onPressed: _openAppSettings,
                    icon: Icons.settings,
                    color: const Color(0xFF1565C0),
                  ),

                  const SizedBox(height: 10),
                  _buildBottomButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
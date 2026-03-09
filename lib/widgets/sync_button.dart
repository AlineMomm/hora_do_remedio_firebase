import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/firebase_service.dart';
import '../pages/cloud_login_page.dart';

class SyncButton extends StatefulWidget {
  final VoidCallback onSyncComplete;
  
  const SyncButton({
    super.key,
    required this.onSyncComplete,
  });

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> {
  final SyncService _syncService = SyncService();
  bool _isSyncing = false;

  Future<void> _handleSyncPress() async {
    // Verificar status da sincronização
    final status = await _syncService.getSyncStatus();
    
    if (!status['hasInternet']) {
      _showMessage(
        'Sem conexão',
        'Você precisa estar conectado à internet para sincronizar.',
        Icons.wifi_off,
      );
      return;
    }

    if (status['isLoggedIn']) {
      // Já está logado, pergunta se quer sincronizar
      _showSyncDialog();
    } else {
      // Não está logado, oferece opções de login/registro
      _showLoginOptions();
    }
  }

  void _showLoginOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sincronizar com a Nuvem'),
        content: const Text(
          'Para sincronizar seus dados com a nuvem, você precisa ter uma conta.\n\n'
          'Isso permite que seus medicamentos fiquem salvos mesmo se você trocar de celular!'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Agora não'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToCloudLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
            ),
            child: const Text('Fazer Login/Cadastro'),
          ),
        ],
      ),
    );
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sincronizar Dados'),
        content: const Text(
          'Deseja sincronizar seus medicamentos com a nuvem?\n\n'
          'Isso vai enviar todos os seus dados locais para sua conta na nuvem.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performSync();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('Sincronizar Agora'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSync() async {
  setState(() {
    _isSyncing = true;
  });

  try {
    final cloudUserId = await _syncService.getCloudUserId();
    if (cloudUserId != null) {
      await _syncService.syncLocalToCloud(cloudUserId);
      
      if (!mounted) return;
      
      _showMessage(
        'Sucesso!',
        'Dados sincronizados com a nuvem.',
        Icons.cloud_done,
        isSuccess: true,
      );
      
      // Atualizar a lista após sincronizar
      widget.onSyncComplete();
    }
  } catch (e) {
    if (!mounted) return;
    
    _showMessage(
      'Erro',
      'Não foi possível sincronizar: $e',
      Icons.error,
      isSuccess: false,
    );
  } finally {
    setState(() {
      _isSyncing = false;
    });
  }
}

  void _showMessage(String title, String message, IconData icon, {bool isSuccess = true}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 50,
              color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F),
            ),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToCloudLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CloudLoginPage(
          onLoginSuccess: () {
            widget.onSyncComplete();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.cloud_upload),
          onPressed: _isSyncing ? null : _handleSyncPress,
          tooltip: 'Sincronizar com a nuvem',
        ),
        if (_isSyncing)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ),
      ],
    );
  }
}
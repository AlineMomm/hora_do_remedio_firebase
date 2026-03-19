import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/medication_service.dart';
import '../models/medication_model.dart';
import 'add_medication_page.dart';
import 'help_page.dart';
import 'profile_page.dart';
import '../widgets/sync_button.dart';
import '../services/sync_service.dart';
import 'settings_page.dart';
import '../services/settings_service.dart';

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  final MedicationService _medicationService = MedicationService();
  List<MedicationModel> _medications = [];
  bool _isLoading = true;
  
  final SyncService _syncService = SyncService(); // Já existe
  String _currentUserId = 'local_user_001';

  @override
  void initState() {
    super.initState();
    _syncService.addListener(_onSyncChange); // Adicionar listener
    _initializeUserAndLoad();
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncChange); // Remover listener
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUserAndLoad();
  }

void _onSyncChange() {
    // Quando o status de sincronização mudar (login/logout), recarregar
    print('🔄 SyncService mudou, recarregando medicamentos...');
    _checkUserAndLoad();
  }
  
  Future<void> _initializeUserAndLoad() async {
    final existingLocalId = await _syncService.getLocalUserId();
    if (existingLocalId == null) {
      await _syncService.setLocalUserId(_currentUserId);
      print('✅ ID local salvo: $_currentUserId');
    } else {
      _currentUserId = existingLocalId;
      print('📌 ID local existente: $_currentUserId');
    }
    
    await _checkUserAndLoad();
  }

  Future<String> _getEffectiveUserId() async {
    final status = await _syncService.getSyncStatus();
    if (status['isLoggedIn'] && status['cloudUserId'] != null) {
      return status['cloudUserId'];
    }
    return _currentUserId;
  }

  Future<void> _checkUserAndLoad() async {
  final status = await _syncService.getSyncStatus();
  
  if (status['isLoggedIn']) {
    _currentUserId = status['cloudUserId'];
    print('✅ Usuário logado na nuvem: $_currentUserId');
    
    try {
      // Carregar medicamentos da nuvem
      final cloudMeds = await _syncService.loadFromCloud(_currentUserId);
      
      // Garantir que estamos usando a lista mais atualizada
      final updatedMeds = await _medicationService.getMedicationsList(_currentUserId);
      
      // Ordenar medicamentos
      updatedMeds.sort((a, b) {
        if (a.hour != b.hour) return a.hour.compareTo(b.hour);
        if (a.minute != b.minute) return a.minute.compareTo(b.minute);
        return a.name.compareTo(b.name);
      });
      
      setState(() {
        _medications = updatedMeds;
        _isLoading = false;
      });
      
      print('📦 Medicamentos carregados da nuvem: ${updatedMeds.length}');
      for (var i = 0; i < updatedMeds.length; i++) {
        print('   ${i+1}. ${updatedMeds[i].name} - ${updatedMeds[i].formattedTime}');
      }
      
    } catch (e) {
      print('❌ Erro ao carregar da nuvem: $e');
      // Se falhar, tenta carregar local
      await _loadMedications();
    }
  } else {
    print('📌 Usuário não logado, carregando medicamentos locais');
    await _loadMedications();
  }
}
  Future<void> _loadMedications() async {
    try {
      final userId = await _getEffectiveUserId();
      final medications = await _medicationService.getMedicationsList(userId);
      
      setState(() {
        _medications = medications;
        _isLoading = false;
      });
      
      print('📦 Medicamentos carregados para $userId: ${medications.length}');
      
      for (var i = 0; i < medications.length; i++) {
        print('   ${i+1}. ${medications[i].name} - ${medications[i].formattedTime}');
      }
    } catch (e) {
      print('❌ Erro ao carregar medicamentos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _confirmDeleteMedication(MedicationModel medication) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Medicamento'),
        content: Text('Tem certeza que deseja excluir "${medication.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMedication(medication.id);
            },
            child: const Text(
              'Excluir',
              style: TextStyle(color: Color(0xFFD32F2F)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMedication(String medicationId) async {
    try {
      await _medicationService.deleteMedication(medicationId);
      await _loadMedications();
      
      final status = await _syncService.getSyncStatus();
      if (status['isLoggedIn']) {
        await _syncService.syncLocalToCloud(status['cloudUserId']);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicamento excluído com sucesso!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir medicamento: $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  void _editMedication(MedicationModel medication) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicationPage(
          medication: medication,
          localUserId: _currentUserId,
        ),
      ),
    ).then((_) async {
      await _loadMedications();
      
      final status = await _syncService.getSyncStatus();
      if (status['isLoggedIn']) {
        await _syncService.syncLocalToCloud(status['cloudUserId']);
      }
    });
  }

  Future<void> _navigateToAddMedication() async {
  final userId = await _getEffectiveUserId();
  if (!mounted) return;
  
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AddMedicationPage(
        localUserId: userId,
      ),
    ),
  );
  
  // Recarregar medicamentos após voltar da tela de adição
  await _checkUserAndLoad();
}

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
  title: Container(
    height: 60, // Altura reduzida
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Image.asset(
      'assets/logo_hora_remedio.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              'HORA DO REMÉDIO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    ),
  ),
  backgroundColor: const Color(0xFF1565C0),
  foregroundColor: Colors.white,
  elevation: 2,
  toolbarHeight: 80, // AppBar mais baixa para centralizar melhor
  centerTitle: true,
  actions: [
    // Configurações
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, // Centralizar verticalmente
        children: [
          IconButton(
            icon: Icon(Icons.settings, size: 28, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            padding: const EdgeInsets.all(4),
          ),
          Text(
            'Config.',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    ),
    
    // Ajuda
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, // Centralizar verticalmente
        children: [
          IconButton(
            icon: Icon(Icons.help_outline, size: 28, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpPage()),
              );
            },
            padding: const EdgeInsets.all(4),
          ),
          Text(
            'Ajuda',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    ),
    
    // Perfil
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, // Centralizar verticalmente
        children: [
          IconButton(
            icon: Icon(Icons.person, size: 28, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            padding: const EdgeInsets.all(4),
          ),
          Text(
            'Perfil',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    ),
  ],
),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF1565C0)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Carregando seus medicamentos...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF212121),
                    ),
                  ),
                ],
              ),
            )
          : _medications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        height: 120,
                        width: 120,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.medical_services,
                            size: 120,
                            color: Colors.grey[300],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Nenhum medicamento cadastrado',
                        style: settings.getTextStyle(
                          size: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toque no botão abaixo para adicionar seu primeiro medicamento',
                        textAlign: TextAlign.center,
                        style: settings.getTextStyle(
                          size: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildAddButton(settings),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _medications.length,
                        itemBuilder: (context, index) {
                          final medication = _medications[index];
                          return _buildMedicationCard(medication, settings);
                        },
                      ),
                    ),
                    _buildAddButton(settings),
                  ],
                ),
    );
  }

  // Botão de adicionar medicamento
  Widget _buildAddButton(SettingsService settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _navigateToAddMedication,
        style: settings.getElevatedButtonStyle(
          backgroundColor: const Color(0xFF2E7D32), // Verde escuro
          foregroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: settings.iconSize,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ADICIONAR MEDICAMENTO',
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: true,
                style: settings.getTextStyle(
                  size: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        )
      ),
    );
  }

  Widget _buildMedicationCard(MedicationModel medication, SettingsService settings) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha do nome e botões
            Row(
              children: [
                Expanded(
                  child: Text(
                    medication.name,
                    style: settings.getTextStyle(
                      size: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF212121),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editMedication(medication),
                      color: const Color(0xFFF57C00),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _confirmDeleteMedication(medication),
                      color: const Color(0xFFD32F2F),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                // Horário
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${medication.formattedTime}',
                      style: settings.getTextStyle(
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                // Frequência
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      medication.frequency,
                      style: settings.getTextStyle(
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Observações
            if (medication.notes != null && medication.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      medication.notes!,
                      style: settings.getTextStyle(
                        size: 14,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
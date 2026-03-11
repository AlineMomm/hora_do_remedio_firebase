import 'package:flutter/material.dart';
import '../services/medication_service.dart';
import '../models/medication_model.dart';
import 'add_medication_page.dart';
import 'help_page.dart';
import 'profile_page.dart';
import '../widgets/sync_button.dart';
import '../services/sync_service.dart';

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  final MedicationService _medicationService = MedicationService();
  List<MedicationModel> _medications = [];
  bool _isLoading = true;
  
  final SyncService _syncService = SyncService();
  String _currentUserId = 'local_user_001'; // ID padrão para usuário não logado

  @override
  void initState() {
    super.initState();
    _initializeUserAndLoad();
  }

  // NOVO: Inicializar e salvar o ID do usuário local
  Future<void> _initializeUserAndLoad() async {
    // Salvar o ID do usuário local se ainda não existir
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
    
    try {
      final cloudMeds = await _syncService.loadFromCloud(_currentUserId);
      cloudMeds.sort((a, b) {
        if (a.hour != b.hour) return a.hour.compareTo(b.hour);
        if (a.minute != b.minute) return a.minute.compareTo(b.minute);
        return a.name.compareTo(b.name);
      });
      
      setState(() {
        _medications = cloudMeds;
        _isLoading = false;
      });
    } catch (e) {
      await _loadMedications();
    }
  } else {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medical_services,
                  color: Colors.white,
                  size: 24,
                ),
              );
            },
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hora do Remédio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Cuide da sua saúde',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          SyncButton(
            onSyncComplete: _loadMedications,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpPage()),
              );
            },
            tooltip: 'Ajuda',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            tooltip: 'Perfil',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF1976D2)),
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
                      const Text(
                        'Nenhum medicamento cadastrado',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toque no botão + para adicionar seu primeiro medicamento',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          final userId = await _getEffectiveUserId();
                          if (!mounted) return;
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddMedicationPage(
                                localUserId: userId,
                              ),
                            ),
                          ).then((_) async {
                            await _loadMedications();
                            
                            final status = await _syncService.getSyncStatus();
                            if (status['isLoggedIn']) {
                              await _syncService.syncLocalToCloud(status['cloudUserId']);
                            }
                          });
                        },
                        child: const Text('Adicionar Primeiro Medicamento'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _medications.length,
                  itemBuilder: (context, index) {
                    final medication = _medications[index];
                    return _buildMedicationCard(medication);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final userId = await _getEffectiveUserId();
          if (!mounted) return;
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMedicationPage(
                localUserId: userId,
              ),
            ),
          ).then((_) async {
            await _loadMedications();
            
            final status = await _syncService.getSyncStatus();
            if (status['isLoggedIn']) {
              await _syncService.syncLocalToCloud(status['cloudUserId']);
            }
          });
        },
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMedicationCard(MedicationModel medication) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editMedication(medication),
                      color: const Color(0xFFF57C00),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _confirmDeleteMedication(medication),
                      color: const Color(0xFFD32F2F),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Horário: ${medication.formattedTime}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.repeat,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Frequência: ${medication.frequency}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (medication.notes != null && medication.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Observações: ${medication.notes}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
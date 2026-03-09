import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/medication_service.dart';
import '../models/medication_model.dart';
import 'medication_list_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final LocalStorageService _storage = LocalStorageService();
  final SyncService _syncService = SyncService();
  final AuthService _authService = AuthService();
  final MedicationService _medicationService = MedicationService();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _ageController;
  late TextEditingController _bloodTypeController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _observationsController;

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isCloudUser = false;
  
  final String _profileId = 'local_profile_001';
  final String _localUserId = 'local_user_001';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadProfile();
    _checkCloudStatus();
  }

  Future<void> _checkCloudStatus() async {
    final status = await _syncService.getSyncStatus();
    setState(() {
      _isCloudUser = status['isLoggedIn'] ?? false;
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await _getProfile();
      
      _nameController.text = profile['name'] ?? '';
      _emailController.text = profile['email'] ?? '';
      _phoneController.text = profile['phone'] ?? '';
      _ageController.text = profile['age']?.toString() ?? '';
      _bloodTypeController.text = profile['bloodType'] ?? '';
      _emergencyNameController.text = profile['emergencyContactName'] ?? '';
      _emergencyPhoneController.text = profile['emergencyContactPhone'] ?? '';
      _observationsController.text = profile['observations'] ?? '';
      
    } catch (e) {
      print('❌ Erro ao carregar perfil: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getProfile() async {
    final profiles = await _storage.getUsers();
    return profiles.firstWhere(
      (p) => p['uid'] == _profileId,
      orElse: () => {},
    );
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _ageController = TextEditingController();
    _bloodTypeController = TextEditingController();
    _emergencyNameController = TextEditingController();
    _emergencyPhoneController = TextEditingController();
    _observationsController = TextEditingController();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _loadProfile();
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final profile = {
          'uid': _profileId,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()),
          'bloodType': _bloodTypeController.text.trim(),
          'emergencyContactName': _emergencyNameController.text.trim(),
          'emergencyContactPhone': _emergencyPhoneController.text.trim(),
          'observations': _observationsController.text.trim(),
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        };

        await _storage.saveUser(profile);

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        
        setState(() {
          _isEditing = false;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar perfil: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // NOVO: Salvar medicamentos da nuvem localmente antes do logout
  Future<void> _saveCloudMedsLocally() async {
    try {
      final status = await _syncService.getSyncStatus();
      if (!status['isLoggedIn'] || status['cloudUserId'] == null) return;

      print('🔄 Salvando medicamentos da nuvem para uso local...');
      
      // Carregar medicamentos da nuvem
      final cloudMeds = await _syncService.loadFromCloud(status['cloudUserId']);
      
      if (cloudMeds.isNotEmpty) {
        print('📦 Salvando ${cloudMeds.length} medicamentos localmente');
        
        // Primeiro, limpar medicamentos locais antigos
        final localMeds = await _medicationService.getMedicationsList(_localUserId);
        for (var med in localMeds) {
          await _medicationService.deleteMedication(med.id);
        }
        
        // Salvar medicamentos da nuvem com o ID local
        for (var med in cloudMeds) {
          final localMed = MedicationModel(
            id: med.id, // Manter o mesmo ID
            userId: _localUserId, // Trocar para o ID local
            name: med.name,
            hour: med.hour,
            minute: med.minute,
            frequency: med.frequency,
            notes: med.notes,
            createdAt: med.createdAt,
          );
          await _medicationService.addMedication(localMed);
        }
        
        print('✅ Medicamentos salvos localmente com sucesso!');
      }
    } catch (e) {
      print('❌ Erro ao salvar medicamentos localmente: $e');
      rethrow;
    }
  }

  // MODIFICADO: Função para mostrar diálogo de confirmação de saída
  Future<void> _confirmLogout() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Sair da Conta',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Tem certeza que deseja sair da sua conta?\n\n'
            'Seus medicamentos serão salvos no seu celular para você continuar usando mesmo sem internet.',
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'NÃO',
                style: TextStyle(fontSize: 18, color: Color(0xFF1976D2)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'SIM, SAIR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // MODIFICADO: Função para fazer logout (agora salva local primeiro)
  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // PRIMEIRO: Salvar medicamentos da nuvem localmente
      await _saveCloudMedsLocally();
      
      // DEPOIS: Fazer logout do Firebase
      await _syncService.logoutFromCloud();
      
      // Limpar estado de autenticação local
      await _authService.signOut();
      
      if (!mounted) return;

      // Mostrar mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você saiu da sua conta com sucesso!\nSeus medicamentos foram salvos no celular.'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 4),
        ),
      );

      // Voltar para a tela principal (agora com os medicamentos salvos localmente)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MedicationListPage()),
        (route) => false,
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sair da conta: $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFF1976D2),
          child: const Icon(
            Icons.person,
            size: 50,
            color: Colors.white,
          ),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF388E3C),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                onPressed: _changeProfileImage,
              ),
            ),
          ),
        if (_isCloudUser)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_done,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  void _changeProfileImage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar Foto'),
        content: const Text('Funcionalidade de câmera/galeria será implementada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: _toggleEdit,
            tooltip: _isEditing ? 'Cancelar' : 'Editar',
          ),
          if (_isEditing)
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveProfile,
              tooltip: 'Salvar',
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
                    'Carregando perfil...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF212121),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildProfileImage(),
                    const SizedBox(height: 20),
                    
                    // Informações Pessoais
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informações Pessoais',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nome completo',
                                prefixIcon: Icon(Icons.person, color: Color(0xFF757575)),
                              ),
                              enabled: _isEditing,
                              validator: (value) {
                                if (_isEditing && (value == null || value.isEmpty)) {
                                  return 'Por favor, digite seu nome';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                prefixIcon: Icon(Icons.email, color: Color(0xFF757575)),
                              ),
                              enabled: _isEditing,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (_isEditing && value != null && value.isNotEmpty) {
                                  if (!value.contains('@') || !value.contains('.')) {
                                    return 'Digite um e-mail válido';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Telefone',
                                prefixIcon: Icon(Icons.phone, color: Color(0xFF757575)),
                              ),
                              enabled: _isEditing,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _ageController,
                              decoration: const InputDecoration(
                                labelText: 'Idade',
                                prefixIcon: Icon(Icons.cake, color: Color(0xFF757575)),
                              ),
                              enabled: _isEditing,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _bloodTypeController,
                              decoration: const InputDecoration(
                                labelText: 'Tipo Sanguíneo',
                                prefixIcon: Icon(Icons.bloodtype, color: Color(0xFF757575)),
                              ),
                              enabled: _isEditing,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Contato de Emergência
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contato de Emergência',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _emergencyNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nome do contato',
                                prefixIcon: Icon(Icons.contact_emergency, color: Color(0xFF757575)),
                              ),
                              enabled: _isEditing,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _emergencyPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Telefone do contato',
                                prefixIcon: Icon(Icons.phone, color: Color(0xFF757575)),
                              ),
                              enabled: _isEditing,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Observações
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Observações',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _observationsController,
                              decoration: const InputDecoration(
                                labelText: 'Observações médicas ou alergias',
                                prefixIcon: Icon(Icons.note, color: Color(0xFF757575)),
                              ),
                              enabled: _isEditing,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Botão de Sair da Conta (só aparece se estiver logado na nuvem)
                    if (_isCloudUser) ...[
                      Container(
                        width: 280, // Largura fixa menor
                        height: 48, // Altura reduzida
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        child: ElevatedButton(
                          onPressed: _confirmLogout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30), // Mais arredondado
                            ),
                            elevation: 2, // Menos sombra
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min, // Para não expandir
                            children: [
                              Icon(Icons.exit_to_app, size: 20), // Ícone menor
                              SizedBox(width: 8), // Espaço menor
                              Text(
                                'SAIR DA CONTA',
                                style: TextStyle(
                                  fontSize: 16, // Fonte menor
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5, // Leve espaçamento
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Texto explicativo com padding ajustado
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 16),
                        child: Text(
                          'Ao sair, seus medicamentos continuam salvos no celular.\n'
                          'Quando você entrar novamente, eles serão sincronizados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13, // Fonte um pouco menor
                            color: Color(0xFF757575),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _bloodTypeController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _observationsController.dispose();
    super.dispose();
  }
}
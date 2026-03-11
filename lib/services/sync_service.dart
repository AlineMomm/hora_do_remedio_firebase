import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import 'medication_service.dart';
import '../models/medication_model.dart';
import '../models/user_model.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  
  final FirebaseService _firebaseService = FirebaseService();
  final MedicationService _medicationService = MedicationService();
  
  late final FlutterSecureStorage? _secureStorage;
  late final bool _useSecureStorage;
  
  static const String _syncEnabledKey = 'sync_enabled';
  static const String _lastSyncKey = 'last_sync';
  static const String _cloudUserIdKey = 'cloud_user_id';
  static const String _localUserIdKey = 'local_user_id';

  SyncService._internal() {
    if (kIsWeb) {
      _useSecureStorage = false;
      _secureStorage = null;
      print('🌐 Web detectada: usando SharedPreferences');
    } else {
      _useSecureStorage = true;
      _secureStorage = const FlutterSecureStorage();
    }
  }

  Future<bool> hasInternetConnection() async {
    if (kIsWeb) return true;
    try {
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncEnabledKey) ?? false;
  }

  Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, enabled);
  }

  Future<void> setLocalUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUserIdKey, userId);
    print('✅ ID local salvo: $userId');
  }

  Future<String?> getLocalUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localUserIdKey);
  }

  Future<void> setCloudUserId(String? userId) async {
    try {
      if (_useSecureStorage && _secureStorage != null) {
        if (userId == null) {
          await _secureStorage!.delete(key: _cloudUserIdKey);
        } else {
          await _secureStorage!.write(key: _cloudUserIdKey, value: userId);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        if (userId == null) {
          await prefs.remove(_cloudUserIdKey);
        } else {
          await prefs.setString(_cloudUserIdKey, userId);
        }
      }
    } catch (e) {
      print('⚠️ Erro ao salvar ID: $e');
      final prefs = await SharedPreferences.getInstance();
      if (userId == null) {
        await prefs.remove(_cloudUserIdKey);
      } else {
        await prefs.setString(_cloudUserIdKey, userId);
      }
    }
  }

  Future<String?> getCloudUserId() async {
    try {
      if (_useSecureStorage && _secureStorage != null) {
        return await _secureStorage!.read(key: _cloudUserIdKey);
      } else {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_cloudUserIdKey);
      }
    } catch (e) {
      print('⚠️ Erro ao ler ID: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cloudUserIdKey);
    }
  }

  // FUNÇÃO AUXILIAR: Comparar medicamentos por nome e horário (não apenas ID)
  bool _isSameMedication(MedicationModel a, MedicationModel b) {
    return a.name == b.name && 
           a.hour == b.hour && 
           a.minute == b.minute;
  }

  // MODIFICADO: Migrar medicamentos locais para o usuário da nuvem
  Future<void> _migrateLocalMedicationsToCloud(String cloudUserId) async {
    try {
      final localUserId = await getLocalUserId();
      
      print('🔍 Verificando migração: localUserId=$localUserId, cloudUserId=$cloudUserId');
      
      if (localUserId == null) {
        print('⚠️ Nenhum ID local encontrado');
        return;
      }
      
      if (localUserId == cloudUserId) {
        print('📌 IDs iguais, não precisa migrar');
        return;
      }
      
      print('🔄 Migrando medicamentos locais do usuário $localUserId para $cloudUserId...');
      
      // Carregar medicamentos do usuário local
      final localMeds = await _medicationService.getMedicationsList(localUserId);
      
      if (localMeds.isNotEmpty) {
        print('📦 Encontrados ${localMeds.length} medicamentos locais para migrar');
        
        // Carregar medicamentos existentes na nuvem
        final cloudMeds = await _firebaseService.loadMedicationsFromCloud(cloudUserId);
        
        int migrados = 0;
        int ignorados = 0;
        
        for (var localMed in localMeds) {
          bool existeNaNuvem = false;
          
          // Verificar se já existe na nuvem (por nome e horário)
          for (var cloudMed in cloudMeds) {
            if (_isSameMedication(localMed, cloudMed)) {
              existeNaNuvem = true;
              print('   ⏭️ Já existe na nuvem: ${localMed.name} (${localMed.formattedTime})');
              break;
            }
          }
          
          if (!existeNaNuvem) {
            print('   ✅ Migrando: ${localMed.name} (${localMed.formattedTime})');
            final newMed = MedicationModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(), // NOVO ID para evitar conflitos
              userId: cloudUserId,
              name: localMed.name,
              hour: localMed.hour,
              minute: localMed.minute,
              frequency: localMed.frequency,
              notes: localMed.notes,
              createdAt: localMed.createdAt,
            );
            await _medicationService.addMedication(newMed);
            migrados++;
          } else {
            ignorados++;
          }
        }
        
        if (migrados > 0) {
          // Sincronizar com a nuvem
          final allMeds = await _medicationService.getMedicationsList(cloudUserId);
          await _firebaseService.syncMedicationsToCloud(cloudUserId, allMeds);
          print('✅ Migração concluída! $migrados medicamentos migrados, $ignorados ignorados');
        } else {
          print('📌 Nenhum medicamento novo para migrar ($ignorados ignorados)');
        }
      } else {
        print('📦 Nenhum medicamento local para migrar');
      }
    } catch (e) {
      print('❌ Erro na migração: $e');
    }
  }

Future<void> _mergeCloudWithLocal(String cloudUserId) async {
  try {
    print('🔄 Mesclando dados da nuvem com locais...');
    
    final cloudMeds = await _firebaseService.loadMedicationsFromCloud(cloudUserId);
    
    // Ordenar medicamentos da nuvem
    final sortedCloudMeds = List<MedicationModel>.from(cloudMeds);
    sortedCloudMeds.sort((a, b) {
      if (a.hour != b.hour) return a.hour.compareTo(b.hour);
      if (a.minute != b.minute) return a.minute.compareTo(b.minute);
      return a.name.compareTo(b.name);
    });
    
    if (sortedCloudMeds.isNotEmpty) {
      print('📦 Carregando ${sortedCloudMeds.length} medicamentos da nuvem');
      
      final localMeds = await _medicationService.getMedicationsList(cloudUserId);
      
      final Map<String, MedicationModel> existingMeds = {};
      for (var med in localMeds) {
        final key = '${med.name}_${med.hour}_${med.minute}';
        existingMeds[key] = med;
      }
      
      int adicionados = 0;
      int ignorados = 0;
      
      for (var cloudMed in sortedCloudMeds) {
        final key = '${cloudMed.name}_${cloudMed.hour}_${cloudMed.minute}';
        
        if (!existingMeds.containsKey(key)) {
          print('   ✅ Adicionando localmente: ${cloudMed.name} (${cloudMed.formattedTime})');
          await _medicationService.addMedication(cloudMed);
          adicionados++;
        } else {
          print('   ⏭️ Já existe localmente: ${cloudMed.name} (${cloudMed.formattedTime})');
          ignorados++;
        }
      }
      
      print('✅ Mesclagem concluída: $adicionados novos medicamentos adicionados, $ignorados ignorados');
    } else {
      print('📦 Nenhum medicamento na nuvem');
    }
  } catch (e) {
    print('❌ Erro ao mesclar dados: $e');
  }
}

  Future<bool> loginToCloud(String email, String password) async {
  try {
    final user = await _firebaseService.signInWithEmailAndPassword(email, password);
    if (user != null) {
      final oldLocalUserId = await getLocalUserId();
      
      print('🔑 Login: oldLocal=$oldLocalUserId, newCloud=${user.uid}');
      
      await setCloudUserId(user.uid);
      await setSyncEnabled(true);
      
      // PRIMEIRO: Carregar medicamentos da nuvem para local
      // Isso garante que temos os dados mais recentes
      await _mergeCloudWithLocal(user.uid);
      
      // DEPOIS: Migrar dados locais para a nuvem (se houver)
      if (oldLocalUserId != null && oldLocalUserId != user.uid) {
        await _migrateLocalMedicationsToCloud(user.uid);
      }
      
      return true;
    }
    return false;
  } catch (e) {
    print('❌ Erro no login cloud: $e');
    rethrow;
  }
}

  // MODIFICADO: Registro na nuvem com migração
  Future<bool> registerInCloud(String name, String email, String password) async {
    try {
      final user = await _firebaseService.registerWithEmailAndPassword(name, email, password);
      if (user != null) {
        final oldLocalUserId = await getLocalUserId();
        
        print('📝 Registro: oldLocal=$oldLocalUserId, newCloud=${user.uid}');
        
        await setCloudUserId(user.uid);
        await setSyncEnabled(true);
        
        // Migrar dados locais para a nova conta
        if (oldLocalUserId != null) {
          await _migrateLocalMedicationsToCloud(user.uid);
        }
        
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro no registro cloud: $e');
      rethrow;
    }
  }

  Future<void> logoutFromCloud() async {
    await _firebaseService.signOut();
    await setCloudUserId(null);
    await setSyncEnabled(false);
  }

  Future<void> syncLocalToCloud(String userId) async {
    if (!await hasInternetConnection()) {
      throw 'Sem conexão com a internet';
    }

    try {
      final localMeds = await _medicationService.getMedicationsList(userId);
      await _firebaseService.syncMedicationsToCloud(userId, localMeds);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      
      print('✅ Sincronização concluída');
    } catch (e) {
      print('❌ Erro na sincronização: $e');
      rethrow;
    }
  }

  Future<List<MedicationModel>> loadFromCloud(String userId) async {
  if (!await hasInternetConnection()) {
    throw 'Sem conexão com a internet';
  }

  try {
    final cloudMeds = await _firebaseService.loadMedicationsFromCloud(userId);
    
    // Ordenar medicamentos da nuvem
    final sortedCloudMeds = List<MedicationModel>.from(cloudMeds);
    sortedCloudMeds.sort((a, b) {
      if (a.hour != b.hour) return a.hour.compareTo(b.hour);
      if (a.minute != b.minute) return a.minute.compareTo(b.minute);
      return a.name.compareTo(b.name);
    });
    
    final localMeds = await _medicationService.getMedicationsList(userId);
    
    for (var cloudMed in sortedCloudMeds) {
      bool existeLocal = false;
      
      for (var localMed in localMeds) {
        if (_isSameMedication(cloudMed, localMed)) {
          existeLocal = true;
          break;
        }
      }
      
      if (!existeLocal) {
        await _medicationService.addMedication(cloudMed);
      }
    }
    
    return sortedCloudMeds;
  } catch (e) {
    print('❌ Erro ao carregar da nuvem: $e');
    rethrow;
  }
}

  Future<void> updateUserProfileInCloud(UserModel user) async {
  try {
    await _firebaseService.updateUserProfile(user);
    print('✅ Perfil atualizado na nuvem: ${user.name}');
  } catch (e) {
    print('❌ Erro ao atualizar perfil na nuvem: $e');
    rethrow;
  }
}

  Future<Map<String, dynamic>> getSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey);
    final isEnabled = await isSyncEnabled();
    final cloudUserId = await getCloudUserId();
    final hasInternet = await hasInternetConnection();
    final localUserId = await getLocalUserId();

    return {
      'isEnabled': isEnabled,
      'isLoggedIn': cloudUserId != null,
      'lastSync': lastSync != null ? DateTime.fromMillisecondsSinceEpoch(lastSync) : null,
      'hasInternet': hasInternet,
      'cloudUserId': cloudUserId,
      'localUserId': localUserId,
      'isWeb': kIsWeb,
    };
  }
}
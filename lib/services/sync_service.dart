import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import 'medication_service.dart';
import '../models/medication_model.dart';
import '../models/user_model.dart';
import 'package:flutter/material.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  final FirebaseService _firebaseService = FirebaseService();

  late final FlutterSecureStorage? _secureStorage;
  late final bool _useSecureStorage;

  static const String _syncEnabledKey = 'sync_enabled';
  static const String _lastSyncKey = 'last_sync';
  static const String _cloudUserIdKey = 'cloud_user_id';
  static const String _localUserIdKey = 'local_user_id';

  // Getter para verificar se o usuário está logado na nuvem (assíncrono)
  Future<bool> get isLoggedIn async => (await getCloudUserId()) != null;

  // Método para obter o ID do usuário atual (prioriza nuvem, depois local)
  Future<String?> getCurrentUserId() async {
    final cloudId = await getCloudUserId();
    if (cloudId != null) return cloudId;
    return await getLocalUserId();
  }

  // Método para sincronizar medicamentos (usa o ID do usuário atual)
  Future<void> syncMedications() async {
    final userId = await getCurrentUserId();
    if (userId == null) {
      print('⚠️ Nenhum usuário encontrado para sincronizar');
      return;
    }
    await syncLocalToCloud(userId);
  }

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
    return a.name == b.name && a.hour == b.hour && a.minute == b.minute;
  }

  MedicationModel _mergeMedicationState(
  MedicationModel localMed,
  MedicationModel cloudMed,
  String userId,
) {
  DateTime? mergedLastTaken;

  final localLastTaken = localMed.lastTaken;
  final cloudLastTaken = cloudMed.lastTaken;

  if (localLastTaken == null) {
    mergedLastTaken = cloudLastTaken;
  } else if (cloudLastTaken == null) {
    mergedLastTaken = localLastTaken;
  } else {
    mergedLastTaken =
        localLastTaken.isAfter(cloudLastTaken) ? localLastTaken : cloudLastTaken;
  }

  return MedicationModel(
    id: cloudMed.id,
    userId: userId,
    name: cloudMed.name,
    hour: cloudMed.hour,
    minute: cloudMed.minute,
    frequency: cloudMed.frequency,
    notes: cloudMed.notes ?? localMed.notes,
    createdAt: cloudMed.createdAt,
    lastTaken: mergedLastTaken,
  );
}

  // MODIFICADO: Migrar medicamentos locais para o usuário da nuvem
  Future<void> _migrateLocalMedicationsToCloud(String cloudUserId) async {
    try {
      final localUserId = await getLocalUserId();

      print(
          '🔍 Verificando migração: localUserId=$localUserId, cloudUserId=$cloudUserId');

      if (localUserId == null) {
        print('⚠️ Nenhum ID local encontrado');
        return;
      }

      if (localUserId == cloudUserId) {
        print('📌 IDs iguais, não precisa migrar');
        return;
      }

      print(
          '🔄 Migrando medicamentos locais do usuário $localUserId para $cloudUserId...');

      // Carregar medicamentos do usuário local
      final localMeds =
          await MedicationService().getMedicationsList(localUserId);

      if (localMeds.isNotEmpty) {
        print(
            '📦 Encontrados ${localMeds.length} medicamentos locais para migrar');

        // Carregar medicamentos existentes na nuvem
        final cloudMeds =
            await _firebaseService.loadMedicationsFromCloud(cloudUserId);

        int migrados = 0;
        int ignorados = 0;

        for (var localMed in localMeds) {
  MedicationModel? cloudMatch;

  for (var cloudMed in cloudMeds) {
      if (_isSameMedication(localMed, cloudMed)) {
        cloudMatch = cloudMed;
        break;
      }
    }
  
    if (cloudMatch == null) {
      print('   ✅ Migrando: ${localMed.name} (${localMed.formattedTime})');
  
      final newMed = MedicationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: cloudUserId,
        name: localMed.name,
        hour: localMed.hour,
        minute: localMed.minute,
        frequency: localMed.frequency,
        notes: localMed.notes,
        createdAt: localMed.createdAt,
        lastTaken: localMed.lastTaken,
      );
  
      await MedicationService().addMedication(newMed);
      migrados++;
    } else {
      final localLastTaken = localMed.lastTaken;
      final cloudLastTaken = cloudMatch.lastTaken;
  
      final localIsMoreRecent = localLastTaken != null &&
          (cloudLastTaken == null || localLastTaken.isAfter(cloudLastTaken));
  
      if (localIsMoreRecent) {
        print('   🔄 Atualizando tomada na nuvem: ${localMed.name}');
  
        final updatedMed = MedicationModel(
          id: cloudMatch.id,
          userId: cloudUserId,
          name: cloudMatch.name,
          hour: cloudMatch.hour,
          minute: cloudMatch.minute,
          frequency: cloudMatch.frequency,
          notes: cloudMatch.notes,
          createdAt: cloudMatch.createdAt,
          lastTaken: localLastTaken,
        );
  
        await MedicationService().addMedication(updatedMed);
        migrados++;
      } else {
        print('   ⏭️ Já existe na nuvem: ${localMed.name}');
        ignorados++;
      }
    }
  }

        if (migrados > 0) {
          // Sincronizar com a nuvem
          final allMeds =
              await MedicationService().getMedicationsList(cloudUserId);
          await _firebaseService.syncMedicationsToCloud(cloudUserId, allMeds);
          print(
              '✅ Migração concluída! $migrados medicamentos migrados, $ignorados ignorados');
        } else {
          print(
              '📌 Nenhum medicamento novo para migrar ($ignorados ignorados)');
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

    final cloudMeds =
        await _firebaseService.loadMedicationsFromCloud(cloudUserId);

    final localMeds =
        await MedicationService().getMedicationsList(cloudUserId);

    int adicionados = 0;
    int atualizados = 0;
    int ignorados = 0;

    for (var cloudMed in cloudMeds) {
      MedicationModel? localMatch;

      for (var localMed in localMeds) {
        if (_isSameMedication(cloudMed, localMed)) {
          localMatch = localMed;
          break;
        }
      }

      if (localMatch == null) {
        print('   ✅ Adicionando localmente: ${cloudMed.name}');
        await MedicationService().addMedication(cloudMed);
        adicionados++;
      } else {
        final mergedMed =
            _mergeMedicationState(localMatch, cloudMed, cloudUserId);

        final changed =
            mergedMed.lastTaken != localMatch.lastTaken ||
            mergedMed.notes != localMatch.notes;

        if (changed) {
          print('   🔄 Atualizando localmente: ${mergedMed.name}');
          await MedicationService().addMedication(mergedMed);
          atualizados++;
        } else {
          print('   ⏭️ Sem alterações: ${cloudMed.name}');
          ignorados++;
        }
      }
    }

    final allLocalMeds =
        await MedicationService().getMedicationsList(cloudUserId);

    await _firebaseService.syncMedicationsToCloud(cloudUserId, allLocalMeds);

    print(
      '✅ Mesclagem concluída: $adicionados adicionados, $atualizados atualizados, $ignorados ignorados',
    );
  } catch (e) {
    print('❌ Erro ao mesclar dados: $e');
  }
}

  Future<bool> loginToCloud(String email, String password) async {
    try {
      final user =
          await _firebaseService.signInWithEmailAndPassword(email, password);
      if (user != null) {
        final oldLocalUserId = await getLocalUserId();

        print('🔑 Login: oldLocal=$oldLocalUserId, newCloud=${user.uid}');

        await setCloudUserId(user.uid);
        await setSyncEnabled(true);

        await _mergeCloudWithLocal(user.uid);

        if (oldLocalUserId != null && oldLocalUserId != user.uid) {
          await _migrateLocalMedicationsToCloud(user.uid);
        }

        notifyListeners(); // Notificar ouvintes
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro no login cloud: $e');
      rethrow;
    }
  }

  Future<bool> registerInCloud(
      String name, String email, String password) async {
    try {
      final user = await _firebaseService.registerWithEmailAndPassword(
          name, email, password);
      if (user != null) {
        final oldLocalUserId = await getLocalUserId();

        print('📝 Registro: oldLocal=$oldLocalUserId, newCloud=${user.uid}');

        await setCloudUserId(user.uid);
        await setSyncEnabled(true);

        if (oldLocalUserId != null) {
          await _migrateLocalMedicationsToCloud(user.uid);
        }

        notifyListeners(); // Notificar ouvintes
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
    notifyListeners(); // Notificar ouvintes
  }

  Future<void> syncLocalToCloud(String userId) async {
    if (!await hasInternetConnection()) {
      throw 'Sem conexão com a internet';
    }

    try {
      final localMeds = await MedicationService().getMedicationsList(userId);
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
      print('📥 Carregando medicamentos da nuvem para $userId');
      final cloudMeds = await _firebaseService.loadMedicationsFromCloud(userId);

      // Ordenar medicamentos da nuvem
      final sortedCloudMeds = List<MedicationModel>.from(cloudMeds);
      sortedCloudMeds.sort((a, b) {
        if (a.hour != b.hour) return a.hour.compareTo(b.hour);
        if (a.minute != b.minute) return a.minute.compareTo(b.minute);
        return a.name.compareTo(b.name);
      });

      print('📦 Encontrados ${sortedCloudMeds.length} medicamentos na nuvem');

      // Carregar medicamentos locais atuais
      final localMeds = await MedicationService().getMedicationsList(userId);

      int adicionados = 0;

      // Adicionar medicamentos da nuvem que não existem localmente
      for (var cloudMed in sortedCloudMeds) {
        bool existeLocal = false;

        for (var localMed in localMeds) {
          if (_isSameMedication(cloudMed, localMed)) {
            existeLocal = true;
            break;
          }
        }

        if (!existeLocal) {
          print('   ✅ Adicionando localmente: ${cloudMed.name}');
          await MedicationService().addMedication(cloudMed);
          adicionados++;
        }
      }

      print(
          '✅ LoadFromCloud concluído: $adicionados novos medicamentos adicionados');

      // Retornar a lista completa
      return await MedicationService().getMedicationsList(userId);
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
      'lastSync': lastSync != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSync)
          : null,
      'hasInternet': hasInternet,
      'cloudUserId': cloudUserId,
      'localUserId': localUserId,
      'isWeb': kIsWeb,
    };
  }
}

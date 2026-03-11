import '../services/local_storage_service.dart';
import '../models/medication_model.dart';

class MedicationService {
  final LocalStorageService _storage = LocalStorageService();

  MedicationService._privateConstructor();
  static final MedicationService _instance = MedicationService._privateConstructor();
  factory MedicationService() => _instance;

  Future<List<MedicationModel>> getMedicationsList(String userId) async {
    try {
      final medications = await _storage.getMedications(userId: userId);
      final medList = medications.map((data) => MedicationModel.fromMap(data)).toList();
      
      // ORDENAR: Primeiro por hora, depois por minuto, depois por nome
      medList.sort((a, b) {
        // Primeiro compara hora
        if (a.hour != b.hour) {
          return a.hour.compareTo(b.hour);
        }
        // Se hora igual, compara minuto
        if (a.minute != b.minute) {
          return a.minute.compareTo(b.minute);
        }
        // Se tudo igual, compara por nome
        return a.name.compareTo(b.name);
      });
      
      return medList;
    } catch (e) {
      print('❌ Erro ao carregar medicamentos: $e');
      return [];
    }
  }

  Future<void> addMedication(MedicationModel medication) async {
    try {
      print('🔄 Salvando medicamento: ${medication.name}');
      
      final medToSave = MedicationModel(
        id: medication.id.isEmpty 
            ? DateTime.now().millisecondsSinceEpoch.toString() 
            : medication.id,
        userId: medication.userId,
        name: medication.name,
        hour: medication.hour,
        minute: medication.minute,
        frequency: medication.frequency,
        notes: medication.notes,
        createdAt: medication.createdAt,
      );
      
      await _storage.saveMedication(medToSave.toMap());
      
      print('✅ Medicamento salvo! ID: ${medToSave.id}');
    } catch (e) {
      print('❌ Erro ao salvar: $e');
      throw 'Erro ao salvar medicamento: $e';
    }
  }

  Future<void> updateMedication(MedicationModel medication) async {
    try {
      if (medication.id.isEmpty) {
        throw 'Medicamento sem ID para atualização';
      }
      
      print('🔄 Atualizando medicamento: ${medication.name} (ID: ${medication.id})');
      
      final allMeds = await _storage.getMedications(userId: medication.userId);
      
      final index = allMeds.indexWhere((m) => m['id'] == medication.id);
      
      if (index >= 0) {
        allMeds[index] = medication.toMap();
        
        await _storage.saveAllMedications(allMeds);
        print('✅ Medicamento atualizado! ID: ${medication.id}');
      } else {
        print('⚠️ Medicamento não encontrado, adicionando como novo');
        await _storage.saveMedication(medication.toMap());
      }
    } catch (e) {
      print('❌ Erro ao atualizar: $e');
      throw 'Erro ao atualizar medicamento: $e';
    }
  }

  Future<void> deleteMedication(String medicationId) async {
    try {
      await _storage.deleteMedication(medicationId);
      print('✅ Medicamento excluído! ID: $medicationId');
    } catch (e) {
      print('❌ Erro ao excluir: $e');
      throw 'Erro ao excluir medicamento: $e';
    }
  }
}
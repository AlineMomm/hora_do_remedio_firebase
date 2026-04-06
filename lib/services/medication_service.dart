import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/local_storage_service.dart';
import '../models/medication_model.dart';
import 'notification_service.dart';
import 'sync_service.dart';

class MedicationService {
  final LocalStorageService _storage = LocalStorageService();

  static final MedicationService _instance = MedicationService._internal();
  factory MedicationService() => _instance;
  MedicationService._internal();

  Future<List<MedicationModel>> getMedicationsList(String userId) async {
    try {
      final medications = await _storage.getMedications(userId: userId);
      final medList =
          medications.map((data) => MedicationModel.fromMap(data)).toList();

      medList.sort((a, b) {
        if (a.hour != b.hour) return a.hour.compareTo(b.hour);
        if (a.minute != b.minute) return a.minute.compareTo(b.minute);
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

      // Agendar notificação (apenas em mobile)
      await _scheduleNotificationForMedication(medToSave);

      // Sincronizar com nuvem se estiver logado
      try {
        final syncService = SyncService();
        if (await syncService.isLoggedIn) {
          await syncService.syncMedications();
        }
      } catch (e) {
        print('⚠️ Erro ao sincronizar (não crítico): $e');
      }

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

      print(
          '🔄 Atualizando medicamento: ${medication.name} (ID: ${medication.id})');

      final allMeds = await _storage.getMedications(userId: medication.userId);
      final index = allMeds.indexWhere((m) => m['id'] == medication.id);

      if (index >= 0) {
        allMeds[index] = medication.toMap();
        await _storage.saveAllMedications(allMeds);

        if (!kIsWeb) {
          await NotificationService()
              .cancelNotification(medication.id.hashCode);
          await _scheduleNotificationForMedication(medication);
        }

        try {
          final syncService = SyncService();
          if (await syncService.isLoggedIn) {
            await syncService.syncMedications();
          }
        } catch (e) {
          print('⚠️ Erro ao sincronizar (não crítico): $e');
        }

        print('✅ Medicamento atualizado! ID: ${medication.id}');
      } else {
        print('⚠️ Medicamento não encontrado, adicionando como novo');
        await addMedication(medication);
      }
    } catch (e) {
      print('❌ Erro ao atualizar: $e');
      throw 'Erro ao atualizar medicamento: $e';
    }
  }

  Future<void> deleteMedication(String medicationId) async {
    try {
      if (!kIsWeb) {
        await NotificationService().cancelNotification(medicationId.hashCode);
      }

      await _storage.deleteMedication(medicationId);

      try {
        final syncService = SyncService();
        if (await syncService.isLoggedIn) {
          await syncService.syncMedications();
        }
      } catch (e) {
        print('⚠️ Erro ao sincronizar (não crítico): $e');
      }

      print('✅ Medicamento excluído! ID: $medicationId');
    } catch (e) {
      print('❌ Erro ao excluir: $e');
      throw 'Erro ao excluir medicamento: $e';
    }
  }

  Future<void> _scheduleNotificationForMedication(MedicationModel med) async {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      med.hour,
      med.minute,
    );

    final notificationTime = scheduledTime.isBefore(now)
        ? scheduledTime.add(const Duration(days: 1))
        : scheduledTime;

    await NotificationService().scheduleMedicationReminder(
      id: med.id.hashCode,
      medicationName: med.name,
      scheduledTime: notificationTime,
      observation: med.notes,
    );
  }

  Future<void> restoreAllNotifications(String userId) async {
    if (kIsWeb) return; // Não fazer nada na web

    final medications = await getMedicationsList(userId);
    for (var med in medications) {
      await _scheduleNotificationForMedication(med);
    }
  }
Future<void> markAsTaken(String medicationId, String userId) async {
  try {
    print('💊 Marcando medicamento $medicationId como tomado');
    
    final allMeds = await _storage.getMedications(userId: userId);
    final index = allMeds.indexWhere((m) => m['id'] == medicationId);
    
    if (index >= 0) {
      final now = DateTime.now();
      
      // Verificar se já foi tomado hoje (proteção extra)
      final lastTaken = allMeds[index]['lastTaken'];
      if (lastTaken != null) {
        final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTaken);
        if (lastDate.year == now.year &&
            lastDate.month == now.month &&
            lastDate.day == now.day) {
          throw 'Este medicamento já foi registrado como tomado hoje';
        }
      }
      
      // Atualizar o lastTaken
      allMeds[index]['lastTaken'] = now.millisecondsSinceEpoch;
      await _storage.saveAllMedications(allMeds);
      
      print('✅ Medicamento $medicationId marcado como tomado');
      
      // Cancelar notificação atual e reagendar conforme a frequência
      if (!kIsWeb) {
        await NotificationService().cancelNotification(medicationId.hashCode);
      
        final med = MedicationModel.fromMap(allMeds[index]);
        final nextTime = med.nextDoseTime;
      
        await NotificationService().scheduleMedicationReminder(
          id: med.id.hashCode,
          medicationName: med.name,
          scheduledTime: nextTime,
          observation: med.notes,
        );
      }
      
      // Sincronizar com nuvem
      try {
        final syncService = SyncService();
        if (await syncService.isLoggedIn) {
          await syncService.syncMedications();
        }
      } catch (e) {
        print('⚠️ Erro ao sincronizar: $e');
      }
    } else {
      throw 'Medicamento não encontrado';
    }
    
  } catch (e) {
    print('❌ Erro ao marcar como tomado: $e');
    throw e.toString();
  }
}

Future<void> undoTakeMedication(String medicationId, String userId) async {
  try {
    print('🔄 Desfazendo medicamento $medicationId');
    
    final allMeds = await _storage.getMedications(userId: userId);
    final index = allMeds.indexWhere((m) => m['id'] == medicationId);
    
    if (index >= 0) {
      // Remover o lastTaken
      allMeds[index].remove('lastTaken');
      await _storage.saveAllMedications(allMeds);
      
      print('✅ Desfeito medicamento $medicationId');
      
      // Reagendar notificação para hoje (se ainda não passou)
      if (!kIsWeb) {
        final med = MedicationModel.fromMap(allMeds[index]);
        final now = DateTime.now();
      
        await NotificationService().cancelNotification(medicationId.hashCode);
      
        DateTime notificationTime;
      
        if (med.frequency == 'Quando necessário') {
          notificationTime = now;
        } else if (med.isIntervalFrequency) {
          final base = DateTime(now.year, now.month, now.day, med.hour, med.minute);
      
          if (base.isAfter(now)) {
            notificationTime = base;
          } else {
            DateTime next = base;
            while (!next.isAfter(now)) {
              next = next.add(med.frequencyDuration);
            }
            notificationTime = next;
          }
        } else {
          final todayDose = DateTime(
            now.year,
            now.month,
            now.day,
            med.hour,
            med.minute,
          );
      
          notificationTime = todayDose.isBefore(now)
              ? todayDose.add(med.frequencyDuration)
              : todayDose;
        }
      
        await NotificationService().scheduleMedicationReminder(
          id: med.id.hashCode,
          medicationName: med.name,
          scheduledTime: notificationTime,
          observation: med.notes,
        );
      }
      
      // Sincronizar com nuvem
      try {
        final syncService = SyncService();
        if (await syncService.isLoggedIn) {
          await syncService.syncMedications();
        }
      } catch (e) {
        print('⚠️ Erro ao sincronizar: $e');
      }
    } else {
      throw 'Medicamento não encontrado';
    }
    
  } catch (e) {
    print('❌ Erro ao desfazer: $e');
    throw e.toString();
  }
}
}

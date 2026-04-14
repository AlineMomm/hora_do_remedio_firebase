import 'package:flutter/material.dart';

class MedicationModel {
  final String id;
  final String userId;
  final String name;
  final int hour;
  final int minute;
  final String frequency;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastTaken;

  MedicationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.hour,
    required this.minute,
    required this.frequency,
    this.notes,
    required this.createdAt,
    this.lastTaken,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'hour': hour,
      'minute': minute,
      'frequency': frequency,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastTaken': lastTaken?.millisecondsSinceEpoch,
    };
  }

  factory MedicationModel.fromMap(Map<String, dynamic> map) {
    return MedicationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      hour: map['hour'] ?? 0,
      minute: map['minute'] ?? 0,
      frequency: map['frequency'] ?? 'Diário',
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      lastTaken: map['lastTaken'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastTaken'] as int)
          : null,
    );
  }

  Duration get frequencyDuration {
    switch (frequency) {
      case 'A cada 12 horas':
        return const Duration(hours: 12);
      case 'A cada 8 horas':
        return const Duration(hours: 8);
      case 'A cada 6 horas':
        return const Duration(hours: 6);
      case 'Semanal':
        return const Duration(days: 7);
      case 'Diário':
      default:
        return const Duration(days: 1);
    }
  }

  bool get isIntervalFrequency {
    return frequency == 'A cada 12 horas' ||
        frequency == 'A cada 8 horas' ||
        frequency == 'A cada 6 horas';
  }

  DateTime get scheduledBaseTime {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  bool get canTakeNow {
    final now = DateTime.now();

    if (isIntervalFrequency) {
      if (lastTaken == null) {
        final base = scheduledBaseTime;
        return now.isAfter(base) || base.difference(now).inMinutes <= 30;
      }

      return !now.isBefore(lastTaken!.add(frequencyDuration));
    }

    final todayDoseTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (lastTaken == null) {
      return now.isAfter(todayDoseTime) ||
          todayDoseTime.difference(now).inMinutes <= 30;
    }

    if (lastTaken!.isBefore(todayDoseTime)) {
      return now.isAfter(todayDoseTime) ||
          now.isAtSameMomentAs(todayDoseTime);
    }

    final nextDose = todayDoseTime.add(frequencyDuration);
    return now.isAfter(nextDose) || now.isAtSameMomentAs(nextDose);
  }

  DateTime get nextDoseTime {
    final now = DateTime.now();

    if (isIntervalFrequency) {
      if (lastTaken != null) {
        return lastTaken!.add(frequencyDuration);
      }

      final base = scheduledBaseTime;
      if (base.isAfter(now)) {
        return base;
      }

      DateTime next = base;
      while (!next.isAfter(now)) {
        next = next.add(frequencyDuration);
      }
      return next;
    }

    final todayDose = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (lastTaken == null) {
      return todayDose.isAfter(now)
          ? todayDose
          : todayDose.add(frequencyDuration);
    }

    if (lastTaken!.isBefore(todayDose)) {
      return todayDose;
    }

    return todayDose.add(frequencyDuration);
  }

  DateTime get currentDoseScheduledTime {
  final now = DateTime.now();

  if (isIntervalFrequency) {
    final base = DateTime(now.year, now.month, now.day, hour, minute);

    if (lastTaken != null) {
      return lastTaken!.add(frequencyDuration);
    }

    if (base.isAfter(now)) {
      return base;
    }

    DateTime current = base;
    while (current.add(frequencyDuration).isBefore(now) ||
        current.add(frequencyDuration).isAtSameMomentAs(now)) {
      current = current.add(frequencyDuration);
    }
    return current;
  }

  return DateTime(
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
}

bool get isOverdue {
  final now = DateTime.now();
  final scheduled = currentDoseScheduledTime;

  if (lastTaken != null) {
    if (isIntervalFrequency) {
      return now.isAfter(scheduled);
    }

    if (!lastTaken!.isBefore(scheduled)) {
      return false;
    }
  }

  return now.isAfter(scheduled);
}

String get overdueText {
  final diff = DateTime.now().difference(currentDoseScheduledTime);

  final totalMinutes = diff.inMinutes < 0 ? 0 : diff.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours > 0) {
    return 'Atrasado há ${hours} h ${minutes} min';
  }

  return 'Atrasado há ${minutes} min';
}

  String get status {
  if (isOverdue) {
    return overdueText;
  }

  final now = DateTime.now();
  final scheduled = currentDoseScheduledTime;

  if (canTakeNow && !now.isAfter(scheduled)) {
    return 'Pode tomar';
  }

  final diff = nextDoseTime.difference(now);
  final totalMinutes = diff.inMinutes < 0 ? 0 : diff.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (wasTakenToday || (isIntervalFrequency && lastTaken != null)) {
    return 'Próxima dose em $hours h $minutes min';
  }

  return 'Próximo horário em $hours h $minutes min';
}

  bool get wasTakenToday {
    if (lastTaken == null) return false;
    final now = DateTime.now();
    return lastTaken!.year == now.year &&
        lastTaken!.month == now.month &&
        lastTaken!.day == now.day;
  }

  bool isSameAs(MedicationModel other) {
    return name == other.name &&
        hour == other.hour &&
        minute == other.minute;
  }

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  String get formattedTime {
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}
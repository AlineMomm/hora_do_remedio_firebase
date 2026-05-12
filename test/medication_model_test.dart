// Testes unitários da lógica interna do MedicationModel.
//
// Estes testes verificam se o modelo de medicamento mantém corretamente
// as informações importantes, principalmente o campo lastTaken,
// que indica quando o medicamento foi marcado como tomado.

import 'package:flutter_test/flutter_test.dart';
import 'package:hora_do_remedio/models/medication_model.dart';

void main() {
  group('MedicationModel - conversão de dados', () {
    test('deve converter medicamento para Map mantendo lastTaken', () {
      // Cria uma data com o momento atual.
      // Essa data será usada para simular a criação do medicamento
      // e o horário em que ele foi marcado como tomado.
      final now = DateTime.now();

      // Cria um medicamento fictício para teste.
      final med = MedicationModel(
        id: '1',
        userId: 'user1',
        name: 'Dipirona',
        hour: 8,
        minute: 30,
        frequency: 'Diário',
        notes: 'Após o café',
        createdAt: now,
        lastTaken: now,
      );

      // Converte o objeto para Map.
      //
      // Isso simula o que acontece quando o app prepara o medicamento
      // para salvar localmente ou no Firebase.
      final map = med.toMap();

      // Verifica se os dados principais foram salvos corretamente no Map.
      expect(map['name'], 'Dipirona');
      expect(map['hour'], 8);
      expect(map['minute'], 30);
      expect(map['frequency'], 'Diário');

      // Verifica se o campo lastTaken foi salvo.
      //
      // Esse campo é importante porque controla se o medicamento aparece
      // como TOMADO, PENDENTE ou ATRASADO.
      expect(map['lastTaken'], now.millisecondsSinceEpoch);
    });

    test('deve recriar medicamento a partir do Map com lastTaken', () {
      // Cria uma data atual para simular dados vindos do banco.
      final now = DateTime.now();

      // Este Map simula um medicamento carregado do armazenamento
      // local ou do Firebase.
      final map = {
        'id': '1',
        'userId': 'user1',
        'name': 'Dipirona',
        'hour': 8,
        'minute': 30,
        'frequency': 'Diário',
        'notes': 'Após o café',
        'createdAt': now.millisecondsSinceEpoch,
        'lastTaken': now.millisecondsSinceEpoch,
      };

      // Converte o Map novamente para MedicationModel.
      //
      // Isso simula o app carregando dados salvos e reconstruindo
      // o objeto para exibir na tela.
      final med = MedicationModel.fromMap(map);

      expect(med.name, 'Dipirona');
      expect(med.hour, 8);
      expect(med.minute, 30);
      expect(med.frequency, 'Diário');

      // Confirma que o medicamento continua com informação de tomado.
      expect(med.lastTaken, isNotNull);
    });
  });

  group('MedicationModel - frequências', () {
    test('deve retornar duração correta para frequência diária', () {
      final med = MedicationModel(
        id: '1',
        userId: 'user1',
        name: 'Remédio diário',
        hour: 8,
        minute: 0,
        frequency: 'Diário',
        createdAt: DateTime.now(),
      );

      // Frequência diária deve equivaler a 1 dia.
      expect(med.frequencyDuration, const Duration(days: 1));
    });

    test('deve retornar duração correta para frequência a cada 8 horas', () {
      final med = MedicationModel(
        id: '1',
        userId: 'user1',
        name: 'Remédio 8h',
        hour: 8,
        minute: 0,
        frequency: 'A cada 8 horas',
        createdAt: DateTime.now(),
      );

      // Frequência "A cada 8 horas" deve equivaler a 8 horas.
      expect(med.frequencyDuration, const Duration(hours: 8));
    });

    test('deve identificar frequência por intervalo', () {
      final med = MedicationModel(
        id: '1',
        userId: 'user1',
        name: 'Antibiótico',
        hour: 8,
        minute: 0,
        frequency: 'A cada 12 horas',
        createdAt: DateTime.now(),
      );

      // Frequências de 6h, 8h e 12h devem ser reconhecidas
      // como frequências por intervalo.
      expect(med.isIntervalFrequency, true);
    });
  });

  group('MedicationModel - formatação', () {
    test('deve formatar horário em formato AM/PM', () {
      final med = MedicationModel(
        id: '1',
        userId: 'user1',
        name: 'Dipirona',
        hour: 8,
        minute: 5,
        frequency: 'Diário',
        createdAt: DateTime.now(),
      );

      // Verifica se o horário é exibido com dois dígitos.
      expect(med.formattedTime, '08:05 AM');
    });
  });
}
// Teste de interface da tela de configuração de alarmes.
//
// Este teste verifica se a tela abre corretamente
// e mostra os textos principais.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hora_do_remedio/pages/alarm_permissions_page.dart';

void main() {
  testWidgets('deve abrir tela de configuração de alarmes',
      (WidgetTester tester) async {
    // Monta a tela dentro de um MaterialApp.
    await tester.pumpWidget(
      const MaterialApp(
        home: AlarmPermissionsPage(),
      ),
    );

    // Aguarda a construção inicial.
    await tester.pump();

    // Aguarda a tela sair do carregamento.
    await tester.pump(const Duration(seconds: 1));

    // Verifica se o título apareceu.
    expect(find.text('Configurar Alarmes'), findsOneWidget);

    // Verifica se o card principal apareceu.
    expect(find.text('Configurar o App'), findsOneWidget);

    // Verifica se o botão principal apareceu.
    expect(find.text('ABRIR CONFIGURAÇÕES'), findsOneWidget);
  });
}
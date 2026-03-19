import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Ajuda e Como Usar',
          style: settings.getTextStyle(
            size: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(settings),
            const SizedBox(height: 30),
            _buildIconsSection(settings),
            const SizedBox(height: 30),
            _buildFunctionsSection(settings),
            const SizedBox(height: 30),
            _buildTipsSection(settings),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(SettingsService settings) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medical_services,
                size: 50,
                color: const Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Bem-vindo ao Hora do Remédio!',
              style: settings.getTextStyle(
                size: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D47A1),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Este aplicativo foi feito especialmente para ajudar você a lembrar de tomar seus remédios nos horários certos. É muito simples de usar!',
              style: settings.getTextStyle(
                size: 16,
                height: 1.5,
                color: const Color(0xFF424242),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconsSection(SettingsService settings) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CORRIGIDO: Row com Expanded para evitar overflow
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.touch_app,
                  color: Color(0xFF0D47A1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded( // <-- IMPORTANTE: Expanded aqui!
                child: Text(
                  'O que significa cada ícone:',
                  style: settings.getTextStyle(
                    size: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D47A1),
                  ),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis, // Segurança extra
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildIconItem(settings, Icons.add, 'Botão Adicionar',
              'Toque aqui para cadastrar um novo remédio. Aparece como um botão na parte inferior da tela com o texto "ADICIONAR MEDICAMENTO".'),
          _buildIconItem(settings, Icons.edit, 'Lápis (Editar)',
              'Toque neste ícone para modificar as informações de um remédio que já cadastrou.'),
          _buildIconItem(settings, Icons.delete, 'Lixeira (Excluir)',
              'Toque aqui para remover um remédio da sua lista. O app vai perguntar se você tem certeza antes de excluir.'),
          _buildIconItem(settings, Icons.person, 'Silhueta (Perfil)',
              'Toque aqui para ver e editar suas informações pessoais, como telefone, tipo sanguíneo e contato de emergência.'),
          _buildIconItem(settings, Icons.help_outline, 'Ponto de Interrogação (Ajuda)',
              'Toque aqui sempre que tiver dúvidas sobre como usar o aplicativo. Esta tela vai aparecer!'),
          _buildIconItem(settings, Icons.cloud_upload, 'Nuvem (Sincronizar)',
              'Toque aqui para fazer login na nuvem e salvar seus medicamentos online.'),
          _buildIconItem(settings, Icons.exit_to_app, 'Porta de Saída (Sair)',
              'Toque aqui para sair da sua conta e voltar para a tela inicial.'),
          _buildIconItem(settings, Icons.access_time, 'Relógio (Horário)',
              'Mostra o horário em que você deve tomar cada remédio.'),
          _buildIconItem(settings, Icons.repeat, 'Seta Circular (Frequência)',
              'Mostra de quanto em quanto tempo você deve tomar o remédio (todo dia, toda semana, etc.).'),
          _buildIconItem(settings, Icons.medical_services, 'Cruz Médica (Remédio)',
              'Representa cada medicamento que você cadastrou.'),
        ],
      ),
    ),
  );
}

  Widget _buildIconItem(SettingsService settings, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white, // Fundo branco
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1565C0),
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: settings.getTextStyle(
                    size: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: settings.getTextStyle(
                    size: 14,
                    height: 1.4,
                    color: const Color(0xFF424242),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionsSection(SettingsService settings) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CORRIGIDO: Row com Expanded para evitar overflow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.menu_book,
                    color: const Color(0xFF0D47A1),
                    size: settings.iconSize,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded( // <-- IMPORTANTE: Expanded aqui!
                  child: Text(
                    'Como usar as principais funções:',
                    style: settings.getTextStyle(
                      size: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D47A1),
                    ),
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFunctionItem(settings,
              'Cadastrar um Remédio',
              '1. Toque no botão "ADICIONAR MEDICAMENTO" na parte de baixo da tela\n2. Digite o nome do remédio\n3. Escolha o horário tocando no relógio\n4. Selecione a frequência\n5. Toque em "CADASTRAR"',
            ),
            _buildFunctionItem(settings,
              'Ver seus Remédios',
              'Na tela principal você vê todos os remédios que cadastrou, organizados por horário. Cada card mostra:\n• Nome do remédio\n• Horário para tomar\n• Frequência\n• Observações (se tiver)',
            ),
            _buildFunctionItem(settings,
              'Receber Lembretes',
              'O app avisa você quando chegar a hora de tomar cada remédio. Um alerta vai aparecer na tela do celular com o nome do remédio.',
            ),
            _buildFunctionItem(settings,
              'Editar suas Informações',
              '1. Toque no ícone de perfil (silhueta)\n2. Toque no lápis para editar\n3. Preencha suas informações\n4. Toque no ícone de salvar (disquete)',
            ),
            _buildFunctionItem(settings,
              'Salvar na Nuvem',
              '1. Toque no ícone de nuvem na parte superior\n2. Escolha "Fazer Login/Cadastro"\n3. Crie uma conta ou faça login\n4. Seus medicamentos serão salvos online e sincronizados entre dispositivos',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionItem(SettingsService settings, String title, String steps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: settings.getTextStyle(
              size: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, // Fundo branco
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: Text(
              steps,
              style: settings.getTextStyle(
                size: 14,
                height: 1.5,
                color: const Color(0xFF424242),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection(SettingsService settings) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb,
                    color: Color(0xFF0D47A1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Dicas Importantes:',
                  style: settings.getTextStyle(
                    size: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTipItem(settings, 'Sempre mantenha suas informações atualizadas no perfil'),
            _buildTipItem(settings, 'Cadastre todos os remédios que toma regularmente'),
            _buildTipItem(settings, 'Verifique se o horário do celular está correto'),
            _buildTipItem(settings, 'Mantenha o volume do celular ligado para ouvir os alertas'),
            _buildTipItem(settings, 'Se tiver dúvidas, volte sempre nesta tela de ajuda'),
            _buildTipItem(settings, 'Peça ajuda a um familiar se precisar'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, // Fundo branco
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0D47A1).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Lembre-se: este aplicativo é seu amigo para cuidar da sua saúde!',
                style: settings.getTextStyle(
                  size: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0D47A1),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(SettingsService settings, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: const Color(0xFF2E7D32),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: settings.getTextStyle(
                size: 14,
                height: 1.4,
                color: const Color(0xFF424242),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../services/medication_service.dart';
import '../models/medication_model.dart';

class AddMedicationPage extends StatefulWidget {
  final MedicationModel? medication;
  final String localUserId;
  
  const AddMedicationPage({
    super.key, 
    this.medication,
    required this.localUserId,
  });

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _medicationService = MedicationService();
  
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedFrequency = 'Diário';
  
  final List<String> _frequencies = [
    'Diário',
    'A cada 12 horas',
    'A cada 8 horas',
    'A cada 6 horas',
    'Semanal',
    'Quando necessário'
  ];

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.medication != null;
    
    if (_isEditing) {
      _nameController.text = widget.medication!.name;
      _notesController.text = widget.medication?.notes ?? '';
      _selectedTime = widget.medication!.timeOfDay;
      _selectedFrequency = widget.medication!.frequency;
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveMedication() async {
  if (_formKey.currentState!.validate()) {
    setState(() {
      _isLoading = true;
    });

    try {
      final medication = MedicationModel(
        id: _isEditing ? widget.medication!.id : '',
        userId: widget.localUserId,
        name: _nameController.text.trim(),
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        frequency: _selectedFrequency,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: _isEditing ? widget.medication!.createdAt : DateTime.now(),
      );

      if (_isEditing) {
        await _medicationService.updateMedication(medication);
        print('✅ Medicamento atualizado via updateMedication');
      } else {
        await _medicationService.addMedication(medication);
        print('✅ Medicamento adicionado via addMedication');
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing 
              ? 'Medicamento atualizado com sucesso!' 
              : 'Medicamento salvo com sucesso!'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: const Color(0xFFD32F2F),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Medicamento' : 'Novo Medicamento'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do medicamento*',
                    prefixIcon: Icon(Icons.medical_services, color: Color(0xFF757575)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, digite o nome do medicamento';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                InkWell(
                  onTap: _selectTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Horário*',
                      prefixIcon: Icon(Icons.access_time, color: Color(0xFF757575)),
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedTime.format(context),
                          style: const TextStyle(fontSize: 16, color: Color(0xFF212121)),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF757575)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                DropdownButtonFormField<String>(
                  value: _selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequência*',
                    prefixIcon: Icon(Icons.repeat, color: Color(0xFF757575)),
                  ),
                  items: _frequencies.map((String frequency) {
                    return DropdownMenuItem<String>(
                      value: frequency,
                      child: Text(
                        frequency,
                        style: const TextStyle(color: Color(0xFF212121)),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedFrequency = newValue;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, selecione a frequência';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    prefixIcon: Icon(Icons.note, color: Color(0xFF757575)),
                  ),
                  maxLines: 3,
                ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEditing ? const Color(0xFFF57C00) : const Color(0xFF388E3C),
                    ),
                    onPressed: _isLoading ? null : _saveMedication,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(_isEditing ? 'ATUALIZAR' : 'CADASTRAR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
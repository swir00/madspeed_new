import 'package:flutter/material.dart';
import 'package:madspeed_app/models/dog_profile.dart';
import 'package:madspeed_app/models/training_session.dart';

class EditTrainingSessionDialog extends StatefulWidget {
  final TrainingSession session;
  final List<DogProfile> allDogs;

  const EditTrainingSessionDialog({
    super.key,
    required this.session,
    required this.allDogs,
  });

  @override
  State<EditTrainingSessionDialog> createState() => _EditTrainingSessionDialogState();
}

class _EditTrainingSessionDialogState extends State<EditTrainingSessionDialog> {
  late TextEditingController _nameController;
  late DogProfile? _selectedDog;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name);
    if (widget.session.dogId != null) {
      try {
        _selectedDog = widget.allDogs.firstWhere((dog) => dog.id == widget.session.dogId);
      } catch (e) {
        _selectedDog = null;
      }
    } else {
      _selectedDog = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edytuj trening'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nazwa treningu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DogProfile>(
              value: _selectedDog,
              decoration: const InputDecoration(
                labelText: 'Wybierz psa',
                border: OutlineInputBorder(),
              ),
              items: widget.allDogs.map((DogProfile dog) {
                return DropdownMenuItem<DogProfile>(
                  value: dog,
                  child: Text(dog.name),
                );
              }).toList(),
              onChanged: (DogProfile? newValue) {
                setState(() {
                  _selectedDog = newValue;
                });
              },
              validator: (value) => value == null ? 'Musisz wybrać psa' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isEmpty || _selectedDog == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wszystkie pola muszą być wypełnione.')));
              return;
            }
            final updatedSession = widget.session.copyWith(
              name: _nameController.text,
              dogId: _selectedDog!.id,
            );
            Navigator.of(context).pop(updatedSession);
          },
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}
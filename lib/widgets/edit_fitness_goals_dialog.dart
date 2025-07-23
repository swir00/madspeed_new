// lib/widgets/edit_fitness_goals_dialog.dart

import 'package:flutter/material.dart';
import 'package:madspeed_app/models/dog_profile.dart';

class EditFitnessGoalsDialog extends StatefulWidget {
  final DogProfile dogProfile;

  const EditFitnessGoalsDialog({super.key, required this.dogProfile});

  @override
  State<EditFitnessGoalsDialog> createState() => _EditFitnessGoalsDialogState();
}

class _EditFitnessGoalsDialogState extends State<EditFitnessGoalsDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _targetWeightController;
  late TextEditingController _dailyDistanceGoalController;
  late TextEditingController _dailyDurationGoalController;

  @override
  void initState() {
    super.initState();
    _targetWeightController = TextEditingController(text: widget.dogProfile.targetWeight?.toString() ?? '');
    _dailyDistanceGoalController = TextEditingController(text: widget.dogProfile.dailyDistanceGoal?.toString() ?? '');
    _dailyDurationGoalController = TextEditingController(text: widget.dogProfile.dailyDurationGoal?.toString() ?? '');
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    _dailyDistanceGoalController.dispose();
    _dailyDurationGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edytuj Cele Fitness'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _targetWeightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Waga docelowa (kg)',
                  hintText: 'np. 25.0',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.track_changes),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                    return 'Proszę podać prawidłową wagę';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dailyDistanceGoalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dzienny cel dystansu (metry)',
                  hintText: 'np. 5000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_walk),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                    return 'Proszę podać prawidłowy dystans';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dailyDurationGoalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dzienny cel czasu aktywności (minuty)',
                  hintText: 'np. 60',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return 'Proszę podać prawidłowy czas w minutach';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Zamyka dialog bez zapisywania
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                DogProfile(
                  id: widget.dogProfile.id,
                  name: widget.dogProfile.name, // Zachowaj istniejące pola
                  breed: widget.dogProfile.breed,
                  dateOfBirth: widget.dogProfile.dateOfBirth,
                  gender: widget.dogProfile.gender,
                  currentWeight: widget.dogProfile.currentWeight,
                  activityLevel: widget.dogProfile.activityLevel,
                  photoPath: widget.dogProfile.photoPath,
                  targetWeight: double.tryParse(_targetWeightController.text),
                  dailyDistanceGoal: double.tryParse(_dailyDistanceGoalController.text),
                  dailyDurationGoal: int.tryParse(_dailyDurationGoalController.text),
                ),
              );
            }
          },
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}

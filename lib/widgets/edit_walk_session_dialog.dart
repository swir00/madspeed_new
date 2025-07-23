import 'package:flutter/material.dart';
import 'package:madspeed_app/models/dog_profile.dart';
import 'package:madspeed_app/models/walk_session_model.dart';

class EditWalkSessionDialog extends StatefulWidget {
  final WalkSession session;
  final List<DogProfile> allDogs;

  const EditWalkSessionDialog({
    super.key,
    required this.session,
    required this.allDogs,
  });

  @override
  State<EditWalkSessionDialog> createState() => _EditWalkSessionDialogState();
}

class _EditWalkSessionDialogState extends State<EditWalkSessionDialog> {
  late TextEditingController _nameController;
  late List<DogProfile> _selectedDogs;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name);
    _selectedDogs = widget.allDogs
        .where((dog) => widget.session.dogIds.contains(dog.id))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showDogSelection() {
    showDialog(
      context: context,
      builder: (context) {
        List<DogProfile> tempSelected = List.from(_selectedDogs);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Wybierz psy'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.allDogs.length,
                  itemBuilder: (context, index) {
                    final dog = widget.allDogs[index];
                    final isSelected = tempSelected.any((d) => d.id == dog.id);
                    return CheckboxListTile(
                      title: Text(dog.name),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(dog);
                          } else {
                            tempSelected.removeWhere((d) => d.id == dog.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedDogs = tempSelected;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Zatwierdź'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edytuj spacer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nazwa spaceru',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Psy uczestniczące:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _selectedDogs.map((dog) => Chip(label: Text(dog.name))).toList(),
            ),
            const SizedBox(height: 8),
            Center(child: ElevatedButton.icon(icon: const Icon(Icons.pets), label: const Text('Zmień psy'), onPressed: _showDogSelection)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nazwa nie może być pusta.')));
              return;
            }
            final updatedSession = widget.session.copyWith(name: _nameController.text, dogIds: _selectedDogs.map((d) => d.id).toList());
            Navigator.of(context).pop(updatedSession);
          },
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}
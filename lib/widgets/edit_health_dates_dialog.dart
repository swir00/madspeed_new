// lib/widgets/edit_health_dates_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:madspeed_app/models/dog_profile.dart';

class EditHealthDatesDialog extends StatefulWidget {
  final DogProfile dogProfile;

  const EditHealthDatesDialog({super.key, required this.dogProfile});

  @override
  State<EditHealthDatesDialog> createState() => _EditHealthDatesDialogState();
}

class _EditHealthDatesDialogState extends State<EditHealthDatesDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedLastVaccinationDate;
  DateTime? _selectedRabiesVaccinationDate;
  DateTime? _selectedLastDewormingDate;

  @override
  void initState() {
    super.initState();
    if (widget.dogProfile.lastVaccinationDate != null) {
      _selectedLastVaccinationDate = DateTime.parse(widget.dogProfile.lastVaccinationDate!);
    }
    if (widget.dogProfile.rabiesVaccinationDate != null) {
      _selectedRabiesVaccinationDate = DateTime.parse(widget.dogProfile.rabiesVaccinationDate!);
    }
    if (widget.dogProfile.lastDewormingDate != null) {
      _selectedLastDewormingDate = DateTime.parse(widget.dogProfile.lastDewormingDate!);
    }
  }

  // Zmodyfikowana funkcja - teraz zwraca wybraną datę
  Future<DateTime?> _selectDate(BuildContext context, DateTime? initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    return picked; // Zwróć wybraną datę
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edytuj Daty Zdrowotne'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  _selectedLastVaccinationDate == null
                      ? 'Data ostatniego szczepienia (ogólne)'
                      : 'Ostatnie szczepienie (ogólne): ${DateFormat('yyyy-MM-dd').format(_selectedLastVaccinationDate!)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async { // Zmieniono na async
                        final pickedDate = await _selectDate(context, _selectedLastVaccinationDate);
                        if (pickedDate != null) {
                          setState(() {
                            _selectedLastVaccinationDate = pickedDate;
                          });
                        }
                      },
                      tooltip: 'Wybierz datę',
                    ),
                    if (_selectedLastVaccinationDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _selectedLastVaccinationDate = null;
                          });
                        },
                        tooltip: 'Wyczyść datę',
                      ),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _selectedRabiesVaccinationDate == null
                      ? 'Data szczepienia na wściekliznę'
                      : 'Szczepienie na wściekliznę: ${DateFormat('yyyy-MM-dd').format(_selectedRabiesVaccinationDate!)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async { // Zmieniono na async
                        final pickedDate = await _selectDate(context, _selectedRabiesVaccinationDate);
                        if (pickedDate != null) {
                          setState(() {
                            _selectedRabiesVaccinationDate = pickedDate;
                          });
                        }
                      },
                      tooltip: 'Wybierz datę',
                    ),
                    if (_selectedRabiesVaccinationDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _selectedRabiesVaccinationDate = null;
                          });
                        },
                        tooltip: 'Wyczyść datę',
                      ),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _selectedLastDewormingDate == null
                      ? 'Data ostatniego odrobaczenia'
                      : 'Ostatnie odrobaczenie: ${DateFormat('yyyy-MM-dd').format(_selectedLastDewormingDate!)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async { // Zmieniono na async
                        final pickedDate = await _selectDate(context, _selectedLastDewormingDate);
                        if (pickedDate != null) {
                          setState(() {
                            _selectedLastDewormingDate = pickedDate;
                          });
                        }
                      },
                      tooltip: 'Wybierz datę',
                    ),
                    if (_selectedLastDewormingDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _selectedLastDewormingDate = null;
                          });
                        },
                        tooltip: 'Wyczyść datę',
                      ),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                widget.dogProfile.copyWith(
                  lastVaccinationDate: _selectedLastVaccinationDate?.toIso8601String().split('T')[0],
                  rabiesVaccinationDate: _selectedRabiesVaccinationDate?.toIso8601String().split('T')[0],
                  lastDewormingDate: _selectedLastDewormingDate?.toIso8601String().split('T')[0],
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

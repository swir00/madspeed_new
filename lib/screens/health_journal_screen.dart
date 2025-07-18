// lib/screens/health_journal_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:madspeed_app/database/database_helper.dart';
import 'package:madspeed_app/models/dog_profile.dart';
import 'package:madspeed_app/models/health_entry.dart';

class HealthJournalScreen extends StatefulWidget {
  final DogProfile dogProfile;

  const HealthJournalScreen({super.key, required this.dogProfile});

  @override
  State<HealthJournalScreen> createState() => _HealthJournalScreenState();
}

class _HealthJournalScreenState extends State<HealthJournalScreen> {
  List<HealthEntry> _healthEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHealthEntries();
  }

  Future<void> _loadHealthEntries() async {
    setState(() {
      _isLoading = true;
    });
    final entries = await DatabaseHelper.instance.getHealthEntriesForDog(widget.dogProfile.id!);
    setState(() {
      _healthEntries = entries;
      _isLoading = false;
    });
  }

  Future<void> _addOrEditHealthEntry({HealthEntry? entry}) async {
    final TextEditingController titleController = TextEditingController(text: entry?.title);
    final TextEditingController descriptionController = TextEditingController(text: entry?.description);
    String? selectedCategory = entry?.category;
    DateTime? selectedDate = entry != null ? DateTime.parse(entry.entryDate) : DateTime.now();

    final List<String> categories = ['Szczepienie', 'Wizyta u weterynarza', 'Leczenie', 'Dieta', 'Ogólne'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry == null ? 'Dodaj wpis zdrowia' : 'Edytuj wpis zdrowia'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Tytuł'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Proszę podać tytuł';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Opis (opcjonalnie)'),
                maxLines: 3,
              ),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Kategoria (opcjonalnie)'),
                items: categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  selectedCategory = newValue;
                },
              ),
              ListTile(
                title: Text(
                  'Data: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate!,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && picked != selectedDate) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tytuł nie może być pusty.')),
                );
                return;
              }

              final newEntry = HealthEntry(
                id: entry?.id,
                dogId: widget.dogProfile.id!,
                title: titleController.text,
                description: descriptionController.text.isEmpty ? null : descriptionController.text,
                entryDate: DateFormat('yyyy-MM-dd').format(selectedDate!),
                category: selectedCategory,
              );

              if (entry == null) {
                await DatabaseHelper.instance.insertHealthEntry(newEntry);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wpis dodany!')),
                );
              } else {
                await DatabaseHelper.instance.updateHealthEntry(newEntry);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wpis zaktualizowany!')),
                );
              }
              _loadHealthEntries();
              Navigator.pop(context);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHealthEntry(int entryId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: const Text('Czy na pewno chcesz usunąć ten wpis zdrowia?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Usuń')),
        ],
      ),
    );
    if (!context.mounted) return;

    if (confirm == true) {
      await DatabaseHelper.instance.deleteHealthEntry(entryId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wpis usunięty.')),
      );
      _loadHealthEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dziennik Zdrowia: ${widget.dogProfile.name}'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _healthEntries.isEmpty
              ? const Center(
                  child: Text(
                    'Brak wpisów w dzienniku zdrowia. Dodaj pierwszy wpis!',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _healthEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _healthEntries[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        title: Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Data: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(entry.entryDate))}'),
                            if (entry.category != null && entry.category!.isNotEmpty)
                              Text('Kategoria: ${entry.category}'),
                            if (entry.description != null && entry.description!.isNotEmpty)
                              Text('Opis: ${entry.description}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _addOrEditHealthEntry(entry: entry),
                              tooltip: 'Edytuj wpis',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteHealthEntry(entry.id!),
                              tooltip: 'Usuń wpis',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditHealthEntry(),
        child: const Icon(Icons.add),
        tooltip: 'Dodaj nowy wpis zdrowia',
      ),
    );
  }
}

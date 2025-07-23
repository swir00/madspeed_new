import 'dart:io'; // DODANO TEN IMPORT
import 'package:flutter/material.dart';
import 'package:madspeed_app/database/database_helper.dart'; // Zmieniono na madspeed_app
import 'package:madspeed_app/models/dog_profile.dart'; // Zmieniono na madspeed_app
import 'package:madspeed_app/screens/dog_profile_form_screen.dart'; // Zmieniono na madspeed_app
import 'package:madspeed_app/screens/dog_details_screen.dart'; // Zmieniono na madspeed_app

class DogProfileListScreen extends StatefulWidget {
  const DogProfileListScreen({super.key});

  @override
  State<DogProfileListScreen> createState() => _DogProfileListScreenState();
}

class _DogProfileListScreenState extends State<DogProfileListScreen> {
  List<DogProfile> _dogProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDogProfiles();
  }

  Future<void> _loadDogProfiles() async {
    setState(() {
      _isLoading = true;
    });
    final profiles = await DatabaseHelper.instance.getDogProfiles();
    setState(() {
      _dogProfiles = profiles;
      _isLoading = false;
    });
  }

  Future<void> _deleteDogProfile(int id) async {
    await DatabaseHelper.instance.deleteDogProfile(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil psa usunięty')),
    );
    _loadDogProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Psów'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dogProfiles.isEmpty
              ? const Center(
                  child: Text(
                    'Brak dodanych profili psów. Dodaj nowego psa!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _dogProfiles.length,
                  itemBuilder: (context, index) {
                    final dog = _dogProfiles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          backgroundImage: dog.photoPath != null && dog.photoPath!.isNotEmpty
                              ? Image.file(
                                  File(dog.photoPath!),
                                  fit: BoxFit.cover,
                                ).image
                              : null,
                          child: dog.photoPath == null || dog.photoPath!.isEmpty
                              ? Icon(
                                  Icons.pets,
                                  size: 30,
                                  color: Theme.of(context).primaryColor,
                                )
                              : null,
                        ),
                        title: Text(
                          dog.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (dog.breed != null && dog.breed!.isNotEmpty)
                              Text('Rasa: ${dog.breed}'),
                            if (dog.currentWeight != null)
                              Text('Waga: ${dog.currentWeight?.toStringAsFixed(1)} kg'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueGrey),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DogProfileFormScreen(dogProfile: dog),
                                  ),
                                );
                                _loadDogProfiles();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Usuń profil'),
                                    content: Text('Czy na pewno chcesz usunąć profil psa ${dog.name}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Anuluj'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          _deleteDogProfile(dog.id!);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                        ),
                                        child: const Text('Usuń', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DogDetailsScreen(dogProfile: dog),
                            ),
                          );
                          _loadDogProfiles();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DogProfileFormScreen()),
          );
          _loadDogProfiles();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

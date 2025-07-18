// lib/screens/dog_profile_form_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:madspeed_app/database/database_helper.dart';
import 'package:madspeed_app/models/dog_profile.dart';

class DogProfileFormScreen extends StatefulWidget {
  final DogProfile? dogProfile;

  const DogProfileFormScreen({super.key, this.dogProfile});

  @override
  State<DogProfileFormScreen> createState() => _DogProfileFormScreenState();
}

class _DogProfileFormScreenState extends State<DogProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _otherBreedController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _dailyDistanceGoalController = TextEditingController();
  final _dailyDurationGoalController = TextEditingController();

  String? _selectedGender;
  String? _selectedActivityLevel;
  DateTime? _selectedDateOfBirth;
  String? _imagePath;

  String? _selectedBreed;
  bool _isOtherBreedSelected = false;

  DateTime? _selectedLastVaccinationDate;
  DateTime? _selectedRabiesVaccinationDate; // NOWA ZMIENNA
  DateTime? _selectedLastDewormingDate; // NOWA ZMIENNA

  final List<String> _sighthoundBreeds = [
    'Afgan',
    'Azawakh',
    'Borzoj',
    
    'Chart Hiszpański (Galgo Español)',
    'Chart Irlandzki (Irish Wolfhound)',
    'Chart Perski (Saluki)',
    'Chart Polski',
    'Chart Szkocki (Deerhound)',
    'Chart Węgierski (Magyar Agár)',
    'Charcik Włoski (Italian Greyhound)',
    'Greyhound',
    'Inne',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.dogProfile != null) {
      _nameController.text = widget.dogProfile!.name;
      _weightController.text = widget.dogProfile!.currentWeight?.toString() ?? '';
      _selectedGender = widget.dogProfile!.gender;
      _selectedActivityLevel = widget.dogProfile!.activityLevel;
      if (widget.dogProfile!.dateOfBirth != null) {
        _selectedDateOfBirth = DateTime.parse(widget.dogProfile!.dateOfBirth!);
      }
      _imagePath = widget.dogProfile!.photoPath;

      if (widget.dogProfile!.breed != null) {
        if (_sighthoundBreeds.contains(widget.dogProfile!.breed)) {
          _selectedBreed = widget.dogProfile!.breed;
          _isOtherBreedSelected = false;
        } else {
          _selectedBreed = 'Inne';
          _isOtherBreedSelected = true;
          _otherBreedController.text = widget.dogProfile!.breed!;
        }
      }
      _targetWeightController.text = widget.dogProfile!.targetWeight?.toString() ?? '';
      _dailyDistanceGoalController.text = widget.dogProfile!.dailyDistanceGoal?.toString() ?? '';
      _dailyDurationGoalController.text = widget.dogProfile!.dailyDurationGoal?.toString() ?? '';

      if (widget.dogProfile!.lastVaccinationDate != null) {
        _selectedLastVaccinationDate = DateTime.parse(widget.dogProfile!.lastVaccinationDate!);
      }
      // Załaduj nowe daty
      if (widget.dogProfile!.rabiesVaccinationDate != null) {
        _selectedRabiesVaccinationDate = DateTime.parse(widget.dogProfile!.rabiesVaccinationDate!);
      }
      if (widget.dogProfile!.lastDewormingDate != null) {
        _selectedLastDewormingDate = DateTime.parse(widget.dogProfile!.lastDewormingDate!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _otherBreedController.dispose();
    _targetWeightController.dispose();
    _dailyDistanceGoalController.dispose();
    _dailyDurationGoalController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceSelection() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Zrób zdjęcie (Aparat)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Wybierz z galerii (Galeria)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _selectLastVaccinationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedLastVaccinationDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedLastVaccinationDate) {
      setState(() {
        _selectedLastVaccinationDate = picked;
      });
    }
  }

  // NOWA FUNKCJA: Wybór daty szczepienia na wściekliznę
  Future<void> _selectRabiesVaccinationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedRabiesVaccinationDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedRabiesVaccinationDate) {
      setState(() {
        _selectedRabiesVaccinationDate = picked;
      });
    }
  }

  // NOWA FUNKCJA: Wybór daty ostatniego odrobaczenia
  Future<void> _selectLastDewormingDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedLastDewormingDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedLastDewormingDate) {
      setState(() {
        _selectedLastDewormingDate = picked;
      });
    }
  }

  Future<void> _saveDogProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      String? finalBreed;
      if (_selectedBreed == 'Inne') {
        finalBreed = _otherBreedController.text.isNotEmpty ? _otherBreedController.text : null;
      } else {
        finalBreed = _selectedBreed;
      }

      final newDog = DogProfile(
        id: widget.dogProfile?.id,
        name: _nameController.text,
        breed: finalBreed,
        dateOfBirth: _selectedDateOfBirth?.toIso8601String().split('T')[0],
        gender: _selectedGender,
        currentWeight: double.tryParse(_weightController.text),
        activityLevel: _selectedActivityLevel,
        photoPath: _imagePath,
        targetWeight: double.tryParse(_targetWeightController.text),
        dailyDistanceGoal: double.tryParse(_dailyDistanceGoalController.text),
        dailyDurationGoal: int.tryParse(_dailyDurationGoalController.text),
        lastVaccinationDate: _selectedLastVaccinationDate?.toIso8601String().split('T')[0],
        rabiesVaccinationDate: _selectedRabiesVaccinationDate?.toIso8601String().split('T')[0], // Zapisz datę
        lastDewormingDate: _selectedLastDewormingDate?.toIso8601String().split('T')[0], // Zapisz datę
      );

      if (widget.dogProfile == null) {
        await DatabaseHelper.instance.insertDogProfile(newDog);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil psa dodany!')),
        );
      } else {
        await DatabaseHelper.instance.updateDogProfile(newDog);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil psa zaktualizowany!')),
        );
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dogProfile == null ? 'Dodaj Psa' : 'Edytuj Psa'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceSelection,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _imagePath != null && _imagePath!.isNotEmpty
                        ? Image.file(File(_imagePath!), fit: BoxFit.cover).image
                        : null,
                    child: _imagePath == null || _imagePath!.isEmpty
                        ? Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.grey[600],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Imię psa',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Proszę podać imię psa';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedBreed,
                decoration: const InputDecoration(
                  labelText: 'Rasa (opcjonalnie)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _sighthoundBreeds.map((String breed) {
                  return DropdownMenuItem<String>(
                    value: breed,
                    child: Text(breed),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedBreed = newValue;
                    _isOtherBreedSelected = (newValue == 'Inne');
                    if (!_isOtherBreedSelected) {
                      _otherBreedController.clear();
                    }
                  });
                },
              ),
              if (_isOtherBreedSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TextFormField(
                    controller: _otherBreedController,
                    decoration: const InputDecoration(
                      labelText: 'Wpisz inną rasę',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit),
                    ),
                    validator: (value) {
                      if (_selectedBreed == 'Inne' && (value == null || value.isEmpty)) {
                        return 'Proszę podać nazwę rasy';
                      }
                      return null;
                    },
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Aktualna waga (kg, opcjonalnie)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight),
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
                controller: _targetWeightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Waga docelowa (kg, opcjonalnie)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.track_changes),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                    return 'Proszę podać prawidłową wagę docelową';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dailyDistanceGoalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dzienny cel dystansu (metry, opcjonalnie)',
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
                  labelText: 'Dzienny cel czasu aktywności (minuty, opcjonalnie)',
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
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _selectedDateOfBirth == null
                      ? 'Wybierz datę urodzenia (opcjonalnie)'
                      : 'Data urodzenia: ${DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDateOfBirth(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _selectedLastVaccinationDate == null
                      ? 'Data ostatniego szczepienia (ogólne, opcjonalnie)'
                      : 'Ostatnie szczepienie (ogólne): ${DateFormat('yyyy-MM-dd').format(_selectedLastVaccinationDate!)}',
                ),
                trailing: const Icon(Icons.vaccines),
                onTap: () => _selectLastVaccinationDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
              // NOWE POLE: Data szczepienia na wściekliznę
              ListTile(
                title: Text(
                  _selectedRabiesVaccinationDate == null
                      ? 'Data szczepienia na wściekliznę (opcjonalnie)'
                      : 'Szczepienie na wściekliznę: ${DateFormat('yyyy-MM-dd').format(_selectedRabiesVaccinationDate!)}',
                ),
                trailing: const Icon(Icons.vaccines),
                onTap: () => _selectRabiesVaccinationDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
              // NOWE POLE: Data ostatniego odrobaczenia
              ListTile(
                title: Text(
                  _selectedLastDewormingDate == null
                      ? 'Data ostatniego odrobaczenia (opcjonalnie)'
                      : 'Ostatnie odrobaczenie: ${DateFormat('yyyy-MM-dd').format(_selectedLastDewormingDate!)}',
                ),
                trailing: const Icon(Icons.medication), // Ikona dla odrobaczenia
                onTap: () => _selectLastDewormingDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Płeć (opcjonalnie)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wc),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Samiec')),
                  DropdownMenuItem(value: 'Female', child: Text('Samica')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedActivityLevel,
                decoration: const InputDecoration(
                  labelText: 'Poziom aktywności (opcjonalnie)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_run),
                ),
                items: const [
                  DropdownMenuItem(value: 'Low', child: Text('Niski')),
                  DropdownMenuItem(value: 'Moderate', child: Text('Umiarkowany')),
                  DropdownMenuItem(value: 'High', child: Text('Wysoki')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedActivityLevel = value;
                  });
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saveDogProfile,
                icon: const Icon(Icons.save),
                label: Text(widget.dogProfile == null ? 'Dodaj Psa' : 'Zapisz Zmiany'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

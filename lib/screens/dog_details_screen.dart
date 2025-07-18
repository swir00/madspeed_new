// lib/screens/dog_details_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:madspeed_app/database/database_helper.dart';
import 'package:madspeed_app/models/dog_profile.dart';
import 'package:madspeed_app/models/weight_entry.dart';
import 'package:madspeed_app/models/training.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:madspeed_app/models/training_session.dart';
import 'package:madspeed_app/services/weather_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:madspeed_app/widgets/training_session_preview_widget.dart';
import 'package:madspeed_app/widgets/edit_fitness_goals_dialog.dart';
import 'package:madspeed_app/screens/health_journal_screen.dart';
import 'package:madspeed_app/models/health_entry.dart';
import 'package:madspeed_app/widgets/edit_health_dates_dialog.dart';

class DogDetailsScreen extends StatefulWidget {
  final DogProfile dogProfile;

  const DogDetailsScreen({super.key, required this.dogProfile});

  @override
  State<DogDetailsScreen> createState() => _DogDetailsScreenState();
}

class _DogDetailsScreenState extends State<DogDetailsScreen> {
  late DogProfile _currentDogProfile;
  List<WeightEntry> _weightEntries = [];
  List<TrainingSession> _dogTrainingSessions = [];
  List<HealthEntry> _healthEntries = [];
  bool _isLoading = true;
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _currentDogProfile = widget.dogProfile;
    _loadDogData();
  }

  Future<void> _loadDogData() async {
    setState(() {
      _isLoading = true;
    });
    final updatedDog = await DatabaseHelper.instance.getDogProfile(_currentDogProfile.id!);
    final weights = await DatabaseHelper.instance.getWeightEntriesForDog(_currentDogProfile.id!);
    final sessions = await _getTrainingSessionsForDog(_currentDogProfile.id!);
    final healthEntries = await DatabaseHelper.instance.getHealthEntriesForDog(_currentDogProfile.id!);

    setState(() {
      if (updatedDog != null) {
        _currentDogProfile = updatedDog;
      }
      _weightEntries = weights;
      _dogTrainingSessions = sessions;
      _healthEntries = healthEntries;
      _isLoading = false;
    });
  }

  Future<List<TrainingSession>> _getTrainingSessionsForDog(int dogId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('training_sessions');
    List<TrainingSession> allSessions = [];
    if (sessionsJson != null) {
      allSessions = TrainingSession.decode(sessionsJson);
    }
    return allSessions.where((s) => s.dogId == dogId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _addWeightEntry() async {
    TextEditingController weightController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj wagę'),
        content: TextField(
          controller: weightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Waga (kg)',
            hintText: 'np. 15.5',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              final weight = double.tryParse(weightController.text);
              if (weight != null && weight > 0) {
                final newEntry = WeightEntry(
                  dogId: _currentDogProfile.id!,
                  weight: weight,
                  timestamp: DateTime.now().toIso8601String(),
                );
                await DatabaseHelper.instance.insertWeightEntry(newEntry);
                await DatabaseHelper.instance.updateDogProfile(
                  _currentDogProfile.copyWith(currentWeight: weight),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Waga dodana!')),
                );
                _loadDogData();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Proszę podać prawidłową wagę')),
                );
              }
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWeightEntry(int entryId) async {
    await DatabaseHelper.instance.deleteWeightEntry(entryId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wpis wagi usunięty')),
    );
    _loadDogData();
  }

  String _getDogAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) {
      return 'Nieznany';
    }
    final dob = DateTime.parse(dateOfBirth);
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;

    if (months < 0 || (months == 0 && days < 0)) {
      years--;
      months += (days < 0 ? 11 : 12);
    }
    if (days < 0) {
      final lastMonth = DateTime(now.year, now.month - 1, dob.day);
      days = now.difference(lastMonth).inDays;
    }

    if (years > 0) {
      return '$years lat, $months mies.';
    } else if (months > 0) {
      return '$months mies., $days dni';
    } else {
      return '$days dni';
    }
  }

  double _calculateCaloriesBurned(TrainingSession session, DogProfile dogProfile, Map<String, dynamic>? weatherData) {
    final double? dogWeightKg = dogProfile.currentWeight;
    final String? activityLevel = dogProfile.activityLevel;

    if (dogWeightKg == null || dogWeightKg <= 0) return 0.0;

    final double distanceKm = session.distance / 1000.0;
    final double avgSpeedKmH = session.averageSpeed;

    const double baseCaloriesPerKgPerKm = 0.9;

    double speedAdjustmentFactor = 1.0;
    if (avgSpeedKmH > 0) {
      speedAdjustmentFactor = 1.0 + (avgSpeedKmH / 10.0) * 0.1;
    }

    double activityLevelMultiplier = 1.0;
    switch (activityLevel) {
      case 'Low':
        activityLevelMultiplier = 0.8;
        break;
      case 'Moderate':
        activityLevelMultiplier = 1.0;
        break;
      case 'High':
        activityLevelMultiplier = 1.2;
        break;
    }

    double temperatureAdjustmentFactor = 1.0;
    if (weatherData != null && weatherData.containsKey('temperature')) {
      final double temperature = weatherData['temperature'];
      if (temperature < 0) {
        temperatureAdjustmentFactor = 1.0 + ((-temperature) * 0.02);
      } else if (temperature > 25) {
        temperatureAdjustmentFactor = 1.0 + ((temperature - 25) * 0.01);
      }
    }

    double totalCalories = distanceKm * dogWeightKg * baseCaloriesPerKgPerKm * speedAdjustmentFactor * activityLevelMultiplier * temperatureAdjustmentFactor;

    return totalCalories;
  }

  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return 'N/A';
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceMeters / 1000.0).toStringAsFixed(3)} km';
    }
  }

  String _formatDurationMinutes(int? minutes) {
    if (minutes == null) return 'N/A';
    final duration = Duration(minutes: minutes);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String hrs = twoDigits(duration.inHours);
    final String mins = twoDigits(duration.inMinutes.remainder(60));
    return '${hrs}g ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentDogProfile.name),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sekcja informacji o psie
                  Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              backgroundImage: _currentDogProfile.photoPath != null &&
                                      _currentDogProfile.photoPath!.isNotEmpty
                                  ? Image.file(File(_currentDogProfile.photoPath!), fit: BoxFit.cover).image
                                  : null,
                              child: _currentDogProfile.photoPath == null ||
                                      _currentDogProfile.photoPath!.isEmpty
                                  ? Icon(
                                      Icons.pets,
                                      size: 60,
                                      color: Theme.of(context).primaryColor,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _currentDogProfile.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(),
                          _buildDetailRow(Icons.category, 'Rasa:', _currentDogProfile.breed ?? 'Nieznana'),
                          _buildDetailRow(Icons.cake, 'Wiek:', _getDogAge(_currentDogProfile.dateOfBirth)),
                          _buildDetailRow(Icons.wc, 'Płeć:', _currentDogProfile.gender == 'Male' ? 'Samiec' : (_currentDogProfile.gender == 'Female' ? 'Samica' : 'Nieznana')),
                          _buildDetailRow(Icons.monitor_weight, 'Aktualna waga:', _currentDogProfile.currentWeight != null ? '${_currentDogProfile.currentWeight!.toStringAsFixed(1)} kg' : 'Brak danych'),
                          _buildDetailRow(Icons.directions_run, 'Poziom aktywności:', _currentDogProfile.activityLevel == 'Low' ? 'Niski' : (_currentDogProfile.activityLevel == 'Moderate' ? 'Umiarkowany' : (_currentDogProfile.activityLevel == 'High' ? 'Wysoki' : 'Nieznany'))),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daty Zdrowotne:',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () async {
                                  final DogProfile? updatedHealthDatesDog = await showDialog<DogProfile>(
                                    context: context,
                                    builder: (context) => EditHealthDatesDialog(dogProfile: _currentDogProfile),
                                  );

                                  if (updatedHealthDatesDog != null) {
                                    _currentDogProfile = _currentDogProfile.copyWith(
                                      lastVaccinationDate: updatedHealthDatesDog.lastVaccinationDate,
                                      rabiesVaccinationDate: updatedHealthDatesDog.rabiesVaccinationDate,
                                      lastDewormingDate: updatedHealthDatesDog.lastDewormingDate,
                                    );
                                    await DatabaseHelper.instance.updateDogProfile(_currentDogProfile);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Daty zdrowotne zaktualizowane!')),
                                      );
                                    }
                                    _loadDogData();
                                  }
                                },
                                tooltip: 'Edytuj daty szczepień i odrobaczenia',
                              ),
                            ],
                          ),
                          _buildDetailRow(Icons.vaccines, 'Ostatnie szczepienie (ogólne):', _currentDogProfile.lastVaccinationDate != null ? DateFormat.yMd(Localizations.localeOf(context).toString()).format(DateTime.parse(_currentDogProfile.lastVaccinationDate!)) : 'Brak danych'),
                          _buildDetailRow(Icons.vaccines, 'Szczepienie na wściekliznę:', _currentDogProfile.rabiesVaccinationDate != null ? DateFormat.yMd(Localizations.localeOf(context).toString()).format(DateTime.parse(_currentDogProfile.rabiesVaccinationDate!)) : 'Brak danych'),
                          _buildDetailRow(Icons.medication, 'Ostatnie odrobaczenie:', _currentDogProfile.lastDewormingDate != null ? DateFormat.yMd(Localizations.localeOf(context).toString()).format(DateTime.parse(_currentDogProfile.lastDewormingDate!)) : 'Brak danych'),
                        ],
                      ),
                    ),
                  ),

                  // Sekcja Celów Fitness
                  Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cele Fitness',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () async {
                                  final DogProfile? updatedGoalsDog = await showDialog<DogProfile>(
                                    context: context,
                                    builder: (context) => EditFitnessGoalsDialog(dogProfile: _currentDogProfile),
                                  );

                                  if (updatedGoalsDog != null) {
                                    _currentDogProfile = _currentDogProfile.copyWith(
                                      targetWeight: updatedGoalsDog.targetWeight,
                                      dailyDistanceGoal: updatedGoalsDog.dailyDistanceGoal,
                                      dailyDurationGoal: updatedGoalsDog.dailyDurationGoal,
                                    );
                                    await DatabaseHelper.instance.updateDogProfile(_currentDogProfile);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Cele fitness zaktualizowane!')),
                                      );
                                    }
                                    _loadDogData();
                                  }
                                },
                                tooltip: 'Edytuj cele fitness',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(Icons.track_changes, 'Waga docelowa:', _currentDogProfile.targetWeight != null ? '${_currentDogProfile.targetWeight!.toStringAsFixed(1)} kg' : 'Brak celu'),
                          _buildDetailRow(Icons.directions_walk, 'Dzienny cel dystansu:', _formatDistance(_currentDogProfile.dailyDistanceGoal)),
                          _buildDetailRow(Icons.timer, 'Dzienny cel czasu aktywności:', _formatDurationMinutes(_currentDogProfile.dailyDurationGoal)),
                        ],
                      ),
                    ),
                  ),

                  // Sekcja Dziennik Zdrowia
                  Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Dziennik Zdrowia',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.launch, color: Colors.blue),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HealthJournalScreen(dogProfile: _currentDogProfile),
                                    ),
                                  );
                                  _loadDogData();
                                },
                                tooltip: 'Otwórz dziennik zdrowia',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _healthEntries.isEmpty
                              ? const Text('Brak wpisów w dzienniku zdrowia.')
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _healthEntries.take(2).map((entry) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      '${DateFormat('yyyy-MM-dd').format(DateTime.parse((entry as HealthEntry).entryDate))}: ${(entry as HealthEntry).title}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  )).toList(),
                                ),
                        ],
                      ),
                    ),
                  ),

                  // Sekcja Waga i Wykres
                  Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Historia Wagi',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              ElevatedButton.icon(
                                onPressed: _addWeightEntry,
                                icon: const Icon(Icons.add),
                                label: const Text('Dodaj Wagę'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _weightEntries.isEmpty
                              ? const Center(child: Text('Brak wpisów wagi.'))
                              : SizedBox(
                                  height: 200,
                                  child: LineChart(
                                    _buildWeightChartData(),
                                  ),
                                ),
                          const SizedBox(height: 16),
                          if (_weightEntries.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wpisy wagi:',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _weightEntries.length,
                                  itemBuilder: (context, index) {
                                    final entry = _weightEntries[index];
                                    return ListTile(
                                      title: Text('${entry.weight.toStringAsFixed(1)} kg'),
                                      subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(entry.timestamp))),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Usuń wpis wagi'),
                                              content: const Text('Czy na pewno chcesz usunąć ten wpis wagi?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Anuluj'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    _deleteWeightEntry(entry.id!);
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
                                    );
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Sekcja Historia Treningów
                  Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historia Treningów',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _dogTrainingSessions.isEmpty
                              ? const Center(child: Text('Brak treningów dla tego psa.'))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _dogTrainingSessions.length,
                                  itemBuilder: (context, index) {
                                    final session = _dogTrainingSessions[index];
                                    return FutureBuilder<Map<String, dynamic>?>(
                                      future: session.startLocation != null
                                          ? _weatherService.fetchWeather(session.startLocation!)
                                          : Future.value(null),
                                      builder: (context, snapshot) {
                                        Map<String, dynamic>? weatherData = snapshot.data;
                                        final caloriesBurned = _calculateCaloriesBurned(session, _currentDogProfile, weatherData);
                                        return Card(
                                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          child: InkWell(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  // Zmodyfikowany tytuł z przyciskiem "X"
                                                  title: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(session.name),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.close, color: Colors.red), // Czerwony "X"
                                                        onPressed: () {
                                                          Navigator.pop(context); // Zamknij dialog
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  contentPadding: EdgeInsets.zero,
                                                  insetPadding: const EdgeInsets.all(16.0),
                                                  content: SizedBox(
                                                    width: MediaQuery.of(context).size.width * 0.9,
                                                    height: MediaQuery.of(context).size.height * 0.7,
                                                    child: TrainingSessionPreviewWidget(
                                                      session: session,
                                                      dogName: _currentDogProfile.name,
                                                    ),
                                                  ),
                                                  // Usunięto sekcję actions
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Nazwa: ${session.name}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  Text(
                                                    'Data: ${DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hm().format(session.timestamp)}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  Text('Dystans: ${(session.distance / 1000).toStringAsFixed(2)} km'),
                                                  Text('Średnia prędkość: ${session.averageSpeed.toStringAsFixed(1)} km/h'),
                                                  Text('Maksymalna prędkość: ${session.maxSpeed.toStringAsFixed(1)} km/h'),
                                                  Text('Czas trwania: ${Duration(seconds: session.duration).inMinutes} min ${Duration(seconds: session.duration).inSeconds.remainder(60)} sek'),
                                                  Text('Spalone kalorie (szacunkowo): ${caloriesBurned.toStringAsFixed(2)} kcal'),
                                                  _buildWeatherContent(snapshot, session),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWeatherContent(AsyncSnapshot<Map<String, dynamic>?> snapshot, TrainingSession session) {
    if (session.startLocation == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text('Brak danych o lokalizacji dla tego treningu.'),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text('Pobieram dane pogodowe...'),
      );
    }

    if (snapshot.hasError) {
      // Log the error for debugging
      print('Błąd FutureBuilder pogody: ${snapshot.error}');
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text(
          'Brak danych pogodowych. Sprawdź połączenie z internetem lub klucz API.',
          style: TextStyle(color: Colors.orange),
        ),
      );
    }

    if (snapshot.hasData) {
      final weatherData = snapshot.data!;
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            Image.network(
              _weatherService.getWeatherIconUrl(weatherData['icon']),
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.cloud_off),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pogoda: ${weatherData['description']}'),
                  Text('Temp: ${weatherData['temperature'].toStringAsFixed(1)}°C (odczuwalna: ${weatherData['feels_like'].toStringAsFixed(1)}°C)'),
                  Text('Wiatr: ${weatherData['wind_speed'].toStringAsFixed(1)} m/s, Wilgotność: ${weatherData['humidity']}%'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // This case should ideally not be reached if startLocation is not null,
    // but it's a good fallback.
    return const Padding(
      padding: EdgeInsets.only(top: 8.0),
      child: Text('Nie udało się pobrać danych pogodowych.'),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  LineChartData _buildWeightChartData() {
    if (_weightEntries.isEmpty) {
      return LineChartData(
        lineBarsData: [],
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
      );
    }

    _weightEntries.sort((a, b) => DateTime.parse(a.timestamp).compareTo(DateTime.parse(b.timestamp)));

    final List<FlSpot> spots = _weightEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weight);
    }).toList();

    final double minWeight = _weightEntries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    final double maxWeight = _weightEntries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    List<String> xTitles = _weightEntries.map((e) => DateFormat('dd.MM').format(DateTime.parse(e.timestamp))).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Color(0xff37434d),
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return const FlLine(
            color: Color(0xff37434d),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < xTitles.length) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8.0,
                  child: Text(xTitles[value.toInt()], style: const TextStyle(fontSize: 10)),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text('${value.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 10));
            },
            interval: (maxWeight - minWeight) > 5 ? 2.0 : 1.0,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d), width: 1),
      ),
      minX: 0,
      maxX: (spots.length - 1).toDouble(),
      minY: minWeight - 1,
      maxY: maxWeight + 1,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.3),
                Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

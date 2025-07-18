// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:madspeed_app/database/database_helper.dart';
import 'package:madspeed_app/models/training.dart';
import 'package:intl/intl.dart';
import 'package:madspeed_app/models/training_session.dart';
import 'package:madspeed_app/services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:madspeed_app/widgets/training_session_preview_widget.dart';
import 'package:madspeed_app/models/dog_profile.dart'; // Import DogProfile

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TrainingSession> _trainingSessions = [];
  bool _isLoading = true;
  final WeatherService _weatherService = WeatherService();
  Map<int, DogProfile> _dogProfilesMap = {}; // Mapa do przechowywania profili psów

  @override
  void initState() {
    super.initState();
    _loadTrainingSessions();
  }

  Future<void> _loadTrainingSessions() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('training_sessions');
    List<TrainingSession> loadedSessions = [];
    if (sessionsJson != null) {
      loadedSessions = TrainingSession.decode(sessionsJson);
    }

    // Posortuj sesje od najnowszej do najstarszej
    loadedSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Załaduj wszystkie profile psów do mapy dla szybkiego dostępu
    final allDogProfiles = await DatabaseHelper.instance.getDogProfiles();
    _dogProfilesMap = {for (var dog in allDogProfiles) dog.id!: dog};

    setState(() {
      _trainingSessions = loadedSessions;
      _isLoading = false;
    });
  }

  Future<void> _deleteTrainingSession(int index) async {
    final sessionToDelete = _trainingSessions[index];
    setState(() {
      _trainingSessions.removeAt(index);
    });

    final prefs = await SharedPreferences.getInstance();
    prefs.setString('training_sessions', TrainingSession.encode(_trainingSessions));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesja treningowa usunięta!')),
    );
  }

  // Obliczanie szacunkowych kalorii spalonych w treningu z pogodą
  double _calculateCaloriesBurned(TrainingSession session, DogProfile? dogProfile, Map<String, dynamic>? weatherData) {
    final double? dogWeightKg = dogProfile?.currentWeight;
    final String? activityLevel = dogProfile?.activityLevel;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia Treningów'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trainingSessions.isEmpty
              ? const Center(
                  child: Text(
                    'Brak zapisanych sesji treningowych.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _trainingSessions.length,
                  itemBuilder: (context, index) {
                    final session = _trainingSessions[index];
                    final dogProfile = session.dogId != null ? _dogProfilesMap[session.dogId] : null;

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: session.startLocation != null
                          ? _weatherService.fetchWeather(session.startLocation!)
                          : Future.value(null),
                      builder: (context, snapshot) {
                        Map<String, dynamic>? weatherData = snapshot.data;
                        final caloriesBurned = _calculateCaloriesBurned(session, dogProfile, weatherData);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                      dogName: dogProfile?.name ?? 'Nieznany pies',
                                    ),
                                  ),
                                  // Usunięto sekcję actions
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Pies: ${dogProfile?.name ?? 'Nieznany'}'),
                                  Text('Data: ${DateFormat('yyyy-MM-dd HH:mm').format(session.timestamp)}'),
                                  Text('Dystans: ${(session.distance / 1000).toStringAsFixed(2)} km'),
                                  Text('Średnia prędkość: ${session.averageSpeed.toStringAsFixed(1)} km/h'),
                                  Text('Maksymalna prędkość: ${session.maxSpeed.toStringAsFixed(1)} km/h'),
                                  Text('Czas trwania: ${Duration(seconds: session.duration).inMinutes} min ${Duration(seconds: session.duration).inSeconds.remainder(60)} sek'),
                                  Text('Spalone kalorie (szacunkowo): ${caloriesBurned.toStringAsFixed(2)} kcal'),
                                  if (snapshot.connectionState == ConnectionState.waiting)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: Text('Pobieram dane pogodowe...'),
                                    )
                                  else if (weatherData != null)
                                    Padding(
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
                                    )
                                  else if (session.startLocation != null)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: Text('Brak danych pogodowych dla tego treningu (sprawdź połączenie z internetem lub lokalizację).'),
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: Text('Brak danych o lokalizacji dla tego treningu.'),
                                    ),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Usuń sesję treningową'),
                                            content: const Text('Czy na pewno chcesz usunąć tę sesję treningową?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Anuluj'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  _deleteTrainingSession(index);
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

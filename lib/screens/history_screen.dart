// lib/screens/history_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:madspeed_app/database/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:madspeed_app/models/training_session.dart';
import 'package:madspeed_app/models/walk_session_model.dart';
import 'package:madspeed_app/screens/map_view_screen.dart';
import 'package:madspeed_app/widgets/walk_session_preview_widget.dart';
import 'package:madspeed_app/services/weather_service.dart';
import 'package:madspeed_app/utils/walk_session_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:madspeed_app/widgets/training_session_preview_widget.dart';
import 'package:madspeed_app/widgets/edit_training_session_dialog.dart';
import 'package:madspeed_app/widgets/edit_walk_session_dialog.dart';
import 'package:madspeed_app/models/dog_profile.dart'; // Import DogProfile

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TrainingSession> _trainingSessions = [];
  List<WalkSession> _walkSessions = [];
  bool _isLoading = true;
  final WeatherService _weatherService = WeatherService();
  Map<int, DogProfile> _dogProfilesMap = {}; // Mapa do przechowywania profili psów

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSessions() async {
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

    // Wczytywanie spacerów
    final loadedWalks = await WalkSessionHelper.loadWalkSessions();

    setState(() {
      _trainingSessions = loadedSessions;
      _walkSessions = loadedWalks;
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

  Future<void> _deleteWalkSession(int index) async {
    final sessionToDelete = _walkSessions[index];
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: const Text('Czy na pewno chcesz usunąć ten spacer?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Usuń')),
        ],
      ),
    );

    if (confirmed == true) {
      await WalkSessionHelper.deleteWalkSession(sessionToDelete.id);
      await _loadAllSessions(); // Odśwież listę
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spacer usunięty.')),
        );
      }
    }
  }

  Future<void> _editTrainingSession(TrainingSession sessionToEdit, int index) async {
    final List<DogProfile> allDogs = _dogProfilesMap.values.toList();
    final updatedSession = await showDialog<TrainingSession>(
      context: context,
      builder: (context) => EditTrainingSessionDialog(
        session: sessionToEdit,
        allDogs: allDogs,
      ),
    );

    if (updatedSession != null && mounted) {
      setState(() {
        _trainingSessions[index] = updatedSession;
        _trainingSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('training_sessions', TrainingSession.encode(_trainingSessions));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trening zaktualizowany.')),
      );
    }
  }

  Future<void> _editWalkSession(WalkSession sessionToEdit, int index) async {
    final List<DogProfile> allDogs = _dogProfilesMap.values.toList();
    final updatedSession = await showDialog<WalkSession>(
      context: context,
      builder: (context) => EditWalkSessionDialog(
        session: sessionToEdit,
        allDogs: allDogs,
      ),
    );

    if (updatedSession != null && mounted) {
      await WalkSessionHelper.saveWalkSession(updatedSession);
      await _loadAllSessions(); // Odśwież i posortuj
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spacer zaktualizowany.')),
      );
    }
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

  double _calculateTotalWalkCalories(WalkSession session) {
    double totalCalories = 0.0;
    if (session.dogIds.isEmpty) return 0.0;

    for (var dogId in session.dogIds) {
      final dogProfile = _dogProfilesMap[dogId];
      if (dogProfile != null) {
        final double? dogWeightKg = dogProfile.currentWeight;
        if (dogWeightKg != null && dogWeightKg > 0) {
          const double met = 3.0; // Wartość MET dla spaceru z psem
          final double durationMinutes = session.duration.inSeconds / 60.0;
          if (durationMinutes > 0) {
            // Kalorie/min = (MET * waga_w_kg * 3.5) / 200
            totalCalories += (met * dogWeightKg * 3.5) / 200 * durationMinutes;
          }
        }
      }
    }
    return totalCalories;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia Aktywności'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.run_circle_outlined), text: 'Treningi'),
            Tab(icon: Icon(Icons.directions_walk), text: 'Spacery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _isLoading
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                        tooltip: 'Edytuj trening',
                                        onPressed: () => _editTrainingSession(session, index),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        tooltip: 'Usuń trening',
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
                                    ],
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
          _buildWalksList(),
        ],
      ),
    );
  }

  Widget _buildDogAvatars(List<int?> dogIds) {
    if (dogIds.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> avatars = dogIds.map((id) {
      final dogProfile = _dogProfilesMap[id];
      if (dogProfile == null) return const SizedBox.shrink();

      final imageFile =
          dogProfile.photoPath != null ? File(dogProfile.photoPath!) : null;
      final imageExists = imageFile?.existsSync() ?? false;

      return Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Tooltip(
          message: dogProfile.name,
          child: CircleAvatar(
            radius: 15,
            backgroundImage: imageExists ? FileImage(imageFile!) : null,
            child: !imageExists && dogProfile.name.isNotEmpty
                ? Text(dogProfile.name[0].toUpperCase())
                : null,
          ),
        ),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(spacing: 4.0, runSpacing: 4.0, children: avatars),
    );
  }

  Widget _buildWalksList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_walkSessions.isEmpty) {
      return const Center(
          child: Text(
        'Brak zapisanych spacerów.',
        style: TextStyle(fontSize: 18, color: Colors.grey),
        textAlign: TextAlign.center,
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _walkSessions.length,
      itemBuilder: (context, index) {
        final session = _walkSessions[index];
        final totalCalories = _calculateTotalWalkCalories(session);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onWalkTapped(session),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.directions_walk,
                      color: Colors.green, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 4),
                        Text(
                            '${DateFormat('dd.MM.yyyy HH:mm').format(session.date)}',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.straighten,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                                '${(session.distance / 1000).toStringAsFixed(2)} km'),
                            const SizedBox(width: 16),
                            const Icon(Icons.timer_outlined,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${session.duration.inMinutes} min'),
                          ],
                        ),
                        if (totalCalories > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.local_fire_department,
                                  size: 16, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text('${totalCalories.toStringAsFixed(0)} kcal (łącznie)'),
                            ],
                          ),
                        ),
                        _buildDogAvatars(session.dogIds),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        tooltip: 'Edytuj spacer',
                        onPressed: () => _editWalkSession(session, index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        tooltip: 'Usuń spacer',
                        onPressed: () => _deleteWalkSession(index),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onWalkTapped(WalkSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(session.name)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.all(16.0),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: WalkSessionPreviewWidget(
            session: session,
            dogProfilesMap: _dogProfilesMap,
          ),
        ),
      ),
    );
  }
}

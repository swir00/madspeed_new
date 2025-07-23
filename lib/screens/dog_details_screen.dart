import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:madspeed_app/database/database_helper.dart';
import 'package:madspeed_app/models/dog_profile.dart';
import 'package:madspeed_app/models/weight_entry.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:madspeed_app/models/training_session.dart';
import 'package:madspeed_app/models/walk_session_model.dart';
import 'package:madspeed_app/screens/map_view_screen.dart';
import 'package:madspeed_app/widgets/walk_session_preview_widget.dart';
import 'package:madspeed_app/services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:madspeed_app/widgets/training_session_preview_widget.dart';
import 'package:madspeed_app/widgets/edit_fitness_goals_dialog.dart';
import 'package:madspeed_app/screens/health_journal_screen.dart';
import 'package:madspeed_app/models/health_entry.dart';
import 'package:madspeed_app/widgets/edit_training_session_dialog.dart';
import 'package:madspeed_app/widgets/edit_walk_session_dialog.dart';
import 'package:madspeed_app/widgets/edit_health_dates_dialog.dart';
import 'package:madspeed_app/utils/walk_session_helper.dart';

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
  List<WalkSession> _dogWalkSessions = [];
  List<HealthEntry> _healthEntries = [];
  bool _isLoading = true;
  Map<int, DogProfile> _dogProfilesMap = {};
  final WeatherService _weatherService = WeatherService();

  // Dodano ScrollController
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentDogProfile = widget.dogProfile;
    _loadDogData();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Zwolnij kontroler po zakończeniu pracy
    super.dispose();
  }

  Future<void> _loadDogData({double? scrollOffset}) async {
    // Zapisz bieżący offset przewijania, jeśli nie podano konkretnego
    final double currentOffset = scrollOffset ?? (_scrollController.hasClients ? _scrollController.offset : 0.0);

    setState(() {
      _isLoading = true;
    });

    final allDogProfiles = await DatabaseHelper.instance.getDogProfiles();
    _dogProfilesMap = {for (var dog in allDogProfiles) if (dog.id != null) dog.id!: dog};

    final updatedDog = await DatabaseHelper.instance.getDogProfile(_currentDogProfile.id!);
    final weights = await DatabaseHelper.instance.getWeightEntriesForDog(_currentDogProfile.id!);
    final sessions = await _getTrainingSessionsForDog(_currentDogProfile.id!);
    final walks = await _getWalkSessionsForDog(_currentDogProfile.id!);
    final healthEntries = await DatabaseHelper.instance.getHealthEntriesForDog(_currentDogProfile.id!);

    if (mounted) {
      setState(() {
        if (updatedDog != null) {
          _currentDogProfile = updatedDog;
        }
        _weightEntries = weights;
        _dogTrainingSessions = sessions;
        _dogWalkSessions = walks;
        _healthEntries = healthEntries;
        _isLoading = false;
      });

      // Przywróć pozycję przewijania po załadowaniu danych
      // Używamy Future.microtask, aby upewnić się, że widgety zostały już zbudowane
      // i kontroler ma dostęp do scrollable.
      if (_scrollController.hasClients && currentOffset > 0) {
        // Dodatkowy warunek, aby nie próbować przewijać, jeśli offset to 0 (góra)
        Future.microtask(() {
          if (_scrollController.hasClients) { // Ponowne sprawdzenie po microtask
             _scrollController.jumpTo(currentOffset.clamp(0.0, _scrollController.position.maxScrollExtent));
          }
        });
      }
    }
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

  Future<List<WalkSession>> _getWalkSessionsForDog(int dogId) async {
    List<WalkSession> allWalks = await WalkSessionHelper.loadWalkSessions();
    // Filtruj spacery, które zawierają ID bieżącego psa i posortuj je wg daty
    return allWalks.where((w) => w.dogIds.contains(dogId)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // --- Obliczenia dla celów fitness ---
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  double get _todayDistance {
    double trainingDistance = _dogTrainingSessions
        .where((s) => _isToday(s.timestamp))
        .fold(0.0, (prev, s) => prev + s.distance);
    double walkDistance = _dogWalkSessions
        .where((w) => _isToday(w.date))
        .fold(0.0, (prev, w) => prev + w.distance);
    return trainingDistance + walkDistance;
  }

  int get _todayDurationMinutes {
    int trainingDurationSec = _dogTrainingSessions
        .where((s) => _isToday(s.timestamp))
        .fold(0, (prev, s) => prev + s.duration);
    int walkDurationSec = _dogWalkSessions.where((w) => _isToday(w.date)).fold(0, (prev, w) => prev + w.duration.inSeconds);
    return ((trainingDurationSec + walkDurationSec) / 60).round();
  }

  double _calculateWalkCaloriesBurned(WalkSession session, DogProfile dogProfile) {
    final double? dogWeightKg = dogProfile.currentWeight;
    if (dogWeightKg == null || dogWeightKg <= 0) return 0.0;

    // Formuła oparta na MET (Metabolic Equivalent of Task)
    // MET dla spaceru z psem to ok. 3.0
    // Kalorie/min = (MET * waga_w_kg * 3.5) / 200
    const double met = 3.0;
    final double durationMinutes = session.duration.inSeconds / 60.0;

    if (durationMinutes <= 0) return 0.0;

    final double calories = (met * dogWeightKg * 3.5) / 200 * durationMinutes;

    return calories;
  }

  Future<void> _deleteTrainingSession(TrainingSession sessionToDelete) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: const Text('Czy na pewno chcesz usunąć ten trening?'),
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
      final prefs = await SharedPreferences.getInstance();
      final String? sessionsJson = prefs.getString('training_sessions');
      List<TrainingSession> allSessions = [];
      if (sessionsJson != null) {
        allSessions = TrainingSession.decode(sessionsJson);
      }
      
      // Usuń sesję na podstawie unikalnych właściwości
      allSessions.removeWhere((s) => s.timestamp == sessionToDelete.timestamp && s.name == sessionToDelete.name && s.dogId == sessionToDelete.dogId);
      
      await prefs.setString('training_sessions', TrainingSession.encode(allSessions));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trening usunięty.')),
        );
      }
      _loadDogData();
    }
  }

  Future<void> _deleteWalkSession(WalkSession sessionToDelete) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: const Text('Czy na pewno chcesz usunąć ten spacer?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Usuń')),
        ],
      ),
    );

    if (confirmed == true) {
      await WalkSessionHelper.deleteWalkSession(sessionToDelete.id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spacer usunięty.'))); }
      _loadDogData();
    }
  }

  Future<void> _editTrainingSession(TrainingSession sessionToEdit) async {
    final List<DogProfile> allDogs = _dogProfilesMap.values.toList();
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('training_sessions');
    List<TrainingSession> allSessions = [];
    if (sessionsJson != null) {
      allSessions = TrainingSession.decode(sessionsJson);
    }

    final updatedSession = await showDialog<TrainingSession>(
      context: context,
      builder: (context) => EditTrainingSessionDialog(
        session: sessionToEdit,
        allDogs: allDogs,
      ),
    );

    if (updatedSession != null && mounted) {
      // Znajdź i zaktualizuj sesję na liście głównej
      final masterIndex = allSessions.indexWhere((s) => s.id == updatedSession.id);
      if (masterIndex != -1) {
        allSessions[masterIndex] = updatedSession;
        await prefs.setString('training_sessions', TrainingSession.encode(allSessions));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trening zaktualizowany.')),
        );
        _loadDogData(); // Przeładuj dane dla tego psa
      }
    }
  }

  Future<void> _editWalkSession(WalkSession sessionToEdit) async {
    final List<DogProfile> allDogs = _dogProfilesMap.values.toList();
    final updatedSession = await showDialog<WalkSession>(
      context: context,
      builder: (context) => EditWalkSessionDialog(session: sessionToEdit, allDogs: allDogs),
    );

    if (updatedSession != null && mounted) {
      await WalkSessionHelper.saveWalkSession(updatedSession);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spacer zaktualizowany.')));
      _loadDogData(); // Przeładuj dane dla tego psa
    }
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

                if (mounted) {
                  Navigator.pop(context); // Zamknij dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Waga dodana!')),
                  );
                }

                _loadDogData(); // Zwykłe przeładowanie danych
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Proszę podać prawidłową wagę')),
                  );
                }
              }
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWeightEntry(int entryId) async {
    // Zapisz offset przed operacją, która przeładuje dane
    final double offset = _scrollController.hasClients ? _scrollController.offset : 0.0;

    await DatabaseHelper.instance.deleteWeightEntry(entryId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wpis wagi usunięty')),
      );
    }
    
    // Przekaż offset do _loadDogData, aby przywrócić pozycję
    _loadDogData(scrollOffset: offset); 
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

  LineChartData _buildWeightChartData() {
    // Sort entries by timestamp to ensure chronological order for the chart
    final sortedEntries = List<WeightEntry>.from(_weightEntries)
      ..sort((a, b) => DateTime.parse(a.timestamp).compareTo(DateTime.parse(b.timestamp)));

    if (sortedEntries.isEmpty) {
      return LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [],
      );
    }

    final List<FlSpot> spots = sortedEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weight);
    }).toList();

    double minWeight = sortedEntries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    double maxWeight = sortedEntries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    // Add some padding to min/max for better chart visibility
    minWeight = (minWeight - 1).floorToDouble().clamp(0.0, double.infinity);
    maxWeight = (maxWeight + 1).ceilToDouble();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.withOpacity(0.3),
            strokeWidth: 0.5,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Colors.grey.withOpacity(0.3),
            strokeWidth: 0.5,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value.toInt() < sortedEntries.length) {
                final date = DateTime.parse(sortedEntries[value.toInt()].timestamp);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('MM-dd').format(date),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
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
              return Text(
                '${value.toStringAsFixed(0)} kg',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              );
            },
            interval: (maxWeight - minWeight) / 4 > 1 ? ((maxWeight - minWeight) / 4).roundToDouble() : 1.0, // Dynamic interval
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d), width: 1),
      ),
      minX: 0,
      maxX: (sortedEntries.length - 1).toDouble(),
      minY: minWeight,
      maxY: maxWeight,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).primaryColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Theme.of(context).primaryColor,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: Theme.of(context).primaryColor.withOpacity(0.3),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => Colors.blueAccent,
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final flSpot = barSpot;
              final entry = sortedEntries[flSpot.x.toInt()];
              return LineTooltipItem(
                '${entry.weight.toStringAsFixed(1)} kg\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: DateFormat('yyyy-MM-dd').format(DateTime.parse(entry.timestamp)),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Helper method for detail rows
    Widget _buildDetailRow(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: '$label ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  children: <TextSpan>[
                    TextSpan(
                      text: value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentDogProfile.name),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController, // Przypisz kontroler
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
                          _buildDetailRow(Icons.vaccines, 'Ostatnie szczepienie (ogólne):', _currentDogProfile.lastVaccinationDate != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(_currentDogProfile.lastVaccinationDate!)) : 'Brak danych'),
                          _buildDetailRow(Icons.vaccines, 'Szczepienie na wściekliznę:', _currentDogProfile.rabiesVaccinationDate != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(_currentDogProfile.rabiesVaccinationDate!)) : 'Brak danych'),
                          _buildDetailRow(Icons.medication, 'Ostatnie odrobaczenie:', _currentDogProfile.lastDewormingDate != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(_currentDogProfile.lastDewormingDate!)) : 'Brak danych'),
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
                          if (_currentDogProfile.dailyDistanceGoal != null && _currentDogProfile.dailyDistanceGoal! > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 32.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LinearProgressIndicator(
                                    value: (_todayDistance / _currentDogProfile.dailyDistanceGoal!).clamp(0.0, 1.0),
                                    minHeight: 10,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Dziś: ${_formatDistance(_todayDistance)} z ${_formatDistance(_currentDogProfile.dailyDistanceGoal)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          _buildDetailRow(Icons.timer, 'Dzienny cel czasu aktywności:', _formatDurationMinutes(_currentDogProfile.dailyDurationGoal)),
                          if (_currentDogProfile.dailyDurationGoal != null && _currentDogProfile.dailyDurationGoal! > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, left: 32.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LinearProgressIndicator(
                                    value: (_todayDurationMinutes / _currentDogProfile.dailyDurationGoal!).clamp(0.0, 1.0),
                                    minHeight: 10,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Dziś: ${_formatDurationMinutes(_todayDurationMinutes)} z ${_formatDurationMinutes(_currentDogProfile.dailyDurationGoal)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
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
                                          '${DateFormat('yyyy-MM-dd').format(DateTime.parse(entry.entryDate))}: ${entry.title}',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      )).toList(),
                                ),
                        ],
                      ),
                    ),
                  ),

                  // Sekcja Historia Wagi
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
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.blue),
                                onPressed: _addWeightEntry,
                                tooltip: 'Dodaj nowy wpis wagi',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_weightEntries.length > 1)
                            SizedBox(
                              height: 200,
                              child: LineChart(_buildWeightChartData()),
                            )
                          else if (_weightEntries.isNotEmpty)
                            const Center(
                                child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Dodaj co najmniej dwa wpisy, aby zobaczyć wykres.'),
                            ))
                          else
                            const Center(
                                child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Brak wpisów wagi.'),
                            )),
                          const SizedBox(height: 16),
                          const Divider(),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _weightEntries.length,
                            itemBuilder: (context, index) {
                              final entry = _weightEntries[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${entry.weight.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(DateFormat('yyyy-MM-dd').format(DateTime.parse(entry.timestamp)), style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _deleteWeightEntry(entry.id!),
                                      tooltip: 'Usuń wpis',
                                    ),
                                  ],
                                ),
                              );
                            },
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
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: InkWell(
                                        onTap: () {
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
                                                child: TrainingSessionPreviewWidget(
                                                  session: session,
                                                  dogName: _currentDogProfile.name,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                    Text('Data: ${DateFormat('yyyy-MM-dd HH:mm').format(session.timestamp)}'),
                                                    Text('Dystans: ${(session.distance / 1000).toStringAsFixed(2)} km'),
                                                    Text('Maks. prędkość: ${session.maxSpeed.toStringAsFixed(1)} km/h'),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                                    tooltip: 'Edytuj trening',
                                                    onPressed: () => _editTrainingSession(session),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline,
                                                        color: Colors.redAccent),
                                                    tooltip: 'Usuń trening',
                                                    onPressed: () => _deleteTrainingSession(session),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),

                  // Sekcja Historia Spacerów
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
                            'Historia Spacerów',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _dogWalkSessions.isEmpty
                              ? const Center(child: Text('Brak spacerów dla tego psa.'))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _dogWalkSessions.length,
                                  itemBuilder: (context, index) {
                                    final session = _dogWalkSessions[index];
                                    final caloriesBurned = _calculateWalkCaloriesBurned(session, _currentDogProfile);
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: InkWell(
                                        onTap: () {
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
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                    Text('Data: ${DateFormat('yyyy-MM-dd HH:mm').format(session.date)}'),
                                                    Text('Dystans: ${(session.distance / 1000).toStringAsFixed(2)} km'),
                                                    Text('Czas trwania: ${session.duration.inMinutes} min ${session.duration.inSeconds.remainder(60)} sek'),
                                                    Text('Spalone kalorie (szacunkowo): ${caloriesBurned.toStringAsFixed(1)} kcal'),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                                    tooltip: 'Edytuj spacer',
                                                    onPressed: () => _editWalkSession(session),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline,
                                                        color: Colors.redAccent),
                                                    tooltip: 'Usuń spacer',
                                                    onPressed: () => _deleteWalkSession(session),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ], // To zamyka listę 'children' dla głównego Column
              ), // To zamyka widget Column
            ), // To zamyka widget SingleChildScrollView
          ); // To zamyka widget Scaffold
  } // To zamyka metodę build
} // To zamyka klasę _DogDetailsScreenState
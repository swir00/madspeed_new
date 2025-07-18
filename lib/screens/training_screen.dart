// lib/screens/training_screen.dart

import 'dart:async';
import 'dart:io'; // Dodano dla File() w CircleAvatar
import 'package:flutter/material.dart';
import 'package:madspeed_app/models/log_data_point.dart';
import 'package:madspeed_app/models/training_session.dart'; // Będziemy go modyfikować w następnym kroku
import 'package:madspeed_app/services/ble_service.dart';
import 'package:madspeed_app/widgets/custom_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:madspeed_app/widgets/status_indicators_widget.dart';
import 'package:madspeed_app/database/database_helper.dart'; // Import dla DatabaseHelper
import 'package:madspeed_app/models/dog_profile.dart'; // Import dla DogProfile

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  List<LogDataPoint> _loggedData = [];
  final TextEditingController _sessionNameController = TextEditingController();

  double _finalMaxSpeed = 0.0;
  double _finalDistance = 0.0;
  double _finalAverageSpeed = 0.0;
  Duration _finalDuration = Duration.zero;

  DogProfile? _selectedDog; // Nowa zmienna dla wybranego psa
  List<DogProfile> _dogProfiles = []; // Lista dostępnych profili psów

  @override
  void initState() {
    super.initState();
    // Ustaw tryb treningu przy wejściu na stronę
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BLEService>(context, listen: false).setTrainingMode();
      _loadDogProfiles(); // Załaduj profile psów przy inicjalizacji
    });
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  // Metoda do ładowania profili psów
  Future<void> _loadDogProfiles() async {
    final profiles = await DatabaseHelper.instance.getDogProfiles();
    setState(() {
      _dogProfiles = profiles;
      // Opcjonalnie: ustaw domyślnego psa, jeśli jest tylko jeden lub ostatnio używany
      // if (_dogProfiles.isNotEmpty) {
      //   // Możesz tutaj załadować ostatnio wybranego psa z SharedPreferences
      //   // lub ustawić pierwszego psa jako domyślnego
      //   // _selectedDog = _dogProfiles.first;
      // }
    });
  }

  // Metoda do wyboru psa
  Future<void> _selectDog() async {
    if (_dogProfiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak dodanych profili psów. Dodaj psa w sekcji "Profile Psów".')),
      );
      return;
    }

    final DogProfile? result = await showDialog<DogProfile>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wybierz psa do treningu'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _dogProfiles.length,
            itemBuilder: (context, index) {
              final dog = _dogProfiles[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: dog.photoPath != null && dog.photoPath!.isNotEmpty
                      ? Image.file(File(dog.photoPath!), fit: BoxFit.cover).image
                      : null,
                  child: dog.photoPath == null || dog.photoPath!.isEmpty
                      ? const Icon(Icons.pets, color: Colors.blueGrey)
                      : null,
                ),
                title: Text(dog.name),
                subtitle: dog.breed != null ? Text(dog.breed!) : null,
                onTap: () => Navigator.pop(context, dog),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null), // Pozwól na brak wyboru
            child: const Text('Anuluj / Bez psa'),
          ),
        ],
      ),
    );

    // Aktualizuj wybranego psa, jeśli coś zostało wybrane lub odznaczone
    if (result != null || (_selectedDog != null && result == null)) {
      setState(() {
        _selectedDog = result;
      }
      );
    }
  }

  void _startLogging(BLEService bleService) async { // Zmieniono na async
    // Wysyłamy twardy reset do urządzenia, aby upewnić się, że cała sesja logowania na urządzeniu zacznie się od zera.
    await bleService.sendControlCommand("RESET");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resetowanie urządzenia i danych...')),
      );
      // Daj urządzeniu czas na restart. To opóźnienie jest kluczowe!
      await Future.delayed(const Duration(seconds: 2)); // Zwiększone opóźnienie dla restartu
    }

    // Po twardym resecie urządzenia, wysyłamy komendę START_LOG
    bleService.sendControlCommand("START_LOG");
    setState(() {
      _loggedData.clear(); // Czyści wykres przed rozpoczęciem nowego treningu
      // Resetuj statystyki, aby nie pokazywały danych z poprzedniego treningu
      _finalMaxSpeed = 0.0;
      _finalDistance = 0.0;
      _finalAverageSpeed = 0.0;
      _finalDuration = Duration.zero; // Resetuj czas trwania
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logowanie treningu rozpoczęte!')),
    );
  }

  void _stopLogging(BLEService bleService) async {
    _showLoadingDialog(); // Pokaż dialog ładowania

    try {
      await bleService.sendControlCommand("STOP_LOG");

      // Po zatrzymaniu, odczytaj pełne dane logu z urządzenia
      _loggedData = await bleService.readLogData();

      _calculateFinalStats(_loggedData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logowanie treningu zakończone! Dane pobrane.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas pobierania logów: ${e.toString()}')),
        );
      }
      _loggedData.clear(); // Wyczyść dane, jeśli wystąpił błąd
      _calculateFinalStats([]); // Zresetuj statystyki
    } finally {
      _hideLoadingDialog(); // Ukryj dialog ładowania, niezależnie od wyniku
      setState(() {}); // Wymuś odświeżenie UI po zakończeniu operacji
      if (_loggedData.isNotEmpty) {
        _showSaveResultDialog(); // Pokaż dialog zapisu po pomyślnym pobraniu danych
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Użytkownik nie może zamknąć dialogu kliknięciem poza nim
      builder: (BuildContext context) {
        final bleService = Provider.of<BLEService>(context);
        return PopScope(
          canPop: false, // Blokuj zamykanie przyciskiem Wstecz
          child: AlertDialog(
            title: const Text('Pobieranie logów...'),
            content: ValueListenableBuilder<double>(
              valueListenable: bleService.logTransferProgress,
              builder: (context, progress, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress == 0.0 ? null : progress),
                    if (progress > 0.0 && progress <= 1.0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('${(progress * 100).toInt()}%'),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _calculateFinalStats(List<LogDataPoint> data) {
    if (data.isEmpty) {
      _finalMaxSpeed = 0.0;
      _finalDistance = 0.0;
      _finalAverageSpeed = 0.0;
      _finalDuration = Duration.zero;
      return;
    }

    double maxSpd = 0.0;
    double totalSpd = 0.0;
    int speedPoints = 0;

    double totalDist = data.isNotEmpty ? data.last.distance : 0.0;

    for (var point in data) {
      if (point.speed > 0.1) {
        if (point.speed > maxSpd) {
          maxSpd = point.speed;
        }
        totalSpd += point.speed;
        speedPoints++;
      }
    }

    Duration duration = Duration.zero;
    if (data.length > 1) {
      final double startTime = data.first.timestamp.toDouble();
      final double endTime = data.last.timestamp.toDouble();
      duration = Duration(seconds: (endTime - startTime).round());
    }

    setState(() {
      _finalMaxSpeed = maxSpd;
      _finalDistance = totalDist;
      _finalAverageSpeed = speedPoints > 0 ? totalSpd / speedPoints : 0.0;
      _finalDuration = duration;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    final String hours = twoDigits(duration.inHours);
    if (duration.inHours > 0) {
      return '$hours godz. $minutes min. $seconds sek.';
    } else if (duration.inMinutes > 0) {
      return '$minutes min. $seconds sek.';
    } else {
      return '$seconds sek.';
    }
  }

  void _showSaveResultDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Zapisz wynik treningu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Maks. prędkość: ${_finalMaxSpeed.toStringAsFixed(2)} km/h'),
              _buildDynamicDistanceText(_finalDistance),
              Text('Średnia prędkość: ${_finalAverageSpeed.toStringAsFixed(2)} km/h'),
              Text('Czas trwania: ${_formatDuration(_finalDuration)}'),
              if (_selectedDog != null) // Wyświetl wybranego psa w dialogu
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Dla psa: ${_selectedDog!.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 15),
              TextField(
                controller: _sessionNameController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa sesji treningowej',
                  hintText: 'Np. Trening poranny',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _sessionNameController.clear();
              },
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveTrainingSession();
                Navigator.of(context).pop();
              },
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTrainingSession() async {
    if (_sessionNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nazwa sesji nie może być pusta.')),
      );
      return;
    }

    final newSession = TrainingSession(
      id: const Uuid().v4(),
      name: _sessionNameController.text,
      maxSpeed: _finalMaxSpeed,
      distance: _finalDistance,
      averageSpeed: _finalAverageSpeed,
      timestamp: DateTime.now(),
      duration: _finalDuration.inSeconds,
      logData: _loggedData,
      dogId: _selectedDog?.id, // ZAPISZ ID WYBRANEGO PSA
    );

    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('training_sessions');
    List<TrainingSession> sessions = [];
    if (sessionsJson != null) {
      sessions = TrainingSession.decode(sessionsJson);
    }
    sessions.add(newSession);
    sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    await prefs.setString('training_sessions', TrainingSession.encode(sessions));
    _sessionNameController.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesja treningowa zapisana pomyślnie!')),
      );
    }
  }

  void _resetDeviceData() {
    final bleService = Provider.of<BLEService>(context, listen: false);
    bleService.sendControlCommand("RESET");
    setState(() {
      _finalMaxSpeed = 0.0;
      _finalDistance = 0.0;
      _finalAverageSpeed = 0.0;
      _finalDuration = Duration.zero;
      _loggedData.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dane na urządzeniu zresetowane.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BLEService>(context);
    final data = bleService.currentGpsData;
    bool isLoggingActiveFromDevice = data.isLoggingActive ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trening'),
        actions: [
          const StatusIndicatorsWidget(),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
            tooltip: 'Historia zapisanych treningów',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
              margin: const EdgeInsets.only(bottom: 16.0),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16.0),
                title: Text(
                  _selectedDog == null ? 'Wybierz psa do treningu' : 'Wybrany pies: ${_selectedDog!.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: _selectedDog?.breed != null && _selectedDog!.breed!.isNotEmpty
                    ? Text('Rasa: ${_selectedDog!.breed!}')
                    : null,
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  backgroundImage: _selectedDog?.photoPath != null && _selectedDog!.photoPath!.isNotEmpty
                      ? Image.file(File(_selectedDog!.photoPath!), fit: BoxFit.cover).image
                      : null,
                  child: _selectedDog?.photoPath == null || _selectedDog!.photoPath!.isEmpty
                      ? Icon(Icons.pets, size: 30, color: Theme.of(context).primaryColor)
                      : null,
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectDog,
              ),
            ),

            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Aktualny pomiar', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),

                    _buildMeasurementRow(
                      'Maks. prędkość:',
                      '${data.maxSpeed?.toStringAsFixed(2) ?? 'N/A'}',
                      'km/h',
                    ),
                    _buildDynamicDistanceRow('Dystans:', data.distance),
                    _buildMeasurementRow(
                      'Średnia prędkość:',
                      '${data.avgSpeed?.toStringAsFixed(2) ?? 'N/A'}',
                      'km/h',
                    ),
                    _buildMeasurementRow(
                      'Logowanie aktywne:',
                      isLoggingActiveFromDevice ? 'Tak' : 'Nie',
                      '',
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: bleService.connectedDevice != null && !isLoggingActiveFromDevice
                                ? () => _startLogging(bleService)
                                : null,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: bleService.connectedDevice != null && isLoggingActiveFromDevice
                                ? () => _stopLogging(bleService)
                                : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Wyniki zakończonego treningu', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMeasurementRow('Maks. prędkość:', '${_finalMaxSpeed.toStringAsFixed(2)}', 'km/h'),
                    _buildDynamicDistanceRow('Całkowity dystans:', _finalDistance),
                    _buildMeasurementRow('Średnia prędkość:', '${_finalAverageSpeed.toStringAsFixed(2)}', 'km/h'),
                    _buildMeasurementRow('Czas trwania:', _formatDuration(_finalDuration), ''),
                    const SizedBox(height: 20),
                    if (_loggedData.isNotEmpty)
                      SizedBox(
                        height: 250,
                        child: CustomChart(logData: _loggedData),
                      )
                    else
                      const Center(
                        child: Text(
                          'Brak danych do wyświetlenia wykresu. Rozpocznij i zakończ logowanie treningu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: bleService.connectedDevice != null && !isLoggingActiveFromDevice && _loggedData.isNotEmpty
                                ? _showSaveResultDialog
                                : null,
                            icon: const Icon(Icons.save),
                            label: const Text('Zapisz'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: bleService.connectedDevice != null && !isLoggingActiveFromDevice
                                ? _resetDeviceData
                                : null,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Reset'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildMeasurementRow(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              '$value $unit',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicDistanceRow(String label, double? distanceMeters) {
    String valueText;
    String unitText;

    if (distanceMeters == null) {
      valueText = 'N/A';
      unitText = '';
    } else if (distanceMeters < 1000) {
      valueText = distanceMeters.toStringAsFixed(0);
      unitText = 'm';
    } else {
      valueText = (distanceMeters / 1000.0).toStringAsFixed(3);
      unitText = 'km';
    }

    return _buildMeasurementRow(label, valueText, unitText);
  }

  Widget _buildDynamicDistanceText(double distanceMeters) {
    String valueText;
    String unitText;

    if (distanceMeters < 1000) {
      valueText = distanceMeters.toStringAsFixed(0);
      unitText = 'm';
    } else {
      valueText = (distanceMeters / 1000.0).toStringAsFixed(3);
      unitText = 'km';
    }
    return Text('Dystans: $valueText $unitText');
  }
}
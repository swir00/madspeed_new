import 'package:flutter/material.dart';
import 'package:madspeed_app/models/log_data_point.dart';
import 'package:madspeed_app/models/training_session.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:madspeed_app/widgets/custom_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:madspeed_app/widgets/status_indicators_widget.dart';

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
  Duration _finalDuration = Duration.zero; // Dodana zmienna do przechowywania czasu trwania

  @override
  void initState() {
    super.initState();
    // Ustaw tryb treningu przy wejściu na stronę
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BLEService>(context, listen: false).setTrainingMode();
    });
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  void _startLogging(BLEService bleService) {
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
      // debugPrint("Received ${_loggedData.length} log points."); // Wyłączono debugowanie

      _calculateFinalStats(_loggedData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logowanie treningu zakończone! Dane pobrane.')),
        );
      }
    } catch (e) {
      // debugPrint("Error stopping logging or reading log data: $e"); // Wyłączono debugowanie
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
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Użytkownik nie może zamknąć dialogu kliknięciem poza nim
      builder: (BuildContext context) {
        final bleService = Provider.of<BLEService>(context);
        return PopScope( // Użyj PopScope zamiast WillPopScope
          canPop: false, // Blokuj zamykanie przyciskiem Wstecz
          child: AlertDialog(
            title: const Text('Pobieranie logów...'),
            content: ValueListenableBuilder<double>(
              valueListenable: bleService.logTransferProgress,
              builder: (context, progress, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress == 0.0 ? null : progress), // Nieskończony, jeśli 0
                    if (progress > 0.0 && progress <= 1.0) // Pokaż procent tylko jeśli jest sensowny
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
    // Sprawdź, czy dialog jest nadal na stosie nawigacji, zanim spróbujesz go zamknąć
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _calculateFinalStats(List<LogDataPoint> data) {
    // debugPrint("Starting _calculateFinalStats with ${data.length} points."); // Wyłączono debugowanie
    if (data.isEmpty) {
      // debugPrint("Data is empty, setting stats to 0."); // Wyłączono debugowanie
      _finalMaxSpeed = 0.0;
      _finalDistance = 0.0;
      _finalAverageSpeed = 0.0;
      _finalDuration = Duration.zero; // Resetuj czas trwania
      return;
    }

    double maxSpd = 0.0;
    double totalSpd = 0.0;
    int speedPoints = 0;

    // Użyj ostatniej wartości dystansu z logu jako całkowity dystans
    // Upewnij się, że 'distance' w LogDataPoint jest w metrach, a ESP32 wysyłało je jako 'distance_m'
    // Flutter konwertuje na km później
    double totalDist = data.isNotEmpty ? data.last.distance : 0.0;
    // debugPrint("Initial totalDist from last point: $totalDist meters"); // Wyłączono debugowanie


    for (var point in data) {
      // debugPrint("Processing point: timestamp=${point.timestamp}, speed=${point.speed}, distance=${point.distance}"); // Wyłączono debugowanie
      // Obliczaj maks. prędkość tylko dla punktów z rzeczywistą prędkością (powyżej 0.1, aby ignorować dryf GPS)
      if (point.speed > 0.1) {
        if (point.speed > maxSpd) {
          maxSpd = point.speed;
          // debugPrint("New max speed found: $maxSpd km/h"); // Wyłączono debugowanie
        }
        totalSpd += point.speed;
        speedPoints++;
      } else {
        // debugPrint("Speed ${point.speed} <= 0.1, skipping for avg/max calculation."); // Wyłączono debugowanie
      }
    }

    // Obliczanie czasu trwania
    Duration duration = Duration.zero;
    if (data.length > 1) {
      final double startTime = data.first.timestamp.toDouble(); // Rzutowanie na double
      final double endTime = data.last.timestamp.toDouble();   // Rzutowanie na double
      duration = Duration(seconds: (endTime - startTime).round());
    }

    setState(() {
      _finalMaxSpeed = maxSpd;
      _finalDistance = totalDist; // Zostaw w metrach do formatowania w _buildMeasurementRow
      _finalAverageSpeed = speedPoints > 0 ? totalSpd / speedPoints : 0.0;
      _finalDuration = duration; // Ustaw obliczony czas trwania
      // debugPrint("Calculated Final Stats: Max Speed: $_finalMaxSpeed km/h, Distance: $_finalDistance km, Avg Speed: $_finalAverageSpeed km/h, Duration: $_finalDuration"); // Wyłączono debugowanie
    });
  }

  // Funkcja formatująca czas trwania
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
              // Użyj _buildDynamicDistanceText do formatowania dystansu
              _buildDynamicDistanceText(_finalDistance),
              Text('Średnia prędkość: ${_finalAverageSpeed.toStringAsFixed(2)} km/h'),
              Text('Czas trwania: ${_formatDuration(_finalDuration)}'), // Wyświetl czas trwania
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
      // Zapisz dystans w metrach, tak jak jest obliczany i pobierany
      distance: _finalDistance,
      averageSpeed: _finalAverageSpeed,
      timestamp: DateTime.now(),
      duration: _finalDuration.inSeconds, // Zapisz czas trwania w sekundach
      logData: _loggedData, // Zapisz rzeczywiste zalogowane punkty
    );

    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('training_sessions');
    List<TrainingSession> sessions = [];
    if (sessionsJson != null) {
      sessions = TrainingSession.decode(sessionsJson);
    }
    sessions.add(newSession);
    sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sortuj od najnowszych

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
      _finalDuration = Duration.zero; // Resetuj czas trwania
      _loggedData.clear(); // Wyczyść dane lokalnie
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dane na urządzeniu zresetowane.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BLEService>(context);
    final data = bleService.currentGpsData;
    bool isLoggingActiveFromDevice = data.isLoggingActive ?? false; // Bezpieczeństwo null

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trening'),
        actions: [
          const StatusIndicatorsWidget(), // Dodano pasek statusu
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
                    // Użyj nowej funkcji do wyświetlania dynamicznego dystansu dla danych bieżących
                    _buildDynamicDistanceRow('Dystans:', data.distance),
                    _buildMeasurementRow(
                      'Średnia prędkość:',
                      '${data.avgSpeed?.toStringAsFixed(2) ?? 'N/A'}',
                      'km/h',
                    ),
                    _buildMeasurementRow(
                      'Logowanie aktywne:',
                      isLoggingActiveFromDevice ? 'Tak' : 'Nie',
                      '', // Brak jednostki
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
                    // Użyj nowej funkcji do wyświetlania dynamicznego dystansu dla wyników końcowych
                    _buildDynamicDistanceRow('Całkowity dystans:', _finalDistance),
                    _buildMeasurementRow('Średnia prędkość:', '${_finalAverageSpeed.toStringAsFixed(2)}', 'km/h'),
                    _buildMeasurementRow('Czas trwania:', _formatDuration(_finalDuration), ''), // Wyświetl czas trwania
                    const SizedBox(height: 20), // Nowy odstęp
                    if (_loggedData.isNotEmpty)
                      SizedBox(
                        height: 250, // Wysokość wykresu
                        child: CustomChart(logData: _loggedData), // Przekazujemy _loggedData do CustomChart
                      )
                    else
                      const Center(
                        child: Text(
                          'Brak danych do wyświetlenia wykresu. Rozpocznij i zakończ logowanie treningu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 20), // Dodano odstęp przed nowymi przyciskami
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
                            icon: const Icon(Icons.delete_forever), // Zmieniona ikona dla resetu danych
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

  // NOWA FUNKCJA do dynamicznego formatowania dystansu
  Widget _buildDynamicDistanceRow(String label, double? distanceMeters) {
    String valueText;
    String unitText;

    if (distanceMeters == null) {
      valueText = 'N/A';
      unitText = '';
    } else if (distanceMeters < 1000) { // Jeśli mniej niż 1 km
      valueText = distanceMeters.toStringAsFixed(0); // Zaokrągl do całości metrów
      unitText = 'm';
    } else { // 1 km lub więcej
      valueText = (distanceMeters / 1000.0).toStringAsFixed(3); // Konwertuj na km
      unitText = 'km';
    }

    return _buildMeasurementRow(label, valueText, unitText);
  }

  // NOWA FUNKCJA do dynamicznego formatowania dystansu w dialogu zapisu
  Widget _buildDynamicDistanceText(double distanceMeters) {
    String valueText;
    String unitText;

    if (distanceMeters < 1000) { // Jeśli mniej niż 1 km
      valueText = distanceMeters.toStringAsFixed(0); // Zaokrągl do całości metrów
      unitText = 'm';
    } else { // 1 km lub więcej
      valueText = (distanceMeters / 1000.0).toStringAsFixed(3); // Konwertuj na km
      unitText = 'km';
    }
    return Text('Dystans: $valueText $unitText');
  }
}

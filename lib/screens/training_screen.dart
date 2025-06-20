import 'package:flutter/material.dart';
import 'package:madspeed_app/models/log_data_point.dart';
import 'package:madspeed_app/models/training_session.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:madspeed_app/widgets/custom_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:madspeed_app/widgets/status_indicators_widget.dart'; // <--- DODANO TEN IMPORT

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
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logowanie treningu rozpoczęte!')),
    );
  }

  void _stopLogging(BLEService bleService) async {
    await bleService.sendControlCommand("STOP_LOG");

    // Po zatrzymaniu, odczytaj pełne dane logu z urządzenia
    _loggedData = await bleService.readLogData();
    debugPrint("Received ${_loggedData.length} log points.");

    // Przelicz statystyki z otrzymanych _loggedData
    _calculateFinalStats(_loggedData);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logowanie treningu zakończone! Dane pobrane.')),
      );
      // Nie pokazujemy automatycznie okna zapisu, użytkownik użyje przycisku "Zapisz Trening"
    }
  }

  void _calculateFinalStats(List<LogDataPoint> data) {
    if (data.isEmpty) {
      _finalMaxSpeed = 0.0;
      _finalDistance = 0.0;
      _finalAverageSpeed = 0.0;
      return;
    }

    double maxSpd = 0.0;
    double totalSpd = 0.0;
    int speedPoints = 0;
    double totalDist = data.last.distance; // Całkowity dystans z ostatniego punktu

    for (var point in data) {
      if (point.speed > maxSpd) {
        maxSpd = point.speed;
      }
      totalSpd += point.speed;
      speedPoints++;
    }

    setState(() {
      _finalMaxSpeed = maxSpd;
      _finalDistance = totalDist / 1000.0; // Konwertuj metry na km
      _finalAverageSpeed = speedPoints > 0 ? totalSpd / speedPoints : 0.0;
    });
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
              Text('Dystans: ${_finalDistance.toStringAsFixed(3)} km'),
              Text('Średnia prędkość: ${_finalAverageSpeed.toStringAsFixed(2)} km/h'),
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
          // Ikony statusu (bateria, GPS) w AppBar
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Aktualny pomiar', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    _buildMeasurementRow(
                      'Prędkość:',
                      '${data.currentSpeed?.toStringAsFixed(2) ?? 'N/A'}',
                      'km/h',
                    ),
                    _buildMeasurementRow(
                      'Maks. prędkość:',
                      '${data.maxSpeed?.toStringAsFixed(2) ?? 'N/A'}',
                      'km/h',
                    ),
                    _buildMeasurementRow(
                      'Dystans:',
                      '${data.distance?.toStringAsFixed(3) ?? 'N/A'}',
                      'km',
                    ),
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
                    _buildMeasurementRow(
                      'Bateria:',
                      '${data.battery?.toStringAsFixed(2) ?? 'N/A'}',
                      'V', // Jednostka V
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
                            label: const Text('Start Logowanie'),
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
                            label: const Text('Stop Logowanie'),
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
                    _buildMeasurementRow('Maks. prędkość (zalogowana):', '${_finalMaxSpeed.toStringAsFixed(2)}', 'km/h'),
                    _buildMeasurementRow('Całkowity dystans (zalogowany):', '${_finalDistance.toStringAsFixed(3)}', 'km'),
                    _buildMeasurementRow('Średnia prędkość (zalogowana):', '${_finalAverageSpeed.toStringAsFixed(2)}', 'km/h'),
                    const SizedBox(height: 20),
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
                            label: const Text('Zapisz Trening'),
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
                            label: const Text('Reset Logów'),
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
}

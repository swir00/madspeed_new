import 'package:flutter/material.dart';
import 'package:madspeed_app/models/gps_data.dart'; // Upewnij się, że ten import jest poprawny
import 'package:madspeed_app/models/speed_master_session.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:madspeed_app/widgets/status_indicators_widget.dart'; // Dodano import

class SpeedMasterScreen extends StatefulWidget {
  const SpeedMasterScreen({super.key});

  @override
  State<SpeedMasterScreen> createState() => _SpeedMasterScreenState();
}

class _SpeedMasterScreenState extends State<SpeedMasterScreen> {
  final List<SpeedMasterSession> _savedSessions = [];
  final TextEditingController _sessionNameController = TextEditingController();

  double _finalMaxSpeed = 0.0;
  double _finalDistance = 0.0;
  double _finalAverageSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BLEService>(context, listen: false).setSpeedMasterMode();
    });
    _loadSavedSessions();
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('speed_master_sessions');
    if (sessionsJson != null) {
      setState(() {
        _savedSessions.addAll(SpeedMasterSession.decode(sessionsJson));
        _savedSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
    }
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String sessionsJson = SpeedMasterSession.encode(_savedSessions);
    await prefs.setString('speed_master_sessions', sessionsJson);
  }

  void _startMeasurement(BLEService bleService) {
    bleService.sendControlCommand("START_LOG");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pomiar Speed Master rozpoczęty!')),
    );
  }

  void _stopMeasurement(BLEService bleService) async {
    await bleService.sendControlCommand("STOP_LOG");

    // Zbieranie finalnych danych z aktualnego stanu GPS
    setState(() {
      _finalMaxSpeed = bleService.currentGpsData.maxSpeed ?? 0.0;
      _finalDistance = bleService.currentGpsData.distance ?? 0.0; // Dystans w metrach
      _finalAverageSpeed = bleService.currentGpsData.avgSpeed ?? 0.0;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pomiar Speed Master zakończony!')),
      );
      _showSaveResultDialog();
    }
  }

  void _showSaveResultDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Zapisz wynik Speed Master'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Maks. prędkość: ${_finalMaxSpeed.toStringAsFixed(2)} km/h'),
              Text('Dystans: ${_formatDistance(_finalDistance)}'), // Użyj _formatDistance
              Text('Średnia prędkość: ${_finalAverageSpeed.toStringAsFixed(2)} km/h'),
              const SizedBox(height: 15),
              TextField(
                controller: _sessionNameController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa sesji',
                  hintText: 'Np. Poranny przejazd',
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
                _saveSpeedMasterSession();
                Navigator.of(context).pop();
              },
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );
  }

  void _saveSpeedMasterSession() {
    if (_sessionNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nazwa sesji nie może być pusta.')),
      );
      return;
    }

    final newSession = SpeedMasterSession(
      id: const Uuid().v4(),
      name: _sessionNameController.text,
      maxSpeed: _finalMaxSpeed,
      distance: _finalDistance, // Dystans jest w metrach
      averageSpeed: _finalAverageSpeed, // Średnia prędkość jest już w km/h
      timestamp: DateTime.now(),
    );

    setState(() {
      _savedSessions.add(newSession);
      _savedSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
    _saveSessions();
    _sessionNameController.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wynik zapisany pomyślnie!')),
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
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dane na urządzeniu zresetowane.')),
    );
  }

  // Funkcja do dynamicznego formatowania dystansu (skopiowana z TrainingScreen dla spójności)
  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return 'N/A';
    
    String valueText;
    String unitText;

    if (distanceMeters < 1000) { // Jeśli mniej niż 1 km
      valueText = distanceMeters.toStringAsFixed(0); // Zaokrągl do całości metrów
      unitText = 'm';
    } else { // 1 km lub więcej
      valueText = (distanceMeters / 1000.0).toStringAsFixed(3); // Konwertuj na km
      unitText = 'km';
    }
    return '$valueText $unitText';
  }


  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BLEService>(context);
    final data = bleService.currentGpsData;
    bool isLoggingActiveFromDevice = data.isLoggingActive ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speed Master'),
        actions: [
          const StatusIndicatorsWidget(),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Wyczyść wszystkie zapisane wyniki?'),
                  content: const Text('Czy na pewno chcesz usunąć wszystkie zapisane sesje Speed Master?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
                    ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Potwierdź')),
                  ],
                ),
              );
              if (!context.mounted) return; // Zabezpieczenie kontekstu
              if (confirm == true) {
                setState(() {
                  _savedSessions.clear();
                });
                _saveSessions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wszystkie wyniki Speed Master usunięte.')),
                  );
                }
              }
            },
            tooltip: 'Wyczyść wszystkie zapisane wyniki',
          ),
        
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Consumer<BLEService>(
                    builder: (context, bleService, child) {
                      final data = bleService.currentGpsData;
                      // bool isLoggingActiveFromDevice = data.isLoggingActive ?? false; // Używamy bezpośrednio data.isLoggingActive
                      
                      return Column(
                        children: [
                          Text('Aktualny pomiar', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 10),
                          _buildMeasurementRow(
                            'Maks. prędkość:',
                            '${data.maxSpeed?.toStringAsFixed(2) ?? 'N/A'}',
                            'km/h',
                          ),
                          _buildMeasurementRow(
                            'Dystans:',
                            _formatDistance(data.distance), // Użyj _formatDistance
                            '', // Jednostka jest już w _formatDistance
                          ),
                          _buildMeasurementRow(
                            'Średnia prędkość:',
                            '${data.avgSpeed?.toStringAsFixed(2) ?? 'N/A'}',
                            'km/h',
                          ),
                          _buildMeasurementRow(
                            'Logowanie aktywne:',
                            (data.isLoggingActive ?? false) ? 'Tak' : 'Nie', // Sprawdź isLoggingActive
                            '',
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: bleService.connectedDevice != null && !(data.isLoggingActive ?? false)
                                      ? () => _startMeasurement(bleService)
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
                                  onPressed: bleService.connectedDevice != null && (data.isLoggingActive ?? false)
                                      ? () => _stopMeasurement(bleService)
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
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Zapisane wyniki', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              _savedSessions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'Brak zapisanych wyników Speed Master.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SingleChildScrollView( // NOWOŚĆ: Przewijanie poziome dla tabeli
                      scrollDirection: Axis.horizontal,
                      child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                          child: Column(
                            children: [
                              Table(
                                defaultColumnWidth: const IntrinsicColumnWidth(), // Utrzymujemy Intrinsic, aby kolumny dopasowały się do treści
                                border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(15)),
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                    ),
                                    children: [
                                      _buildTableHeader('Nazwa'),
                                      _buildTableHeader('Data'),
                                      _buildTableHeader('Max Prędkość'),
                                      _buildTableHeader('Dystans'),
                                      _buildTableHeader('Średnia Prędkość'),
                                      _buildTableHeader('Usuń'),
                                    ],
                                  ),
                                  ..._savedSessions.map((session) {
                                    return TableRow(
                                      children: [
                                        _buildTableCell(session.name),
                                        _buildTableCell('${session.timestamp.toLocal().day}.${session.timestamp.toLocal().month}.${session.timestamp.toLocal().year}'),
                                        _buildTableCell('${session.maxSpeed.toStringAsFixed(2)} km/h'),
                                        _buildTableCell(_formatDistance(session.distance)), // Użyj _formatDistance
                                        _buildTableCell('${session.averageSpeed.toStringAsFixed(2)} km/h'),
                                        TableCell(
                                          child: IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteSession(session.id),
                                            tooltip: 'Usuń sesję',
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Dodaj tutaj przycisk do resetowania danych na urządzeniu, jeśli potrzebujesz go w tej sekcji
                              // Przykład:
                              // ElevatedButton.icon(
                              //   onPressed: bleService.connectedDevice != null ? _resetDeviceData : null,
                              //   icon: const Icon(Icons.refresh),
                              //   label: const Text('Resetuj dane urządzenia'),
                              //   style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              // ),
                            ],
                          ),
                        ),
                    ),
            ],
          ),
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

  static Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  static Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
    );
  }

  void _deleteSession(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: const Text('Czy na pewno chcesz usunąć tę sesję?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Potwierdź')),
        ],
      ),
    );
    if (!context.mounted) return; // Zabezpieczenie kontekstu
    if (confirm == true) {
      setState(() {
        _savedSessions.removeWhere((session) => session.id == id);
      });
      _saveSessions();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesja usunięta.')),
        );
      }
    }
  }
}

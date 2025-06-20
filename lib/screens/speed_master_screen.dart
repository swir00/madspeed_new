import 'package:flutter/material.dart';
import 'package:madspeed_app/models/speed_master_session.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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

    _finalMaxSpeed = bleService.currentGpsData.maxSpeed ?? 0.0;
    _finalDistance = bleService.currentGpsData.distance ?? 0.0;
    _finalAverageSpeed = bleService.currentGpsData.avgSpeed ?? 0.0;

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
              Text('Dystans: ${_finalDistance.toStringAsFixed(3)} km'),
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
      id: Uuid().v4(),
      name: _sessionNameController.text,
      maxSpeed: _finalMaxSpeed,
      distance: _finalDistance,
      averageSpeed: _finalAverageSpeed,
      timestamp: DateTime.now(),
    );

    setState(() {
      _savedSessions.add(newSession);
      _savedSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
    _saveSessions();
    _sessionNameController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wynik zapisany pomyślnie!')),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speed Master'),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetDeviceData,
            tooltip: 'Zresetuj dane na urządzeniu',
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
                      bool isLoggingActiveFromDevice = data.isLoggingActive ?? false;
                      double batteryPercentage = bleService.batteryPercentage; // Pobierz procent baterii

                      return Column(
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
                            '',
                          ),
                          // Nowy wskaźnik baterii
                          _buildBatteryIndicator(data.battery, batteryPercentage),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isLoggingActiveFromDevice ? null : () => _startMeasurement(bleService),
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
                                  onPressed: isLoggingActiveFromDevice ? () => _stopMeasurement(bleService) : null,
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
                  : Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                      child: Column(
                        children: [
                          Table(
                            defaultColumnWidth: const IntrinsicColumnWidth(),
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
                                    _buildTableCell('${session.distance.toStringAsFixed(3)} km'),
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
                        ],
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

  // Nowa funkcja do budowania wskaźnika baterii
  Widget _buildBatteryIndicator(double? batteryVoltage, double batteryPercentage) {
    if (batteryVoltage == null) {
      return _buildMeasurementRow('Bateria:', 'N/A', '');
    }

    IconData batteryIcon;
    Color iconColor;

    if (batteryPercentage >= 90) {
      batteryIcon = Icons.battery_full;
      iconColor = Colors.green;
    } else if (batteryPercentage >= 75) {
      batteryIcon = Icons.battery_full; // battery_6_bar for > 75%
      iconColor = Colors.green;
    } else if (batteryPercentage >= 60) {
      batteryIcon = Icons.battery_5_bar; // battery_5_bar for > 60%
      iconColor = Colors.green;
    } else if (batteryPercentage >= 45) {
      batteryIcon = Icons.battery_4_bar; // battery_4_bar for > 45%
      iconColor = Colors.lightGreen;
    } else if (batteryPercentage >= 30) {
      batteryIcon = Icons.battery_3_bar; // battery_3_bar for > 30%
      iconColor = Colors.orange;
    } else if (batteryPercentage >= 15) {
      batteryIcon = Icons.battery_2_bar; // battery_2_bar for > 15%
      iconColor = Colors.deepOrange;
    } else if (batteryPercentage >= 5) {
      batteryIcon = Icons.battery_1_bar; // battery_1_bar for > 5%
      iconColor = Colors.red;
    } else {
      batteryIcon = Icons.battery_0_bar; // battery_0_bar for <= 5%
      iconColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Bateria:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end, // Wyrównaj ikonę i tekst do prawej
              children: [
                Icon(batteryIcon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  '${batteryPercentage.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
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
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Usuń')),
        ],
      ),
    );
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

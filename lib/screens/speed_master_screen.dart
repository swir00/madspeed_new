import 'dart:io';
import 'dart:convert'; // Dodano import dla kodowania UTF-8

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:madspeed_app/models/gps_data.dart'; // Upewnij się, że ten import jest poprawny
import 'package:madspeed_app/models/speed_master_session.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:madspeed_app/widgets/status_indicators_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

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

  // Zmienne do sortowania tabeli
  int? _sortColumnIndex;
  bool _isAscending = true;

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

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _isAscending = ascending;
      _savedSessions.sort((a, b) {
        int compare;
        switch (columnIndex) {
          case 0: // Nazwa
            compare = a.name.compareTo(b.name);
            break;
          case 1: // Data
            compare = a.timestamp.compareTo(b.timestamp);
            break;
          case 2: // Max Prędkość
            compare = a.maxSpeed.compareTo(b.maxSpeed);
            break;
          case 3: // Dystans
            compare = a.distance.compareTo(b.distance);
            break;
          case 4: // Średnia Prędkość
            compare = a.averageSpeed.compareTo(b.averageSpeed);
            break;
          default:
            return 0;
        }
        return ascending ? compare : -compare;
      });
    });
  }

  Future<void> _exportToCsv() async {
    if (_savedSessions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak danych do wyeksportowania.')),
        );
      }
      return;
    }

    List<List<dynamic>> rows = [];
    // Dodaj nagłówki
    rows.add([
      "Nazwa", "Data", "Godzina", "Maks. prędkość (km/h)", "Dystans (m)", "Średnia prędkość (km/h)"
    ]);

    // Dodaj dane sesji
    for (var session in _savedSessions) {
      rows.add([
        session.name,
        DateFormat('yyyy-MM-dd').format(session.timestamp.toLocal()),
        DateFormat('HH:mm:ss').format(session.timestamp.toLocal()),
        session.maxSpeed.toStringAsFixed(2),
        session.distance.toStringAsFixed(2),
        session.averageSpeed.toStringAsFixed(2)
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/speed_master_export_${DateTime.now().millisecondsSinceEpoch}.csv";
    final File file = File(path);
    await file.writeAsString(csv, encoding: utf8); // Użyj kodowania UTF-8

    await Share.shareXFiles([XFile(path)], text: 'Eksport wyników Speed Master');
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: bleService.connectedDevice != null && !(data.isLoggingActive ?? false)
                                          ? () => _startMeasurement(bleService)
                                          : null,
                                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                                      label: const Text('Start', style: TextStyle(fontSize: 18)),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: bleService.connectedDevice != null && (data.isLoggingActive ?? false)
                                          ? () => _stopMeasurement(bleService)
                                          : null,
                                      icon: const Icon(Icons.stop_rounded, size: 28),
                                      label: const Text('Stop', style: TextStyle(fontSize: 18)),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                ],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Zapisane wyniki',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: 'Eksportuj wyniki do CSV',
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: const Text('Eksport'),
                          onPressed: _savedSessions.isNotEmpty ? _exportToCsv : null,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Wyczyść wszystkie zapisane wyniki',
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.delete_forever, size: 18),
                          label: const Text('Wyczyść'),
                          onPressed: _savedSessions.isNotEmpty
                              ? () async {
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
                                  if (confirm == true && context.mounted) {
                                    setState(() => _savedSessions.clear());
                                    await _saveSessions();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Wszystkie wyniki Speed Master usunięte.')),
                                    );
                                  }
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                  : SingleChildScrollView(
                      // NOWOŚĆ: Przewijanie poziome dla tabeli
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                          child: DataTable(
                            sortColumnIndex: _sortColumnIndex,
                            sortAscending: _isAscending,
                            columns: [
                              DataColumn(label: const Text('Nazwa'), onSort: _onSort),
                              DataColumn(label: const Text('Data'), onSort: _onSort, numeric: true),
                              DataColumn(label: const Text('Max Prędkość'), onSort: _onSort, numeric: true),
                              DataColumn(label: const Text('Dystans'), onSort: _onSort, numeric: true),
                              DataColumn(label: const Text('Śr. Prędkość'), onSort: _onSort, numeric: true),
                              const DataColumn(label: Text('Usuń')),
                            ],
                            rows: _savedSessions.map((session) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(session.name)),
                                  DataCell(Text(DateFormat('dd.MM.yyyy HH:mm').format(session.timestamp.toLocal()))),
                                  DataCell(Text('${session.maxSpeed.toStringAsFixed(2)} km/h')),
                                  DataCell(Text(_formatDistance(session.distance))),
                                  DataCell(Text('${session.averageSpeed.toStringAsFixed(2)} km/h')),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteSession(session.id),
                                      tooltip: 'Usuń sesję',
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
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
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for PlatformException
import 'package:madspeed_app/models/speed_master_session.dart';
import 'package:madspeed_app/models/training_session.dart';
import 'package:madspeed_app/widgets/custom_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:madspeed_app/screens/map_view_screen.dart';
import 'package:madspeed_app/widgets/status_indicators_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart'; // Import share_plus

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SpeedMasterSession> _speedMasterSessions = [];
  List<TrainingSession> _trainingSessions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? speedMasterJson = prefs.getString('speed_master_sessions');
    final String? trainingJson = prefs.getString('training_sessions');

    setState(() {
      if (speedMasterJson != null && speedMasterJson.isNotEmpty) {
        try {
          _speedMasterSessions = SpeedMasterSession.decode(speedMasterJson);
          _speedMasterSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        } catch (e) {
          debugPrint('HistoryScreen ERROR: Failed to decode Speed Master sessions: $e');
          _speedMasterSessions = [];
        }
      }

      if (trainingJson != null && trainingJson.isNotEmpty) {
        try {
          _trainingSessions = TrainingSession.decode(trainingJson);
          _trainingSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        } catch (e) {
          debugPrint('HistoryScreen ERROR: Failed to decode Training sessions: $e');
          debugPrint('HistoryScreen ERROR: Problematic trainingJson: $trainingJson');
          _trainingSessions = [];
        }
      }
    });
  }

  Future<void> _deleteSpeedMasterSession(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: const Text('Czy na pewno chcesz usunąć tę sesję Speed Master?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Usuń')),
        ],
      ),
    );
    if (!context.mounted) return;

    if (confirm == true) {
      setState(() {
        _speedMasterSessions.removeWhere((session) => session.id == id);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('speed_master_sessions', SpeedMasterSession.encode(_speedMasterSessions));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesja Speed Master usunięta.')),
        );
      }
    }
  }

  Future<void> _deleteTrainingSession(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: const Text('Czy na pewno chcesz usunąć tę sesję treningową?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Usuń')),
        ],
        backgroundColor: Theme.of(context).cardColor,
      ),
    );
    if (!context.mounted) return;

    if (confirm == true) {
      setState(() {
        _trainingSessions.removeWhere((session) => session.id == id);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('training_sessions', TrainingSession.encode(_trainingSessions));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesja treningowa usunięta.')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String secs = twoDigits(duration.inSeconds.remainder(60));
    final String hours = twoDigits(duration.inHours);
    if (duration.inHours > 0) {
      return '$hours godz. $minutes min. $secs sek.';
    } else if (duration.inMinutes > 0) {
      return '$minutes min. $secs sek.';
    } else {
      return '$secs sek.';
    }
  }

  String _formatDistance(double distanceMeters) {
    String valueText;
    String unitText;

    if (distanceMeters < 1000) {
      valueText = distanceMeters.toStringAsFixed(0);
      unitText = 'm';
    } else {
      valueText = (distanceMeters / 1000.0).toStringAsFixed(3);
      unitText = 'km';
    }
    return '$valueText $unitText';
  }

  Future<void> _exportTrainingSessionToCsv(TrainingSession session) async {
    if (session.logData.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak danych logów do wyeksportowania dla tej sesji.')),
        );
      }
      return;
    }

    try {
      List<List<dynamic>> csvData = [
        ['Timestamp (s)', 'Speed (km/h)', 'Distance (m)', 'Latitude', 'Longitude']
      ];

      for (var point in session.logData) {
        csvData.add([
          point.timestamp,
          point.speed,
          point.distance,
          point.latitude,
          point.longitude,
        ]);
      }

      String csvString = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${session.name.replaceAll(' ', '_')}_${session.timestamp.toIso8601String().substring(0, 10)}.csv';
      final file = File(filePath);

      await file.writeAsString(csvString);

      if (!context.mounted) return;

      // Wywołanie udostępniania pliku
      // Oczekujemy na wynik, ale obsłużymy PlatformException jeśli wystąpi błąd z callbackiem
      try {
        await Share.shareXFiles([XFile(filePath)], text: 'Logi treningowe dla sesji: ${session.name}');
        if (!context.mounted) return; // Ponowne sprawdzenie kontekstu po operacji async

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logi wyeksportowane i dostępne do udostępnienia!')),
        );
      } on PlatformException catch (e) {
        // Specyficzna obsługa błędu callbacku share_plus
        if (e.message != null && e.message!.contains('Share callback error')) {
          debugPrint('PlatformException (Share callback error) caught: ${e.message}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Udostępnianie zakończone (prawdopodobnie anulowane przez użytkownika).'),
              ),
            );
          }
        } else {
          // Obsługa innych PlatformException
          debugPrint('Error during CSV export (PlatformException): ${e.message}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Błąd podczas eksportu logów: ${e.toString()}')),
            );
          }
        }
      }
    } catch (e) {
      // Ogólna obsługa pozostałych błędów
      debugPrint('Error during CSV export: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas eksportu logów: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia Wyników'),
        actions: const [
          StatusIndicatorsWidget(),
          SizedBox(width: 10),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Speed Master'),
            Tab(text: 'Treningi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _speedMasterSessions.isEmpty
              ? const Center(
                  child: Text('Brak zapisanych sesji Speed Master.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: _speedMasterSessions.length,
                  itemBuilder: (context, index) {
                    final session = _speedMasterSessions[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Data: ${session.timestamp.toLocal().day}.${session.timestamp.toLocal().month}.${session.timestamp.toLocal().year} ${session.timestamp.toLocal().hour}:${session.timestamp.toLocal().minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                            ),
                            const Divider(),
                            _buildHistoryRow('Maks. prędkość:', '${session.maxSpeed.toStringAsFixed(2)} km/h'),
                            _buildHistoryRow('Dystans:', _formatDistance(session.distance)),
                            _buildHistoryRow('Średnia prędkość:', '${session.averageSpeed.toStringAsFixed(2)} km/h'),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteSpeedMasterSession(session.id),
                                tooltip: 'Usuń tę sesję',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          _trainingSessions.isEmpty
              ? const Center(
                  child: Text('Brak zapisanych sesji treningowych.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: _trainingSessions.length,
                  itemBuilder: (context, index) {
                    final session = _trainingSessions[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Data: ${session.timestamp.toLocal().day}.${session.timestamp.toLocal().month}.${session.timestamp.toLocal().year} ${session.timestamp.toLocal().hour}:${session.timestamp.toLocal().minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                            ),
                            _buildHistoryRow('Czas trwania:', _formatDuration(session.duration)),
                            const Divider(),
                            _buildHistoryRow('Maks. prędkość:', '${session.maxSpeed.toStringAsFixed(2)} km/h'),
                            _buildHistoryRow('Dystans:', _formatDistance(session.distance)),
                            _buildHistoryRow('Średnia prędkość:', '${session.averageSpeed.toStringAsFixed(2)} km/h'),
                            if (session.logData.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('Wykres prędkości/dystansu:', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 200,
                                child: CustomChart(logData: session.logData),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.center,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.map),
                                  label: const Text('Pokaż na Mapie'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MapViewScreen(
                                          logData: session.logData,
                                          sessionName: session.name,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.download, color: Colors.blue),
                                    onPressed: () => _exportTrainingSessionToCsv(session),
                                    tooltip: 'Eksportuj do CSV',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteTrainingSession(session.id),
                                    tooltip: 'Usuń tę sesję',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

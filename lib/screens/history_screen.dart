import 'package:flutter/material.dart';
import 'package:madspeed_app/models/speed_master_session.dart';
import 'package:madspeed_app/models/training_session.dart';
import 'package:madspeed_app/widgets/custom_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      if (speedMasterJson != null) {
        _speedMasterSessions = SpeedMasterSession.decode(speedMasterJson);
        _speedMasterSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      if (trainingJson != null) {
        _trainingSessions = TrainingSession.decode(trainingJson);
        _trainingSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
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
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Usuń')),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia Wyników'),
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
          // Speed Master History Tab
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
                            _buildHistoryRow('Dystans:', '${session.distance.toStringAsFixed(3)} km'),
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

          // Training History Tab
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
                            const Divider(),
                            _buildHistoryRow('Maks. prędkość:', '${session.maxSpeed.toStringAsFixed(2)} km/h'),
                            _buildHistoryRow('Dystans:', '${session.distance.toStringAsFixed(3)} km'),
                            _buildHistoryRow('Średnia prędkość:', '${session.averageSpeed.toStringAsFixed(2)} km/h'),
                            if (session.logData.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('Wykres prędkości/dystansu:', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 200, // Fixed height for the chart in history
                                child: CustomChart(logData: session.logData),
                              ),
                            ],
                            Align(
                              alignment: Alignment.bottomRight,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTrainingSession(session.id),
                                tooltip: 'Usuń tę sesję',
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
          Expanded( // Dodano Expanded do wartości
            child: Text(
              value,
              textAlign: TextAlign.right, // Wyrównaj tekst do prawej
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis, // Dodaj elipsę, jeśli tekst jest zbyt długi
            ),
          ),
        ],
      ),
    );
  }
}

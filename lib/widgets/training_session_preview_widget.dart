// lib/widgets/training_session_preview_widget.dart

import 'dart:convert'; // Dodano dla jsonEncode/decode, choć nie jest bezpośrednio używane w tym widżecie
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Dodano dla PlatformException
import 'package:intl/intl.dart';
import 'package:madspeed_app/models/training_session.dart';
import 'package:madspeed_app/widgets/custom_chart.dart';
import 'package:madspeed_app/screens/map_view_screen.dart';
import 'package:madspeed_app/services/weather_service.dart';
import 'package:path_provider/path_provider.dart'; // Dodano
import 'package:csv/csv.dart'; // Dodano
import 'package:share_plus/share_plus.dart'; // Dodano

class TrainingSessionPreviewWidget extends StatefulWidget {
  final TrainingSession session;
  final String? dogName; // Opcjonalna nazwa psa do wyświetlenia

  const TrainingSessionPreviewWidget({
    super.key,
    required this.session,
    this.dogName,
  });

  @override
  State<TrainingSessionPreviewWidget> createState() => _TrainingSessionPreviewWidgetState();
}

class _TrainingSessionPreviewWidgetState extends State<TrainingSessionPreviewWidget> {
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    if (widget.session.startLocation != null) {
      setState(() {
        _isLoadingWeather = true;
      });
      final data = await _weatherService.fetchWeather(widget.session.startLocation!);
      setState(() {
        _weatherData = data;
        _isLoadingWeather = false;
      });
    } else {
      setState(() {
        _isLoadingWeather = false;
      });
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

  Widget _buildDetailRow(String label, String value) {
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

  // Funkcja eksportu do CSV, przeniesiona tutaj
  Future<void> _exportTrainingSessionToCsv() async {
    if (widget.session.logData.isEmpty) {
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

      for (var point in widget.session.logData) {
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
      final filePath = '${directory.path}/${widget.session.name.replaceAll(' ', '_')}_${widget.session.timestamp.toIso8601String().substring(0, 10)}.csv';
      final file = File(filePath);

      await file.writeAsString(csvString);

      if (!context.mounted) return;

      try {
        await Share.shareXFiles([XFile(filePath)], text: 'Logi treningowe dla sesji: ${widget.session.name}');
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logi wyeksportowane i dostępne do udostępnienia!')),
        );
      } on PlatformException catch (e) {
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
          debugPrint('Error during CSV export (PlatformException): ${e.message}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Błąd podczas eksportu logów: ${e.toString()}')),
            );
          }
        }
      }
    } catch (e) {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.session.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (widget.dogName != null)
            Text(
              'Dla psa: ${widget.dogName!}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blueGrey),
            ),
          const SizedBox(height: 8),
          Text(
            'Data: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.session.timestamp.toLocal())}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
          ),
          const Divider(),
          _buildDetailRow('Czas trwania:', _formatDuration(widget.session.duration)),
          _buildDetailRow('Maks. prędkość:', '${widget.session.maxSpeed.toStringAsFixed(2)} km/h'),
          _buildDetailRow('Dystans:', _formatDistance(widget.session.distance)),
          _buildDetailRow('Średnia prędkość:', '${widget.session.averageSpeed.toStringAsFixed(2)} km/h'),

          const SizedBox(height: 16),
          if (widget.session.logData.isNotEmpty) ...[
            Text('Wykres prędkości/dystansu:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: CustomChart(logData: widget.session.logData),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text('Pokaż na Mapie'),
                onPressed: () {
                  if (widget.session.logData.any((point) => point.latitude != null && point.longitude != null)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapViewScreen(
                          logData: widget.session.logData,
                          sessionName: widget.session.name,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Brak danych GPS w logach treningu do wyświetlenia na mapie.')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 10), // Odstęp przed przyciskiem eksportu
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Eksportuj CSV'),
                onPressed: _exportTrainingSessionToCsv, // Wywołanie funkcji eksportu
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Kolor przycisku eksportu
                ),
              ),
            ),
          ] else
            const Center(
              child: Text(
                'Brak danych logów do wyświetlenia wykresu, mapy i eksportu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 16),
          // Sekcja pogody
          if (_isLoadingWeather)
            const Center(child: CircularProgressIndicator())
          else if (_weatherData != null)
            Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Image.network(
                      _weatherService.getWeatherIconUrl(_weatherData!['icon']),
                      width: 40,
                      height: 40,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.cloud_off),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pogoda: ${_weatherData!['description']}'),
                          Text('Temp: ${_weatherData!['temperature'].toStringAsFixed(1)}°C (odczuwalna: ${_weatherData!['feels_like'].toStringAsFixed(1)}°C)'),
                          Text('Wiatr: ${_weatherData!['wind_speed'].toStringAsFixed(1)} m/s, Wilgotność: ${_weatherData!['humidity']}%'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (widget.session.startLocation != null)
            const Center(
              child: Text(
                'Brak danych pogodowych dla tego treningu (sprawdź połączenie z internetem).',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            )
          else
            const Center(
              child: Text(
                'Brak danych o lokalizacji startowej dla tego treningu, aby pobrać pogodę.',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

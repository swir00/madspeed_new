import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:madspeed_app/models/dog_profile.dart';
import 'package:madspeed_app/models/walk_session_model.dart';
import 'package:madspeed_app/screens/map_view_screen.dart';
import 'package:madspeed_app/services/weather_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class WalkSessionPreviewWidget extends StatefulWidget {
  final WalkSession session;
  final Map<int, DogProfile> dogProfilesMap;

  const WalkSessionPreviewWidget({
    super.key,
    required this.session,
    required this.dogProfilesMap,
  });

  @override
  State<WalkSessionPreviewWidget> createState() => _WalkSessionPreviewWidgetState();
}

class _WalkSessionPreviewWidgetState extends State<WalkSessionPreviewWidget> {
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
      setState(() => _isLoadingWeather = true);
      final googleMapsLatLng = google_maps.LatLng(
        widget.session.startLocation!.latitude,
        widget.session.startLocation!.longitude,
      );
      final data = await _weatherService.fetchWeather(googleMapsLatLng);
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoadingWeather = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _exportRouteToCsv() async {
    if (widget.session.routePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak punktów trasy do wyeksportowania.')),
      );
      return;
    }

    List<List<dynamic>> csvData = [['Latitude', 'Longitude']];
    for (var point in widget.session.routePoints) {
      csvData.add([point.latitude, point.longitude]);
    }

    String csvString = const ListToCsvConverter().convert(csvData);
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/${widget.session.name.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(widget.session.date)}.csv';
    final file = File(filePath);
    await file.writeAsString(csvString);

    await Share.shareXFiles([XFile(filePath)], text: 'Trasa spaceru: ${widget.session.name}');
  }

  @override
  Widget build(BuildContext context) {
    final dogNames = widget.session.dogIds.map((id) => widget.dogProfilesMap[id]?.name ?? 'Nieznany').join(', ');
    final avgSpeed = widget.session.duration.inSeconds > 0 ? (widget.session.distance / widget.session.duration.inSeconds) * 3.6 : 0.0;

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
          if (dogNames.isNotEmpty)
            Text(
              'Psy: $dogNames',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blueGrey),
            ),
          const SizedBox(height: 8),
          Text(
            'Data: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.session.date.toLocal())}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
          ),
          const Divider(),
          _buildDetailRow('Czas trwania:', _formatDuration(widget.session.duration)),
          _buildDetailRow('Dystans:', '${(widget.session.distance / 1000).toStringAsFixed(2)} km'),
          _buildDetailRow('Średnia prędkość:', '${avgSpeed.toStringAsFixed(2)} km/h'),
          const SizedBox(height: 16),
          if (widget.session.routePoints.isNotEmpty) ...[
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
                        sessionName: widget.session.name,
                        routePoints: widget.session.routePoints,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Eksportuj Trasę (CSV)'),
                onPressed: _exportRouteToCsv,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
          ],
          const SizedBox(height: 16),
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
                      width: 40, height: 40,
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
          else
            const Center(child: Text('Brak danych o lokalizacji startowej, aby pobrać pogodę.', textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
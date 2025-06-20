import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:madspeed_app/models/log_data_point.dart';

class MapViewScreen extends StatelessWidget {
  final List<LogDataPoint> logData;
  final String sessionName;

  const MapViewScreen({
    super.key,
    required this.logData,
    required this.sessionName,
  });

  @override
  Widget build(BuildContext context) {
    // Utwórz listę punktów LatLng z logData
    final List<LatLng> routePoints = logData
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => LatLng(p.latitude!, p.longitude!))
        .toList();

    // Oblicz środek trasy i początkowy zoom
    LatLng? center;
    double defaultZoom = 13.0; // Domyślny zoom
    if (routePoints.isNotEmpty) {
      double avgLat = routePoints.map((p) => p.latitude!).reduce((a, b) => a + b) / routePoints.length;
      double avgLng = routePoints.map((p) => p.longitude!).reduce((a, b) => a + b) / routePoints.length;
      center = LatLng(avgLat, avgLng);
    } else {
      // Domyślna lokalizacja, jeśli brak danych (np. centrum Polski)
      center = LatLng(52.2297, 21.0122); 
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Trasa: $sessionName'),
      ),
      body: routePoints.isEmpty
          ? const Center(
              child: Text(
                'Brak danych GPS do wyświetlenia trasy. Upewnij się, że logi zawierają dane o lokalizacji.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : FlutterMap(
              options: MapOptions(
                center: center,
                zoom: defaultZoom,
                maxZoom: 18.0, // Maksymalne powiększenie
                minZoom: 2.0,  // Minimalne powiększenie
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.madspeed_app', // Ważne dla OpenStreetMap
                ),
                // Wyświetl trasę jako linię
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
                // Opcjonalnie: markery dla startu i końca
                MarkerLayer(
                  markers: [
                    if (routePoints.isNotEmpty) // Marker na start
                      Marker(
                        point: routePoints.first,
                        width: 40.0, // Zmniejszyłem szerokość i wysokość markera
                        height: 40.0,
                        // Zmieniono 'builder' na bezpośredni 'child'
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 40.0,
                        ),
                      ),
                    if (routePoints.length > 1) // Marker na koniec
                      Marker(
                        point: routePoints.last,
                        width: 40.0, // Zmniejszyłem szerokość i wysokość markera
                        height: 40.0,
                        // Zmieniono 'builder' na bezpośredni 'child'
                        child: const Icon(
                          Icons.flag,
                          color: Colors.red,
                          size: 40.0,
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

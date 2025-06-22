import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:madspeed_app/services/ble_service.dart'; // Upewnij się, że ścieżka jest poprawna
import 'package:madspeed_app/widgets/status_indicators_widget.dart'; // Upewnij się, że ten import jest obecny

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  // Helper widget to build data rows for GPS info
  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BLEService>(context);

    // Jeśli urządzenie jest rozłączone, możemy wrócić do ekranu skanowania
    // lub wyświetlić odpowiedni komunikat.
    if (bleService.connectedDevice == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/');
      });
      // Poprawka: Usunięto 'const' przed AppBar. AppBar sam w sobie nie jest const.
      return Scaffold( // Usunięto 'const', ponieważ AppBar nie ma konstruktora 'const'.
        appBar: AppBar(title: const Text('Informacje o urządzeniu')),
        body: const Center( // Można dodać 'const' tutaj, bo Center i jego dzieci są const.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(), // Dodano const
              const SizedBox(height: 16), // Dodano const
              const Text('Brak połączenia z urządzeniem. Przekierowuję...'), // Dodano const
            ],
          ),
        ),
      );
    }

    // Jeśli urządzenie jest połączone, wyświetl dane
    final data = bleService.currentGpsData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informacje o urządzeniu'),
        actions: const [
          const StatusIndicatorsWidget(), // Status w AppBarze InfoScreen
          const SizedBox(width: 10), // Dodano const
        ],
      ),
      body: SingleChildScrollView( // Pozwala na przewijanie, jeśli zawartość jest długa
        padding: const EdgeInsets.all(20.0),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('Aktualne dane GPS:', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                _buildDataRow('Aktualna prędkość:', '${data.currentSpeed?.toStringAsFixed(2) ?? 'N/A'} km/h'),
                _buildDataRow('Maksymalna prędkość:', '${data.maxSpeed?.toStringAsFixed(2) ?? 'N/A'} km/h'),
                // Poprawione wyświetlanie dystansu (formatowanie w metrach/km)
                _buildDataRow('Przebyty dystans:', _formatDistance(data.distance)),
                _buildDataRow('Średnia prędkość:', '${data.avgSpeed?.toStringAsFixed(2) ?? 'N/A'} km/h'),
                _buildDataRow('Satelity:', '${data.satellites ?? 'N/A'}'),
                _buildDataRow('HDOP:', '${data.hdop?.toStringAsFixed(2) ?? 'N/A'}'),
                _buildDataRow('Jakość GPS:', '${data.gpsQualityLevel ?? 'N/A'}'),
                _buildDataRow('Bateria:', '${data.battery?.toStringAsFixed(0) ?? 'N/A'}%'),
                _buildDataRow('Logowanie aktywne:', (data.isLoggingActive ?? false) ? 'Tak' : 'Nie'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Funkcja do dynamicznego formatowania dystansu (skopiowana z TrainingScreen/SpeedMasterScreen dla spójności)
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
}

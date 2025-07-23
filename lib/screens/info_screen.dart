import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:madspeed_app/services/ble_service.dart'; // Upewnij się, że ścieżka jest poprawna
import 'package:madspeed_app/widgets/status_indicators_widget.dart'; // Upewnij się, że ten import jest obecny
import 'package:madspeed_app/services/theme_provider.dart'; // Dodaj import ThemeProvider

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});
  // Helper widget do budowania wierszy danych dla informacji GPS
  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
  // Funkcja do dynamicznego formatowania dystansu
  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return 'N/A';

    String valueText;
    String unitText;

    if (distanceMeters < 1000) {
      // Jeśli mniej niż 1 km
      valueText = distanceMeters.toStringAsFixed(0); // Zaokrągl do całości metrów
      unitText = 'm';
    } else {
      // 1 km lub więcej
      valueText = (distanceMeters / 1000.0)
          .toStringAsFixed(3); // Konwertuj na km z 3 miejscami po przecinku
      unitText = 'km';
    }
    return '$valueText $unitText';
  }
  Widget _buildGpsInfoCard(BuildContext context) {
    return Consumer<BLEService>(
      builder: (context, bleService, child) {
        if (bleService.connectedDevice == null) {
          // Karta wyświetlana, gdy urządzenie nie jest połączone
          return Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dane GPS',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  const Center(
                    child: Icon(Icons.bluetooth_disabled,
                        size: 40, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Połącz się z urządzeniem MadSpeed, aby zobaczyć aktualne dane.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        } else {
          // Karta z danymi GPS, gdy urządzenie jest połączone
          final data = bleService.currentGpsData;
          return Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aktualne dane GPS:',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  _buildDataRow('Aktualna prędkość:',
                      '${data.currentSpeed?.toStringAsFixed(2) ?? 'N/A'} km/h'),
                  _buildDataRow('Maksymalna prędkość:',
                      '${data.maxSpeed?.toStringAsFixed(2) ?? 'N/A'} km/h'),
                  _buildDataRow(
                      'Przebyty dystans:', _formatDistance(data.distance)),
                  _buildDataRow('Średnia prędkość:',
                      '${data.avgSpeed?.toStringAsFixed(2) ?? 'N/A'} km/h'),
                  _buildDataRow('Satelity:', '${data.satellites ?? 'N/A'}'),
                  _buildDataRow(
                      'HDOP:', '${data.hdop?.toStringAsFixed(2) ?? 'N/A'}'),
                  _buildDataRow(
                      'Jakość GPS:', '${data.gpsQualityLevel ?? 'N/A'}'),
                  _buildDataRow('Bateria:',
                      '${data.battery?.toStringAsFixed(0) ?? 'N/A'}%'),
                  _buildDataRow('Logowanie aktywne:',
                      (data.isLoggingActive ?? false) ? 'Tak' : 'Nie'),
                ],
              ),
            ),
          );
        }
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informacje i Ustawienia'), // Zmieniony tytuł
        actions: const [
          StatusIndicatorsWidget(), // Wskaźniki statusu w AppBarze
          SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Sekcja Danych GPS ---
            _buildGpsInfoCard(context),
            const SizedBox(height: 30), // Odstęp między sekcjami

            // --- Sekcja Ustawień Motywu ---
            Text(
              'Motyw aplikacji',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Wybierz wygląd aplikacji lub pozwól jej dostosować się do ustawień systemowych.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SegmentedButton<ThemeMode>(
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text('Jasny'),
                  icon: Icon(Icons.wb_sunny_outlined),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text('Ciemny'),
                  icon: Icon(Icons.nightlight_outlined),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.settings_system_daydream_outlined),
                ),
              ],
              selected: <ThemeMode>{themeProvider.themeMode},
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                themeProvider.setThemeMode(newSelection.first);
              },
            ),
            const Divider(height: 40),

            // --- Sekcja O aplikacji ---
            Text(
              'O aplikacji',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'MadSpeed App v1.0.0\nStworzona z pasją dla miłośników psów.',
            ),
            const SizedBox(height: 20), // Dodatkowy odstęp na dole
          ],
        ),
      ),
    );
  }
}
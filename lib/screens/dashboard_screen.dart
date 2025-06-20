import 'package:flutter/material.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:provider/provider.dart'; // Upewnij się, że jest zaimportowany

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BLEService>(context); // Poprawiono użycie Provider.of

    // If no device is connected, navigate back to scan screen
    if (bleService.connectedDevice == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/');
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('MadSpeed - Połączono z ${bleService.connectedDevice!.platformName.isNotEmpty ? bleService.connectedDevice!.platformName : "Nieznane"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
            tooltip: 'Historia zapisanych wyników',
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await bleService.disconnect();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
            tooltip: 'Rozłącz i wróć do skanowania',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Current GPS Data Display (always visible on dashboard)
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Aktualne dane GPS:', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      Consumer<BLEService>( // Poprawiono użycie Consumer
                        builder: (context, bleService, child) {
                          final data = bleService.currentGpsData;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDataRow('Aktualna prędkość:', '${data.currentSpeed?.toStringAsFixed(2) ?? 'N/A'} km/h'),
                              _buildDataRow('Maksymalna prędkość:', '${data.maxSpeed?.toStringAsFixed(2) ?? 'N/A'} km/h'),
                              _buildDataRow('Przebyty dystans:', '${data.distance?.toStringAsFixed(3) ?? 'N/A'} km'),
                              _buildDataRow('Średnia prędkość:', '${data.avgSpeed?.toStringAsFixed(2) ?? 'N/A'} km/h'),
                              _buildDataRow('Satelity:', '${data.satellites ?? 'N/A'}'),
                              _buildDataRow('HDOP:', '${data.hdop?.toStringAsFixed(2) ?? 'N/A'}'),
                              _buildDataRow('Jakość GPS:', '${data.gpsQualityLevel ?? 'N/A'}'),
                              _buildDataRow('Bateria:', '${data.battery?.toStringAsFixed(2) ?? 'N/A'} V'),
                              _buildDataRow('Logowanie aktywne:', (data.isLoggingActive ?? false) ? 'Tak' : 'Nie'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Navigation buttons
              _buildDashboardButton(
                context,
                icon: Icons.speed,
                label: 'Speed Master',
                onPressed: () {
                  Navigator.pushNamed(context, '/speed_master');
                },
              ),
              const SizedBox(height: 20),
              _buildDashboardButton(
                context,
                icon: Icons.run_circle,
                label: 'Trening',
                onPressed: () {
                  Navigator.pushNamed(context, '/training');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to build data rows
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

  // Helper widget to build themed dashboard buttons
  Widget _buildDashboardButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 30),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 8,
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}

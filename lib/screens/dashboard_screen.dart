import 'package:flutter/material.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:provider/provider.dart';
import 'package:madspeed_app/widgets/status_indicators_widget.dart'; // Import StatusIndicatorsWidget

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BLEService>(context);

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
          const StatusIndicatorsWidget(), // Dodano pasek statusu
          const SizedBox(width: 10),
          // Przycisk "Rozłącz" pozostaje w AppBarze
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
              const SizedBox(height: 20), // Odstęp między grupami przycisków
              // NOWOŚĆ: Przyciski Historia i Info przeniesione do body
              _buildDashboardButton(
                context,
                icon: Icons.history, // Ikona historii
                label: 'Historia',
                onPressed: () {
                  Navigator.pushNamed(context, '/history');
                },
              ),
              const SizedBox(height: 20),
              _buildDashboardButton(
                context,
                icon: Icons.info, // Ikona informacji
                label: 'Informacje o Urządzeniu', // Zmieniono tekst na bardziej opisowy
                onPressed: () {
                  Navigator.pushNamed(context, '/info');
                },
              ),
            ],
          ),
        ),
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

// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:madspeed_app/screens/dog_profile_list_screen.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:provider/provider.dart';
import 'package:madspeed_app/screens/history_screen.dart';
import 'package:madspeed_app/screens/speed_master_screen.dart';
import 'package:madspeed_app/screens/training_screen.dart';
import 'package:madspeed_app/screens/info_screen.dart'; // Import dla InfoScreen
import 'package:madspeed_app/widgets/status_indicators_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MadSpeed'),
        centerTitle: true,
        actions: [
          const StatusIndicatorsWidget(),
          Consumer<BLEService>(
            builder: (context, bleService, child) {
              return IconButton(
                icon: const Icon(Icons.link_off),
                onPressed: bleService.connectedDevice != null ? () => bleService.disconnect() : null,
                tooltip: 'Rozłącz urządzenie',
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2, // Dwie kolumny
          crossAxisSpacing: 16.0, // Odstęp między kolumnami
          mainAxisSpacing: 16.0, // Odstęp między wierszami
          children: <Widget>[
            _buildDashboardCard(
              context,
              'Moje Psy',
              Icons.pets,
              '/dog_profiles', // Trasa do DogProfileListScreen
            ),
            _buildDashboardCard(
              context,
              'Trening',
              Icons.run_circle,
              '/training',
            ),
            _buildDashboardCard(
              context,
              'Historia',
              Icons.history,
              '/history',
            ),
            _buildDashboardCard(
              context,
              'Speed Master',
              Icons.speed,
              '/speed_master',
            ),
            _buildDashboardCard(
              context,
              'Informacje',
              Icons.info_outline,
              '/info',
            ),
            // NOWY PRZYCISK: Skanuj urządzenia BLE
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/'); // Nawiguj do ScanScreen
                },
                borderRadius: BorderRadius.circular(15.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.bluetooth_searching,
                        size: 50,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Połącz z MadSpeed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, String title, IconData icon, String route) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(15.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 50,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:provider/provider.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BLEService>(context, listen: false).startScan();
    });
  }

  @override
  void dispose() {
    Provider.of<BLEService>(context, listen: false).stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MadSpeed - Skanuj urządzenia'),
        actions: [
          Consumer<BLEService>(
            builder: (context, bleService, child) {
              return IconButton(
                icon: bleService.isScanning
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.refresh),
                onPressed: bleService.isScanning ? null : () => bleService.startScan(), // Odśwież listę
                tooltip: 'Odśwież listę',
              );
            },
          ),
        ],
      ),
      body: Consumer<BLEService>(
        builder: (context, bleService, child) {
          // Display current Bluetooth adapter state
          return StreamBuilder<BluetoothAdapterState>(
            stream: FlutterBluePlus.adapterState,
            builder: (context, snapshot) {
              final adapterState = snapshot.data;
              if (adapterState != BluetoothAdapterState.on) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bluetooth_disabled, size: 100, color: Colors.grey),
                        const SizedBox(height: 20),
                        Text(
                          'Bluetooth jest wyłączony. Proszę włączyć Bluetooth, aby kontynuować.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS)
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: ElevatedButton(
                              onPressed: () {
                                // Open Bluetooth settings for Android and iOS
                                FlutterBluePlus.turnOn();
                              },
                              child: const Text('Włącz Bluetooth'),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              // Display scan results if Bluetooth is on
              return Column(
                children: [
                  if (bleService.isScanning)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Skanowanie urządzeń MadSpeed...',
                        style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                      ),
                    ),
                  Expanded(
                    child: bleService.scanResults.isEmpty && !bleService.isScanning
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bluetooth_searching, size: 100, color: Colors.grey),
                                SizedBox(height: 20),
                                Text(
                                  'Nie znaleziono urządzeń MadSpeed.\nKliknij odśwież, aby spróbować ponownie.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: bleService.scanResults.length,
                            itemBuilder: (context, index) {
                              final BluetoothDevice device = bleService.scanResults[index];
                              final bool isCurrentlyConnected = bleService.connectedDevice?.remoteId == device.remoteId;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                elevation: 3,
                                child: ListTile(
                                  leading: const Icon(Icons.bluetooth, color: Colors.blueAccent),
                                  title: Text(device.platformName.isNotEmpty
                                      ? device.platformName
                                      : 'Nieznane urządzenie'),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      if (isCurrentlyConnected) {
                                        await bleService.disconnect();
                                      } else {
                                        bool connected = await bleService.connectToDevice(device);
                                        if (connected && mounted) {
                                          Navigator.pushReplacementNamed(context, '/dashboard');
                                        } else if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Nie udało się połączyć z urządzeniem.')),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isCurrentlyConnected ? Colors.orange : Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(isCurrentlyConnected ? 'Rozłącz' : 'Połącz'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

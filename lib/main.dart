import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:madspeed_app/screens/scan_screen.dart';
import 'package:madspeed_app/screens/dashboard_screen.dart';
import 'package:madspeed_app/screens/speed_master_screen.dart';
import 'package:madspeed_app/screens/training_screen.dart';
import 'package:madspeed_app/screens/history_screen.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:provider/provider.dart';

void main() {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        // Provide the BLEService to the widget tree
        ChangeNotifierProvider(create: (_) => BLEService()),
      ],
      child: const MyApp(),
    ),
  );
=======
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert'; // Do parsowania JSON

// --- Definicje UUID z Twojego kodu ESP32 ---
// MUSZĄ BYĆ IDENTYCZNE z tymi, które zdefiniowałeś na ESP32!
const String SERVICE_UUID = "A2A00000-B1B1-C2C2-D3D3-E4E4E4E4E4E4";
const String CHAR_UUID_CURRENT_DATA = "A2A00001-B1B1-C2C2-D3D3-E4E4E4E4E4E4";
const String CHAR_UUID_CONTROL = "A2A00002-B1B1-C2C2-D3D3-E4E4E4E4E4E4";
const String CHAR_UUID_LOG_DATA = "A2A00003-B1B1-C2C2-D3D3-E4E4E4E4E4E4";
const String CHAR_UUID_DEVICE_INFO = "A2A00004-B1B1-C2C2-D3D3-E4E4E4E4E4E4";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBluePlus.setForceAndroidBleApi(FlutterBluePlus.instance.isAndroid && false); // Tylko dla Androida, iOS to nie dotyczy
  runApp(const MyApp());
>>>>>>> 453f572e89beca443a1d48bec0e29d104017f543
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
<<<<<<< HEAD
      title: 'MadSpeed App',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          buttonColor: Colors.blueAccent,
          textTheme: ButtonTextTheme.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
        cardTheme: CardThemeData( // Zmieniono na CardThemeData
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          margin: const EdgeInsets.all(10),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      initialRoute: '/', // Set the initial route
      routes: {
        '/': (context) => const ScanScreen(), // Scan screen is the starting point
        '/dashboard': (context) => const DashboardScreen(), // Dashboard after connection
        '/speed_master': (context) => const SpeedMasterScreen(), // Speed Master screen
        '/training': (context) => const TrainingScreen(), // Training screen
        '/history': (context) => const HistoryScreen(), // History screen for saved sessions
      },
    );
  }
}
=======
      title: 'MadSpeed BLE App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BluetoothDiscoveryScreen(),
    );
  }
}

class BluetoothDiscoveryScreen extends StatefulWidget {
  const BluetoothDiscoveryScreen({super.key});

  @override
  _BluetoothDiscoveryScreenState createState() => _BluetoothDiscoveryScreenState();
}

class _BluetoothDiscoveryScreenState extends State<BluetoothDiscoveryScreen> {
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  List<BluetoothDevice> _scannedDevices = [];
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _currentDataCharacteristic;
  BluetoothCharacteristic? _controlCharacteristic;
  BluetoothCharacteristic? _logDataCharacteristic;
  BluetoothCharacteristic? _deviceInfoCharacteristic;

  bool _isScanning = false;
  String _currentData = "Brak danych"; // Surowe dane JSON
  String _statusMessage = "Gotowy do skanowania...";
  bool _isLoggingActive = false; // Stan logowania z ESP32

  // Dostęp do konkretnych danych GNSS/Baterii
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _altitude = 0.0;
  int _satellites = 0;
  double _hdop = 0.0;
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _avgSpeed = 0.0;
  double _distance = 0.0;
  int _gpsQualityLevel = 0;
  double _batteryVoltage = 0.0;


  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _characteristicValueSubscription;
  StreamSubscription? _adapterStateSubscription;


  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _listenToBluetoothState(); // Nasłuchuj stanu adaptera Bluetooth
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _characteristicValueSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  // Sprawdza i prosi o niezbędne uprawnienia (Bluetooth, Lokalizacja)
  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // Wymagane dla skanowania BLE na iOS/Android
    ].request();

    if (statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true &&
        statuses[Permission.locationWhenInUse]?.isGranted == true) {
      _statusMessage = "Uprawnienia Bluetooth i lokalizacji przyznane.";
      setState(() {});
    } else {
      _statusMessage = "Brak wszystkich wymaganych uprawnień. Skanowanie może być niemożliwe.";
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proszę przyznać uprawnienia Bluetooth i lokalizacji w ustawieniach aplikacji.')),
      );
    }
  }

  // Nasłuchuje stanu adaptera Bluetooth (włączony/wyłączony)
  void _listenToBluetoothState() {
    _adapterStateSubscription = flutterBlue.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.off) {
        _statusMessage = "Bluetooth jest wyłączony. Włącz go, aby skanować.";
        _disconnectDevice(); // Rozłącz, jeśli Bluetooth zostanie wyłączony
      } else if (state == BluetoothAdapterState.on) {
        _statusMessage = "Bluetooth jest włączony. Możesz skanować.";
      }
      setState(() {});
    });
  }

  // Rozpoczyna skanowanie urządzeń BLE
  void _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scannedDevices.clear();
      _statusMessage = "Skanowanie urządzeń...";
    });

    try {
      // Upewnij się, że Bluetooth jest włączony przed skanowaniem
      var adapterState = await flutterBlue.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _statusMessage = "Bluetooth nie jest włączony.";
        setState(() {
          _isScanning = false;
        });
        return;
      }

      // Rozpocznij skanowanie na 10 sekund
      _scanResultsSubscription = flutterBlue.scanResults.listen((results) {
        for (ScanResult r in results) {
          // Filtrujemy urządzenia po nazwie, która zaczyna się od "MadSpeed_"
          if (r.device.name.startsWith('MadSpeed_') && !_scannedDevices.contains(r.device)) {
            setState(() {
              _scannedDevices.add(r.device);
            });
          }
        }
      });

      await flutterBlue.startScan(timeout: const Duration(seconds: 10));
      // Czekaj na zakończenie skanowania, subskrypcja scanResults przestanie dostarczać nowe wyniki
      await flutterBlue.isScanning.firstWhere((isScanning) => !isScanning);

      setState(() {
        _isScanning = false;
        if (_scannedDevices.isEmpty) {
          _statusMessage = "Skanowanie zakończone. Nie znaleziono urządzeń MadSpeed.";
        } else {
          _statusMessage = "Skanowanie zakończone. Znaleziono ${_scannedDevices.length} urządzeń.";
        }
      });
    } catch (e) {
      _statusMessage = "Błąd skanowania: $e";
      setState(() {
        _isScanning = false;
      });
      print("Błąd skanowania: $e");
    }
  }

  // Łączy się z wybranym urządzeniem BLE
  Future<void> _connectToDevice(BluetoothDevice device) async {
    // Jeśli już połączono z innym urządzeniem, rozłącz je
    if (_connectedDevice != null && _connectedDevice!.remoteId != device.remoteId) {
      await _disconnectDevice();
    }

    setState(() {
      _statusMessage = "Łączenie z ${device.name}...";
    });

    try {
      // Nasłuchuj zmian stanu połączenia urządzenia
      _connectionStateSubscription = device.connectionState.listen((BluetoothConnectionState state) async {
        if (state == BluetoothConnectionState.disconnected) {
          _statusMessage = "Rozłączono z ${device.name}";
          _disconnectDevice(); // Zaktualizuj stan UI po rozłączeniu
        } else if (state == BluetoothConnectionState.connected) {
          _statusMessage = "Połączono z ${device.name}. Odkrywam usługi...";
        }
        setState(() {});
      });

      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      print('Połączono z ${device.name}');

      await _discoverServicesAndCharacteristics(device);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Połączono z ${device.name}')),
      );
    } catch (e) {
      _statusMessage = "Błąd połączenia z ${device.name}: $e";
      _disconnectDevice(); // Zawsze rozłącz, jeśli wystąpi błąd
      print('Błąd połączenia z ${device.name}: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd połączenia: ${e.toString()}')),
      );
    }
  }

  // Odkrywa usługi i charakterystyki po połączeniu
  Future<void> _discoverServicesAndCharacteristics(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    bool serviceFound = false;

    for (var service in services) {
      if (service.uuid.toString().toUpperCase() == SERVICE_UUID) {
        serviceFound = true;
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_CURRENT_DATA) {
            _currentDataCharacteristic = characteristic;
            await _listenToNotifications(characteristic);
            print('Znaleziono charakterystykę Current Data');
          } else if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_CONTROL) {
            _controlCharacteristic = characteristic;
            print('Znaleziono charakterystykę Control');
          } else if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_LOG_DATA) {
            _logDataCharacteristic = characteristic;
            print('Znaleziono charakterystykę Log Data');
          } else if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_DEVICE_INFO) {
            _deviceInfoCharacteristic = characteristic;
            print('Znaleziono charakterystykę Device Info');
          }
        }
        break; // Znaleziono naszą usługę, nie trzeba szukać dalej
      }
    }

    if (!serviceFound) {
      _statusMessage = "Brak usługi MadSpeed na urządzeniu ${device.name}. Rozłączam.";
      _disconnectDevice();
    } else {
      _statusMessage = "Połączono i usługi odkryte. Oczekuję danych...";
    }
    setState(() {});
  }

  // Nasłuchuje powiadomień z charakterystyki Current Data
  Future<void> _listenToNotifications(BluetoothCharacteristic characteristic) async {
    if (characteristic.properties.notify || characteristic.properties.indicate) {
      await characteristic.setNotifyValue(true);
      _characteristicValueSubscription = characteristic.onValueReceived.listen((value) {
        try {
          String receivedString = utf8.decode(value);
          final Map<String, dynamic> data = json.decode(receivedString);
          setState(() {
            _currentData = receivedString; // Wyświetlamy cały JSON dla debugowania

            // Parsowanie i aktualizacja konkretnych pól
            _latitude = data['latitude'] ?? 0.0;
            _longitude = data['longitude'] ?? 0.0;
            _altitude = data['altitude'] ?? 0.0;
            _satellites = data['satellites'] ?? 0;
            _hdop = data['hdop'] ?? 0.0;
            _currentSpeed = data['currentSpeed'] ?? 0.0;
            _maxSpeed = data['maxSpeed'] ?? 0.0;
            _avgSpeed = data['avgSpeed'] ?? 0.0;
            _distance = data['distance'] ?? 0.0;
            _gpsQualityLevel = data['gpsQualityLevel'] ?? 0;
            _batteryVoltage = data['battery'] ?? 0.0;
            _isLoggingActive = data['isLoggingActive'] ?? false;
          });
        } catch (e) {
          print("Błąd parsowania JSON lub dekodowania danych: $e");
          setState(() {
            _currentData = "Błąd dekodowania danych: $e";
          });
        }
      });
      print('Nasłuchiwanie na powiadomienia Current Data włączone.');
    } else {
      print('Charakterystyka Current Data nie obsługuje powiadomień.');
    }
  }

  // Rozłącza się z aktualnie połączonym urządzeniem
  Future<void> _disconnectDevice() async {
    _scanResultsSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _characteristicValueSubscription?.cancel();
    _currentDataCharacteristic = null;
    _controlCharacteristic = null;
    _logDataCharacteristic = null;
    _deviceInfoCharacteristic = null;
    _currentData = "Brak danych";

    // Resetuj wartości po rozłączeniu
    _latitude = 0.0; _longitude = 0.0; _altitude = 0.0; _satellites = 0; _hdop = 0.0;
    _currentSpeed = 0.0; _maxSpeed = 0.0; _avgSpeed = 0.0; _distance = 0.0;
    _gpsQualityLevel = 0; _batteryVoltage = 0.0; _isLoggingActive = false;


    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
        print('Ręcznie rozłączono z ${_connectedDevice!.name}');
      } catch (e) {
        print('Błąd podczas rozłączania: $e');
      } finally {
        setState(() {
          _connectedDevice = null;
          _statusMessage = "Rozłączono.";
        });
      }
    }
  }

  // Wysyła komendę do ESP32
  Future<void> _sendCommand(String command) async {
    if (_controlCharacteristic != null && _connectedDevice != null &&
        (await _connectedDevice!.connectionState.first) == BluetoothConnectionState.connected) {
      try {
        await _controlCharacteristic!.write(utf8.encode(command), withoutResponse: true);
        print('Wysłano komendę: $command');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wysłano: $command')),
        );
      } catch (e) {
        print('Błąd wysyłania komendy $command: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd wysyłania: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak połączenia lub charakterystyka sterująca niedostępna.')),
      );
    }
  }

  // Pobiera i wyświetla dane logowania
  Future<void> _downloadLogData() async {
    if (_logDataCharacteristic != null && _connectedDevice != null &&
        (await _connectedDevice!.connectionState.first) == BluetoothConnectionState.connected) {
      try {
        List<int> value = await _logDataCharacteristic!.read();
        String logJson = utf8.decode(value);
        print("Pobrane dane logowania (JSON): $logJson");
        // Tutaj możesz wyświetlić dane w nowym oknie dialogowym lub przekazać do innego widoku
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Dane logowania'),
            content: SingleChildScrollView(
              child: Text(logJson),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Zamknij'),
              ),
            ],
          ),
        );
      } catch (e) {
        print('Błąd pobierania danych logowania: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd pobierania logów: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak połączenia lub charakterystyka logowania niedostępna.')),
      );
    }
  }

  // Pobiera i wyświetla informacje o urządzeniu
  Future<void> _getDeviceInfo() async {
    if (_deviceInfoCharacteristic != null && _connectedDevice != null &&
        (await _connectedDevice!.connectionState.first) == BluetoothConnectionState.connected) {
      try {
        List<int> value = await _deviceInfoCharacteristic!.read();
        String deviceInfoJson = utf8.decode(value);
        print("Informacje o urządzeniu (JSON): $deviceInfoJson");
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Informacje o urządzeniu'),
            content: Text(deviceInfoJson),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Zamknij'),
              ),
            ],
          ),
        );
      } catch (e) {
        print('Błąd pobierania informacji o urządzeniu: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd pobierania info: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak połączenia lub charakterystyka informacji niedostępna.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MadSpeed BLE App'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $_statusMessage', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                _connectedDevice == null
                    ? ElevatedButton(
                        onPressed: _isScanning ? null : _startScan,
                        child: Text(_isScanning ? 'Skanowanie...' : 'Skanuj urządzenia BLE'),
                      )
                    : ElevatedButton(
                        onPressed: _disconnectDevice,
                        child: Text('Rozłącz z ${_connectedDevice!.name}'),
                      ),
              ],
            ),
          ),
          const Divider(),
          // Lista znalezionych urządzeń
          Expanded(
            child: ListView.builder(
              itemCount: _scannedDevices.length,
              itemBuilder: (context, index) {
                final device = _scannedDevices[index];
                return ListTile(
                  title: Text(device.name.isEmpty ? '(Brak nazwy)' : device.name),
                  subtitle: Text(device.remoteId.toString()), // Adres MAC urządzenia
                  trailing: _connectedDevice?.remoteId == device.remoteId
                      ? const Text('Połączono', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                      : ElevatedButton(
                          onPressed: () => _connectToDevice(device),
                          child: const Text('Połącz'),
                        ),
                );
              },
            ),
          ),
          const Divider(),
          // Panel sterowania i danych po połączeniu
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nowy widok danych pomiarowych
                const Text('Aktualne dane z urządzenia:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.5)),
                // Karta dla Prędkości
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 5.0),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Prędkość', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(
                          '${_currentSpeed.toStringAsFixed(1)} km/h',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        Text('Max: ${_maxSpeed.toStringAsFixed(1)} km/h', style: const TextStyle(fontSize: 14)),
                        Text('Średnia: ${_avgSpeed.toStringAsFixed(1)} km/h', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                // Karta dla Dystansu
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 5.0),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dystans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(
                          '${_distance.toStringAsFixed(2)} km',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                // Karta dla Baterii i Jakości GPS
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 5.0),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Stan Urządzenia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bateria:', style: TextStyle(fontSize: 14)),
                                Text(
                                  '${_batteryVoltage.toStringAsFixed(2)} V',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _batteryVoltage > 3.7 ? Colors.green : (_batteryVoltage > 3.3 ? Colors.orange : Colors.red),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Jakość GPS:', style: TextStyle(fontSize: 14)),
                                Text(
                                  'Poziom ${_gpsQualityLevel}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _gpsQualityLevel >= 4 ? Colors.green : (_gpsQualityLevel >= 2 ? Colors.orange : Colors.red),
                                  ),
                                ),
                                Text('Satelity: $_satellites (HDOP: ${_hdop.toStringAsFixed(1)})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Mały tekst z surowymi danymi JSON na dole (dla debugowania)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Surowe dane (JSON): $_currentData', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
                const SizedBox(height: 10), // Dodatkowy odstęp przed przyciskami

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: _connectedDevice != null ? () => _sendCommand('START') : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoggingActive ? Colors.green[700] : null, // Ciemniejsza zieleń, jeśli aktywne
                      ),
                      child: Text(_isLoggingActive ? 'Logowanie AKTYWNE' : 'START Logowania'),
                    ),
                    ElevatedButton(
                      onPressed: _connectedDevice != null ? () => _sendCommand('STOP') : null,
                      style: ElevatedButton.styleFrom(
                         backgroundColor: _isLoggingActive ? null : Colors.red[700], // Ciemniejsza czerwień, jeśli nieaktywne
                      ),
                      child: const Text('STOP Logowania'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: _connectedDevice != null ? () => _sendCommand('RESET') : null,
                      child: const Text('RESET Danych'),
                    ),
                    ElevatedButton(
                      onPressed: _connectedDevice != null ? _downloadLogData : null,
                      child: const Text('Pobierz Logi'),
                    ),
                    ElevatedButton(
                      onPressed: _connectedDevice != null ? _getDeviceInfo : null,
                      child: const Text('Info o Urządzeniu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
>>>>>>> 453f572e89beca443a1d48bec0e29d104017f543

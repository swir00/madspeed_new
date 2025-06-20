import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:madspeed_app/models/gps_data.dart';
import 'package:madspeed_app/models/log_data_point.dart';

// BLE UUIDs from ESP32 code
const String SERVICE_UUID = "A2A00000-B1B1-C2C2-D3D3-E4E4E4E4E4E4";
const String CHAR_UUID_CURRENT_DATA = "A2A00001-B1B1-C2C2-D3D3-E4E4E4E4E4E4";
const String CHAR_UUID_CONTROL = "A2A00002-B1B1-C2C2-D3D3-E4E4E4E4E4E4";
const String CHAR_UUID_LOG_DATA = "A2A00003-B1B1-C2C2-D3D3-E4E4E4E4E4E4"; // Now used for NOTIFY chunks
const String CHAR_UUID_DEVICE_INFO = "A2A00004-B1B1-C2C2-D3D3-E4E4E4E4E4E4";

class BLEService with ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  BluetoothCharacteristic? _currentDataCharacteristic;
  BluetoothCharacteristic? _controlCharacteristic;
  BluetoothCharacteristic? _logDataCharacteristic; // Now subscribes for chunks
  BluetoothCharacteristic? _deviceInfoCharacteristic;

  GPSData _currentGpsData = GPSData();
  GPSData get currentGpsData => _currentGpsData;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _currentDataSubscription;
  StreamSubscription? _logDataSubscription; // New subscription for log data chunks

  List<BluetoothDevice> _scanResults = [];
  List<BluetoothDevice> get scanResults => _scanResults;

  // For log data transfer
  String _receivedLogJson = "";
  Completer<List<LogDataPoint>>? _logDataCompleter; // Used to await log transfer completion

  // Constructor to set up initial state and listeners
  BLEService() {
    _initializeBLE();
  }

  Future<void> _initializeBLE() async {
    // Request permissions
    await _requestPermissions();

    // Listen to BLE adapter state changes
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      debugPrint("BLE Adapter State: $state");
      if (state == BluetoothAdapterState.off) {
        disconnect(); // Disconnect if BLE is turned off
        _scanResults.clear();
        notifyListeners();
      } else if (state == BluetoothAdapterState.on && connectedDevice == null) {
        // Optionally: auto-start scan when adapter is on and not connected
      }
    });
  }

  // Request necessary BLE permissions
  Future<void> _requestPermissions() async {
    if (await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted &&
        await Permission.locationWhenInUse.request().isGranted) {
      debugPrint("BLE permissions granted");
    } else {
      debugPrint("BLE permissions not granted");
      // Optionally, show a dialog to the user explaining why permissions are needed
    }
  }

  // Start scanning for BLE devices
  Future<void> startScan() async {
    await _requestPermissions(); // Re-request permissions before scanning
    if (_isScanning) return;

    _scanResults.clear();
    _isScanning = true;
    notifyListeners();

    try {
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.advertisementData.localName.startsWith("MadSpeed") &&
              !_scanResults.any((element) => element.remoteId == r.device.remoteId)) {
            _scanResults.add(r.device);
            debugPrint("Found device: ${r.device.name} (${r.device.remoteId}) RSSI: ${r.rssi}");
            notifyListeners();
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      debugPrint("BLE Scan Started");
    } catch (e) {
      debugPrint("Error starting scan: $e");
    } finally {
      // The scan might stop due to timeout or explicit stopScan call
    }
  }

  // Stop scanning for BLE devices
  void stopScan() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
    debugPrint("BLE Scan Stopped");
  }

  // Connect to a selected BLE device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_connectedDevice != null) {
      await disconnect(); 
    }

    stopScan(); 

    try {
      _connectionStateSubscription = device.connectionState.listen((BluetoothConnectionState state) async {
        debugPrint("Device ${device.name} connection state: $state");
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint("Device ${device.name} disconnected!");
          _connectedDevice = null;
          _currentDataCharacteristic = null;
          _controlCharacteristic = null;
          _logDataCharacteristic = null;
          _deviceInfoCharacteristic = null;
          _currentDataSubscription?.cancel();
          _logDataSubscription?.cancel(); // Cancel log data subscription
          _currentGpsData = GPSData(); 
          notifyListeners();
        }
      });

      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      debugPrint("Connected to ${device.name}");
      notifyListeners();

      await _discoverServices(device); 
      return true;
    } catch (e) {
      debugPrint("Error connecting to device ${device.name}: $e");
      await disconnect(); 
      return false;
    }
  }

  // Disconnect from the current BLE device
  Future<void> disconnect() async {
    _currentDataSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _logDataSubscription?.cancel(); // Cancel log data subscription
    
    stopScan(); 

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      debugPrint("Disconnected from ${_connectedDevice!.name}");
    }
    _connectedDevice = null;
    _currentDataCharacteristic = null;
    _controlCharacteristic = null;
    _logDataCharacteristic = null;
    _deviceInfoCharacteristic = null;
    _currentGpsData = GPSData();
    notifyListeners();
  }

  // Discover services and characteristics on the connected device
  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    debugPrint("Discovered ${services.length} services.");

    for (var service in services) {
      if (service.uuid.toString().toUpperCase() == SERVICE_UUID.toUpperCase()) {
        debugPrint("Found MadSpeed Service: ${service.uuid}");
        for (var characteristic in service.characteristics) {
          debugPrint("  Characteristic: ${characteristic.uuid}");
          if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_CURRENT_DATA.toUpperCase()) {
            _currentDataCharacteristic = characteristic;
            await _setupCurrentDataNotifications(); 
            debugPrint("    Current Data Characteristic found and notifications enabled.");
          } else if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_CONTROL.toUpperCase()) {
            _controlCharacteristic = characteristic;
            debugPrint("    Control Characteristic found.");
          } else if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_LOG_DATA.toUpperCase()) {
            _logDataCharacteristic = characteristic;
            debugPrint("    Log Data Characteristic found. (Now NOTIFY)");
            await _setupLogDataNotifications(); // Setup notifications for log chunks
          } else if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_DEVICE_INFO.toUpperCase()) {
            _deviceInfoCharacteristic = characteristic;
            debugPrint("    Device Info Characteristic found.");
          }
        }
        break; 
      }
    }
    if (_currentDataCharacteristic == null ||
        _controlCharacteristic == null ||
        _logDataCharacteristic == null ||
        _deviceInfoCharacteristic == null) {
      debugPrint("Warning: Not all required characteristics were found.");
    }
  }

  // Set up notifications for current data characteristic
  Future<void> _setupCurrentDataNotifications() async {
    if (_currentDataCharacteristic == null) return;
    await _currentDataCharacteristic!.setNotifyValue(true);
    _currentDataSubscription = _currentDataCharacteristic!.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        try {
          final String jsonString = utf8.decode(value);
          // debugPrint("Raw CurrentData JSON (from ESP32): $jsonString"); // DEBUG: Print raw JSON
          final Map<String, dynamic> data = jsonDecode(jsonString);
          _currentGpsData = GPSData.fromJson(data);
          notifyListeners();
        } catch (e) {
          debugPrint("Error decoding CurrentDataCharacteristic: $e, Raw bytes: $value");
        }
      } else {
        debugPrint("Received empty value from CurrentDataCharacteristic.");
      }
    });
    debugPrint("Notifications enabled for Current Data.");
  }

  // Set up notifications for log data characteristic (to receive chunks)
  Future<void> _setupLogDataNotifications() async {
    if (_logDataCharacteristic == null) return;
    await _logDataCharacteristic!.setNotifyValue(true);
    _logDataSubscription = _logDataCharacteristic!.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        final String chunk = utf8.decode(value);
        debugPrint("[LOG CHUNK] Received chunk: $chunk");

        if (chunk == "END") {
          debugPrint("[LOG CHUNK] End of log data transfer detected.");
          // Transfer zakończony, spróbuj sparsować pełny JSON
          if (_logDataCompleter != null && !_logDataCompleter!.isCompleted) {
            try {
              final List<dynamic> jsonList = jsonDecode(_receivedLogJson);
              final List<LogDataPoint> logPoints = jsonList.map((e) => LogDataPoint.fromJson(e)).toList();
              _logDataCompleter!.complete(logPoints);
              debugPrint("[LOG CHUNK] Successfully parsed ${logPoints.length} log points.");
            } catch (e) {
              debugPrint("[LOG CHUNK ERROR] Error decoding full log JSON: $e, Raw data: $_receivedLogJson");
              _logDataCompleter!.completeError([]); // Zwróć pustą listę w przypadku błędu parsowania
            } finally {
              _receivedLogJson = ""; // Wyczyść bufor
            }
          } else {
            debugPrint("[LOG CHUNK ERROR] Completer not ready or already completed.");
          }
        } else {
          // Kontynuuj zbieranie fragmentów
          _receivedLogJson += chunk;
        }
      } else {
        debugPrint("Received empty value from Log Data Characteristic (chunk).");
      }
    });
    debugPrint("Notifications enabled for Log Data (chunks).");
  }


  // Send a control command to the ESP32 device
  Future<void> sendControlCommand(String command) async {
    if (_controlCharacteristic == null) {
      debugPrint("Control Characteristic not found.");
      return;
    }
    try {
      await _controlCharacteristic!.write(utf8.encode(command), withoutResponse: true);
      debugPrint("Sent command: $command");
    } catch (e) {
      debugPrint("Error sending command $command: $e");
    }
  }

  // Request and read log data from the ESP32 device using NOTIFY chunks
  Future<List<LogDataPoint>> readLogData() async {
    if (_logDataCharacteristic == null || _controlCharacteristic == null) {
      debugPrint("Log Data or Control Characteristic not found.");
      return [];
    }

    _receivedLogJson = ""; // Wyczyść bufor przed nowym transferem
    _logDataCompleter = Completer<List<LogDataPoint>>(); // Utwórz nowy Completer

    try {
      debugPrint("Sending REQUEST_LOGS command to ESP32...");
      await sendControlCommand("REQUEST_LOGS"); // Wysyłamy komendę, aby ESP32 zaczął wysyłać logi

      // Czekaj na zakończenie transferu logów
      // Zwiększono timeout dla dużych logów danych
      final List<LogDataPoint> logPoints = await _logDataCompleter!.future.timeout(const Duration(seconds: 60), onTimeout: () {
        debugPrint("[LOG CHUNK TIMEOUT] Log data transfer timed out.");
        _receivedLogJson = ""; // Wyczyść bufor w przypadku timeoutu
        return []; // Zwróć pustą listę w przypadku timeoutu
      });

      debugPrint("Received ${logPoints.length} log points.");
      return logPoints;
    } catch (e) {
      debugPrint("Error during log data transfer: $e");
      _receivedLogJson = ""; // Wyczyść bufor w przypadku błędu
      return [];
    }
  }

  // Read device info from the ESP32 device
  Future<Map<String, dynamic>> readDeviceInfo() async {
    if (_deviceInfoCharacteristic == null) {
      debugPrint("Device Info Characteristic not found.");
      return {};
    }
    try {
      final List<int> value = await _deviceInfoCharacteristic!.read();
      final String jsonString = utf8.decode(value);
      debugPrint("Received device info (from ESP32): $jsonString");
      return jsonDecode(jsonString);
    } catch (e) {
      debugPrint("Error reading device info: $e");
      return {};
    }
  }

  // Nowy getter do obliczania procentu baterii
  double get batteryPercentage {
    if (_currentGpsData.battery == null) return 0.0; // Zwróć 0% jeśli brak danych

    // Typowe napięcia dla LiPo 1S
    const double minVoltage = 3.3; // Napięcie dla 0% (rozładowana, ale bezpieczna)
    const double maxVoltage = 4.2; // Napięcie dla 100% (pełna)

    // Oblicz procent
    double percentage = ((_currentGpsData.battery! - minVoltage) / (maxVoltage - minVoltage)) * 100;
    
    // Ogranicz wynik do zakresu 0-100
    return percentage.clamp(0.0, 100.0);
  }

  // NOWE METODY DO ZMIANY TRYBU NA ESP32 DLA OPTYMALIZACJI BATERII
  // Wysyła komendę do ESP32, aby wszedł w tryb Speed Master (częściej aktualizacje)
  Future<void> setSpeedMasterMode() async {
    debugPrint("Sending command: SET_MODE:SPEEDMASTER");
    await sendControlCommand("SET_MODE:SPEEDMASTER");
  }

  // Wysyła komendę do ESP32, aby wszedł w tryb Treningu (rzadziej aktualizacje, oszczędność baterii)
  Future<void> setTrainingMode() async {
    debugPrint("Sending command: SET_MODE:TRAINING");
    await sendControlCommand("SET_MODE:TRAINING");
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _currentDataSubscription?.cancel();
    _logDataSubscription?.cancel(); // Cancel log data subscription on dispose
    disconnect(); 
    super.dispose();
  }
}

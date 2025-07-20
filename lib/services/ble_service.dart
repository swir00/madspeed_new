import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:madspeed_app/models/gps_data.dart'; // Upewnij się, że ścieżka jest poprawna
import 'package:madspeed_app/models/log_data_point.dart'; // Upewnij się, że ścieżka jest poprawna

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
  String _receivedLogDataContent = ""; // Will hold comma-separated JSON objects
  Completer<List<LogDataPoint>>? _logDataCompleter; // Used to await log transfer completion
  int _totalExpectedLogPoints = 0; // Przechowuje całkowitą liczbę oczekiwanych punktów (linii)
  int _receivedLogPointsCount = 0; // Licznik odebranych punktów logu

  // Wskaźnik postępu transferu logów
  final ValueNotifier<double> _logTransferProgress = ValueNotifier(0.0);
  ValueNotifier<double> get logTransferProgress => _logTransferProgress;


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
          // Jeśli transfer logów był aktywny i połączenie zostało utracone, zakończ completer z błędem.
          if (_logDataCompleter != null && !_logDataCompleter!.isCompleted) {
            _logDataCompleter!.completeError(Exception("BLE disconnected during log transfer."));
            _logDataCompleter = null; // Clear completer
          }
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

    // Wyczyść również status transferu logów w przypadku rozłączenia
    _receivedLogDataContent = "";
    _totalExpectedLogPoints = 0;
    _receivedLogPointsCount = 0;
    _logTransferProgress.value = 0.0;
    if (_logDataCompleter != null && !_logDataCompleter!.isCompleted) {
      _logDataCompleter!.completeError(Exception("Disconnected before log transfer completion."));
    }
    _logDataCompleter = null;
  }

  // Discover services and characteristics on the connected device
  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    debugPrint("Discovered ${services.length} services.");

    for (var service in services) {
      if (service.uuid.toString().toUpperCase() == SERVICE_UUID.toUpperCase()) {
        debugPrint("Found MadSpeed Service: ${service.uuid}");
        for (var characteristic in service.characteristics) {
          debugPrint("   Characteristic: ${characteristic.uuid}");
          if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_CURRENT_DATA.toUpperCase()) {
            _currentDataCharacteristic = characteristic;
            await _setupCurrentDataNotifications();
            debugPrint("     Current Data Characteristic found and notifications enabled.");
          } else if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_CONTROL.toUpperCase()) {
            _controlCharacteristic = characteristic;
            debugPrint("     Control Characteristic found.");
          } else if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_LOG_DATA.toUpperCase()) {
            _logDataCharacteristic = characteristic;
            debugPrint("     Log Data Characteristic found. (Now NOTIFY)");
            await _setupLogDataNotifications(); // Setup notifications for log chunks
          } else if (characteristic.uuid.toString().toUpperCase() == CHAR_UUID_DEVICE_INFO.toUpperCase()) {
            _deviceInfoCharacteristic = characteristic;
            debugPrint("     Device Info Characteristic found.");
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
          // debugPrint("Raw CurrentData JSON (from ESP32): $jsonString"); // Opcjonalnie odkomentuj dla debugowania
          final Map<String, dynamic> data = jsonDecode(jsonString);
          _currentGpsData = GPSData.fromJson(data);
          // debugPrint("Parsed GPSData - Current Speed: ${_currentGpsData.currentSpeed}"); // Opcjonalnie odkomentuj dla debugowania
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

  // Set up notifications for log data characteristic (to receive single JSON objects)
  Future<void> _setupLogDataNotifications() async {
    if (_logDataCharacteristic == null) return;
    await _logDataCharacteristic!.setNotifyValue(true);
    _logDataSubscription = _logDataCharacteristic!.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        final String receivedData = utf8.decode(value);
        debugPrint("[LOG CHUNK DEBUG] Received: ${receivedData.length} bytes. Content preview: ${receivedData.substring(0, receivedData.length > 50 ? 50 : receivedData.length)}...");

        if (receivedData.startsWith("METADATA_LINES:")) {
          _totalExpectedLogPoints = int.tryParse(receivedData.substring("METADATA_LINES:".length)) ?? 0;
          debugPrint("[LOG DATA] Received METADATA: Total expected LINES $_totalExpectedLogPoints.");
          _receivedLogDataContent = ""; // Ensure buffer is clear before receiving data
          _receivedLogPointsCount = 0; // Reset point counter
          _logTransferProgress.value = 0.0; // Reset progress
        }
        // Obsługa sygnałów zakończenia transferu
        else if (receivedData == "END_LOG_TRANSFER") {
          debugPrint("[LOG DATA] Otrzymano END_LOG_TRANSFER, transfer zakończony pomyślnie.");
          if (_logDataCompleter != null && !_logDataCompleter!.isCompleted) {
            _logTransferProgress.value = 1.0; // Upewnij się, że postęp jest na 100%
            try {
              // Finalize the JSON string: add outer brackets for the complete array
              final String fullLogJson = "[${_receivedLogDataContent}]";
              // Jeśli bufor jest pusty, a oczekiwano danych, to błąd
              if (_receivedLogDataContent.isEmpty && _totalExpectedLogPoints > 0) {
                 _logDataCompleter!.completeError(Exception("Expected log data but received none before END_LOG_TRANSFER."));
                 debugPrint("[LOG DATA ERROR] Oczekiwano danych, ale bufor jest pusty po END_LOG_TRANSFER.");
              } else if (_receivedLogDataContent.isEmpty && _totalExpectedLogPoints == 0) {
                // To jest przypadek, gdy plik logów jest pusty, ale nie wysłano END_EMPTY_LOG
                _logDataCompleter!.complete([]);
                debugPrint("[LOG DATA] Transfer zakończony (END_LOG_TRANSFER) z pustym logiem.");
              } else {
                final List<dynamic> jsonList = jsonDecode(fullLogJson);
                final List<LogDataPoint> logPoints = jsonList.map((e) => LogDataPoint.fromJson(e)).toList();
                _logDataCompleter!.complete(logPoints);
                debugPrint("[LOG DATA] Pomyślnie sparsowano ${logPoints.length} punktów logu.");
              }
            } catch (e) {
              debugPrint("[LOG DATA ERROR] Błąd dekodowania pełnego logu JSON po END_LOG_TRANSFER: $e");
              debugPrint("[LOG DATA ERROR] Problematic JSON content (truncated): ${_receivedLogDataContent.substring(0, _receivedLogDataContent.length > 500 ? 500 : _receivedLogDataContent.length)}...");
              _logDataCompleter!.completeError(
                Exception("Nie udało się sparsować danych logu po zakończeniu transferu: $e")
              );
            } finally {
              _receivedLogDataContent = ""; // Wyczyść bufor
              _totalExpectedLogPoints = 0; // Resetuj całkowity rozmiar
              _receivedLogPointsCount = 0; // Resetuj licznik
            }
          } else {
            debugPrint("[LOG DATA WARNING] Completer nie jest gotowy lub już zakończony po END_LOG_TRANSFER.");
          }
        } else if (receivedData == "END_EMPTY_LOG") {
          debugPrint("[LOG DATA] Otrzymano END_EMPTY_LOG, zwrócono pustą listę.");
          if (_logDataCompleter != null && !_logDataCompleter!.isCompleted) {
            _logTransferProgress.value = 1.0; // Postęp na 100%
            _logDataCompleter!.complete([]); // Zakończ od razu z pustą listą
            _receivedLogDataContent = ""; // Wyczyść bufor
            _totalExpectedLogPoints = 0; // Resetuj całkowity rozmiar
            _receivedLogPointsCount = 0; // Resetuj licznik
          } else {
            debugPrint("[LOG DATA WARNING] Completer nie jest gotowy lub już zakończony po END_EMPTY_LOG.");
          }
        }
        else if (receivedData.startsWith('{') && receivedData.endsWith('}')) { // ONLY append if it looks like a JSON object
          // It's a single JSON object (e.g., {"timestamp":123,...})
          // Add a comma only if it's not the first object
          if (_receivedLogDataContent.isNotEmpty) {
            _receivedLogDataContent += ",";
          }
          _receivedLogDataContent += receivedData; // Append the raw JSON object
          _receivedLogPointsCount++; // Increment count

          if (_totalExpectedLogPoints > 0) {
            _logTransferProgress.value = (_receivedLogPointsCount / _totalExpectedLogPoints).clamp(0.0, 1.0);
            // debugPrint("[LOG DATA DEBUG] Progress: ${_logTransferProgress.value}"); // Opcjonalnie odkomentuj dla debugowania
          } else {
            // Fallback for indeterminate progress if total count not yet known
            // This might happen if METADATA_LINES was missed for some reason,
            // or if the file has 0 lines (which is covered by END_EMPTY_LOG, so not an issue here)
            // It just means the progress bar won't be accurate, but transfer should still complete.
            debugPrint("[LOG DATA DEBUG] Progress indeterminate (_totalExpectedLogPoints is 0).");
          }
        } else if (receivedData.startsWith('ERROR:')) {
          debugPrint("[LOG DATA ERROR] Received error from ESP32: $receivedData");
          if (_logDataCompleter != null && !_logDataCompleter!.isCompleted) {
            _logDataCompleter!.completeError(Exception("ESP32 error during log transfer: $receivedData"));
          }
        } else {
          debugPrint("[LOG DATA WARNING] Received unexpected data format, skipping: $receivedData");
        }
      } else {
        debugPrint("Received empty value from Log Data Characteristic.");
      }
    });
    debugPrint("Notifications enabled for Log Data (single JSON objects).");
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

  // Request and read log data from the ESP32 device using NOTIFY (single JSON objects)
  Future<List<LogDataPoint>> readLogData() async {
    if (_logDataCharacteristic == null || _controlCharacteristic == null) {
      debugPrint("Log Data or Control Characteristic not found.");
      return [];
    }

    // Resetuj stan przed nowym transferem
    _receivedLogDataContent = "";
    _totalExpectedLogPoints = 0;
    _receivedLogPointsCount = 0;
    _logTransferProgress.value = 0.0;
    _logDataCompleter = Completer<List<LogDataPoint>>(); // Utwórz nowy Completer

    try {
      debugPrint("Sending REQUEST_LOGS command to ESP32...");
      await sendControlCommand("REQUEST_LOGS"); // Wysyłamy komendę, aby ESP32 zaczął wysyłać logi

      // Czekaj na zakończenie transferu logów
      // Zwiększono timeout dla dużych logów danych, aby dać ESP32 czas na wysłanie wszystkich fragmentów
      final List<LogDataPoint> logPoints = await _logDataCompleter!.future.timeout(const Duration(seconds: 180), onTimeout: () { // Zwiększono timeout do 180 sekund (3 minuty)
        debugPrint("[LOG DATA TIMEOUT] Log data transfer timed out.");
        throw TimeoutException("Log data transfer timed out."); // Rzuć rzeczywisty błąd
      });

      debugPrint("Received ${logPoints.length} log points.");
      _logTransferProgress.value = 0.0; // Upewnij się, że postęp jest zresetowany po zakończeniu
      return logPoints;
    } catch (e) {
      debugPrint("Error during log data transfer: $e");
      // Upewnij się, że stan jest zresetowany w przypadku błędu
      _receivedLogDataContent = "";
      _totalExpectedLogPoints = 0;
      _receivedLogPointsCount = 0;
      _logTransferProgress.value = 0.0;
      return []; // Zwróć pustą listę w przypadku błędu
    } finally {
      // Upewnij się, że Completer jest zawsze "zwolniony"
      _logDataCompleter = null;
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
    // Zakończ completer, jeśli jest aktywny, aby uniknąć wiszących przyszłości
    if (_logDataCompleter != null && !_logDataCompleter!.isCompleted) {
      _logDataCompleter!.completeError(Exception("BLEService disposed."));
    }
    disconnect(); // Upewnij się, że wszystko jest odłączone
    super.dispose();
  }
}
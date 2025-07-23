import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:madspeed_app/models/dog_profile.dart';
import 'package:madspeed_app/models/walk_session_model.dart';
import 'package:madspeed_app/database/database_helper.dart';
import 'package:madspeed_app/utils/walk_session_helper.dart'; // Upewnij się, że ta ścieżka jest poprawna
import 'package:uuid/uuid.dart';

enum GpsStatus {
  unknown,
  searching,
  ready,
  permissionDenied,
  serviceDisabled,
}

class DogWalkScreen extends StatefulWidget {
  const DogWalkScreen({super.key});

  @override
  State<DogWalkScreen> createState() => _DogWalkScreenState();
}

class _DogWalkScreenState extends State<DogWalkScreen> {
  bool _isWalking = false;
  bool _isPaused = false;
  List<DogProfile> _selectedDogs = [];
  List<DogProfile> _allDogs = [];

  // Statystyki spaceru
  Duration _duration = Duration.zero;
  double _distance = 0.0; // w metrach
  List<LatLng> _routePoints = [];
  LatLng? _startLocation;

  // Obiekty do obsługi logiki
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _serviceStatusStream;

  // Status GPS
  GpsStatus _gpsStatus = GpsStatus.unknown;

  @override
  void initState() {
    super.initState();
    _loadDogs();
    _initializeGps();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    _serviceStatusStream?.cancel();
    super.dispose();
  }

  Future<void> _loadDogs() async {
    final dbHelper = DatabaseHelper.instance;
    final dogs = await dbHelper.getDogProfiles();
    setState(() {
      _allDogs = dogs;
    });
  }

  Future<void> _initializeGps() async {
    _serviceStatusStream = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (mounted) {
        setState(() {
          _gpsStatus = (status == ServiceStatus.enabled) ? GpsStatus.searching : GpsStatus.serviceDisabled;
        });
        if (status == ServiceStatus.enabled) {
          _checkGpsPermission();
        }
      }
    });
    await _checkGpsPermission();
  }

  Future<void> _checkGpsPermission() async {
    if (mounted) setState(() => _gpsStatus = GpsStatus.searching);

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _gpsStatus = GpsStatus.serviceDisabled);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _gpsStatus = GpsStatus.permissionDenied);
      return;
    }

    if (permission == LocationPermission.denied) {
      if (mounted) setState(() => _gpsStatus = GpsStatus.permissionDenied);
      return;
    }

    // Jeśli wszystko jest w porządku, status jest gotowy
    if (mounted) setState(() => _gpsStatus = GpsStatus.ready);
  }

  void _startWalk() async {
    setState(() {
      _isWalking = true;
      _isPaused = false;
      _duration = Duration.zero;
      _distance = 0.0;
      _routePoints.clear();
      _startLocation = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _duration = Duration(seconds: _duration.inSeconds + 1);
        });
      }
    });

    // Start śledzenia GPS
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // aktualizuj co 10 metrów
      // Ustawienia dla Androida, aby utrzymać działanie w tle
      forceLocationManager: true,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "Spacer w toku",
        notificationText: "Aplikacja MadSpeed śledzi Twoją trasę.",
        // Użyj ikony startowej aplikacji. W przyszłości można dodać dedykowaną ikonę.
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        enableWakeLock: true,
      ),
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (mounted) {
        // Zapisz lokalizację startową przy pierwszej aktualizacji
        if (_startLocation == null) {
          _startLocation = LatLng(position.latitude, position.longitude);
        }

        final newPoint = LatLng(position.latitude, position.longitude);
        setState(() {
          if (_routePoints.isNotEmpty) {
            _distance += Geolocator.distanceBetween(
              _routePoints.last.latitude,
              _routePoints.last.longitude,
              newPoint.latitude,
              newPoint.longitude,
            );
          }
          _routePoints.add(newPoint);
        });
      }
    });
  }

  void _pauseWalk() {
    if (!_isWalking || _isPaused) return;
    _timer?.cancel();
    _positionStream?.pause();
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeWalk() {
    if (!_isWalking || !_isPaused) return;
    _positionStream?.resume();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _duration = Duration(seconds: _duration.inSeconds + 1);
        });
      }
    });
    setState(() {
      _isPaused = false;
    });
  }

  void _stopWalk() {
    _timer?.cancel();
    _positionStream?.cancel();
    setState(() {
      _isWalking = false;
      _isPaused = false;
    });
    _showSaveDialog();
  }

  Future<void> _showSaveDialog() async {
    final TextEditingController nameController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Zakończono spacer'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Dystans: ${(_distance / 1000).toStringAsFixed(2)} km'),
                Text('Czas: ${_formatDuration(_duration)}'),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Nazwa spaceru',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Odrzuć'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              child: const Text('Zapisz'),
              onPressed: () {
                _saveSession(nameController.text.isNotEmpty
                    ? nameController.text
                    : 'Spacer z psem');
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveSession(String sessionName) async {
    final newSession = WalkSession(
      id: const Uuid().v4(),
      name: sessionName,
      date: DateTime.now(),
      dogIds: _selectedDogs.map((d) => d.id).toList(),
      duration: _duration,
      distance: _distance,
      routePoints: List.from(_routePoints), // Tworzymy kopię listy
      startLocation: _startLocation,
    );

    await WalkSessionHelper.saveWalkSession(newSession);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spacer został zapisany!')),
      );
    }
  }

  String _formatDuration(Duration d) {
    final twoDigitMinutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final twoDigitSeconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showDogSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        List<DogProfile> tempSelectedDogs = List.from(_selectedDogs);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Wybierz psy'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allDogs.length,
                  itemBuilder: (context, index) {
                    final dog = _allDogs[index];
                    final isSelected = tempSelectedDogs.contains(dog);
                    return CheckboxListTile(
                      title: Text(dog.name),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelectedDogs.add(dog);
                          } else {
                            tempSelectedDogs.remove(dog);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedDogs = tempSelectedDogs;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Zatwierdź'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spacer z psem'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Górna część - wybór psów i statystyki
            _isWalking ? _buildWalkingUI() : _buildSetupUI(),

            // Dolna część - przyciski akcji
            _isWalking ? _buildWalkingActionButtons() : _buildStartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupUI() {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.pets),
          label: const Text('Wybierz psy'),
          onPressed: _showDogSelectionDialog,
        ),
        const SizedBox(height: 20),
        Text(
          _selectedDogs.isEmpty
              ? 'Nie wybrano żadnego psa.'
              : 'Wybrane psy: ${_selectedDogs.map((d) => d.name).join(', ')}',
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        _buildGpsStatusIndicator(),
      ],
    );
  }

  Widget _buildGpsStatusIndicator() {
    IconData icon;
    String message;
    Color color;

    switch (_gpsStatus) {
      case GpsStatus.searching:
        icon = Icons.gps_not_fixed;
        message = 'Szukanie sygnału GPS...';
        color = Colors.orange;
        break;
      case GpsStatus.ready:
        icon = Icons.gps_fixed;
        message = 'GPS gotowy do startu';
        color = Colors.green;
        break;
      case GpsStatus.permissionDenied:
        icon = Icons.gps_off;
        message = 'Brak uprawnień do lokalizacji';
        color = Colors.red;
        break;
      case GpsStatus.serviceDisabled:
        icon = Icons.location_disabled;
        message = 'Usługi lokalizacji są wyłączone';
        color = Colors.red;
        break;
      default:
        icon = Icons.gps_off;
        message = 'Sprawdzanie statusu GPS...';
        color = Colors.grey;
    }

    return Column(
      children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 8),
        Text(message, style: TextStyle(fontSize: 16, color: color)),
      ],
    );
  }

  Widget _buildWalkingUI() {
    return Column(
      children: [
        Text(
          _isPaused ? 'Spacer wstrzymany' : 'Spacer w toku...',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _isPaused ? Colors.orange : null,
              ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatCard('Czas', _formatDuration(_duration)),
            _buildStatCard('Dystans', '${(_distance / 1000).toStringAsFixed(2)} km'),
          ],
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: const Text('Rozpocznij spacer'),
        onPressed: (_selectedDogs.isNotEmpty && _gpsStatus == GpsStatus.ready)
            ? _startWalk
            : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildWalkingActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(_isPaused ? 'Wznów' : 'Pauza'),
            onPressed: _isPaused ? _resumeWalk : _pauseWalk,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Zakończ'),
            onPressed: _stopWalk,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 20),
              backgroundColor: Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}
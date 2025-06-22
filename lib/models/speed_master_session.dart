import 'dart:convert';
import 'package:madspeed_app/models/log_data_point.dart'; // Upewnij się, że ten import jest potrzebny, jeśli SpeedMasterSession będzie miał logData

class SpeedMasterSession {
  final String id;
  final String name;
  final double maxSpeed;
  final double distance;
  final double averageSpeed; // NOWE POLE
  final DateTime timestamp;

  SpeedMasterSession({
    required this.id,
    required this.name,
    required this.maxSpeed,
    required this.distance,
    required this.averageSpeed, // Uaktualniony konstruktor
    required this.timestamp,
  });

  // Factory constructor for deserialization
  factory SpeedMasterSession.fromJson(Map<String, dynamic> json) {
    return SpeedMasterSession(
      id: json['id'],
      name: json['name'],
      maxSpeed: (json['maxSpeed'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble() ?? 0.0, // Bezpieczne odczytywanie, domyślne 0.0
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  // Method for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'maxSpeed': maxSpeed,
      'distance': distance,
      'averageSpeed': averageSpeed, // Uaktualniona serializacja
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static List<SpeedMasterSession> decode(String sessions) =>
      (json.decode(sessions) as List<dynamic>)
          .map<SpeedMasterSession>((item) => SpeedMasterSession.fromJson(item as Map<String, dynamic>))
          .toList();

  static String encode(List<SpeedMasterSession> sessions) => json.encode(
      sessions.map<Map<String, dynamic>>((item) => item.toJson()).toList());
}

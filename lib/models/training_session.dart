import 'dart:convert';
import 'package:madspeed_app/models/log_data_point.dart';

class TrainingSession {
  final String id;
  final String name;
  final double maxSpeed;
  final double distance;
  final double averageSpeed;
  final DateTime timestamp;
  final int duration; // NOWE POLE: czas trwania w sekundach
  final List<LogDataPoint> logData; // Logged points for chart

  TrainingSession({
    required this.id,
    required this.name,
    required this.maxSpeed,
    required this.distance,
    required this.averageSpeed,
    required this.timestamp,
    required this.duration, // Uaktualniony konstruktor
    required this.logData,
  });

  // Factory constructor for deserialization
  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'],
      name: json['name'],
      maxSpeed: (json['maxSpeed'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      averageSpeed: (json['averageSpeed'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      // ZMIANA TUTAJ: Użyj operatora ?? aby ustawić wartość domyślną (0) jeśli json['duration'] jest null
      duration: json['duration'] as int? ?? 0, 
      logData: (json['logData'] as List<dynamic>)
          .map((e) => LogDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Method for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'maxSpeed': maxSpeed,
      'distance': distance,
      'averageSpeed': averageSpeed,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration, // Uaktualniona serializacja
      'logData': logData.map((e) => e.toJson()).toList(),
    };
  }

  static List<TrainingSession> decode(String sessions) =>
      (json.decode(sessions) as List<dynamic>)
          .map<TrainingSession>((item) => TrainingSession.fromJson(item as Map<String, dynamic>)) // Dodano rzutowanie
          .toList();

  static String encode(List<TrainingSession> sessions) => json.encode(
      sessions.map<Map<String, dynamic>>((item) => item.toJson()).toList());
}

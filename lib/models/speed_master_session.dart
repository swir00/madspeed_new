import 'dart:convert';

class SpeedMasterSession {
  final String id;
  final String name;
  final double maxSpeed;
  final double distance;
  final double averageSpeed;
  final DateTime timestamp;

  SpeedMasterSession({
    required this.id,
    required this.name,
    required this.maxSpeed,
    required this.distance,
    required this.averageSpeed,
    required this.timestamp,
  });

  factory SpeedMasterSession.fromJson(Map<String, dynamic> json) {
    return SpeedMasterSession(
      id: json['id'],
      name: json['name'],
      maxSpeed: (json['maxSpeed'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      averageSpeed: (json['averageSpeed'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'maxSpeed': maxSpeed,
      'distance': distance,
      'averageSpeed': averageSpeed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static List<SpeedMasterSession> decode(String sessions) =>
      (json.decode(sessions) as List<dynamic>)
          .map<SpeedMasterSession>((item) => SpeedMasterSession.fromJson(item))
          .toList();

  static String encode(List<SpeedMasterSession> sessions) => json.encode(
      sessions.map<Map<String, dynamic>>((item) => item.toJson()).toList());
}

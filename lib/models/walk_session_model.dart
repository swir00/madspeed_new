import 'dart:convert';
import 'package:latlong2/latlong.dart';

class WalkSession {
  final String id;
  final String name;
  final DateTime date;
  final List<int?> dogIds;
  final Duration duration;
  final double distance; // w metrach
  final List<LatLng> routePoints;
  final LatLng? startLocation;

  WalkSession({
    required this.id,
    required this.name,
    required this.date,
    required this.dogIds,
    required this.duration,
    required this.distance,
    required this.routePoints,
    this.startLocation,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'dogIds': dogIds,
        'duration': duration.inSeconds,
        'distance': distance,
        'routePoints': routePoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'startLocation': startLocation != null
            ? {'lat': startLocation!.latitude, 'lng': startLocation!.longitude}
            : null,
      };

  factory WalkSession.fromJson(Map<String, dynamic> json) {
    var routePointsList = json['routePoints'] as List;
    List<LatLng> points =
        routePointsList.map((p) => LatLng(p['lat'], p['lng'])).toList();

    LatLng? location;
    if (json['startLocation'] != null) {
      location = LatLng(json['startLocation']['lat'], json['startLocation']['lng']);
    }

    return WalkSession(
      id: json['id'],
      name: json['name'],
      date: DateTime.parse(json['date']),
      dogIds: List<int?>.from(json['dogIds']),
      duration: Duration(seconds: json['duration']),
      distance: json['distance'].toDouble(),
      routePoints: points,
      startLocation: location,
    );
  }

  static String encode(List<WalkSession> sessions) => json.encode(sessions.map<Map<String, dynamic>>((s) => s.toJson()).toList());
  static List<WalkSession> decode(String sessions) => (json.decode(sessions) as List<dynamic>).map<WalkSession>((item) => WalkSession.fromJson(item)).toList();

  WalkSession copyWith({
    String? id,
    String? name,
    DateTime? date,
    List<int?>? dogIds,
    Duration? duration,
    double? distance,
    List<LatLng>? routePoints,
    LatLng? startLocation,
  }) {
    return WalkSession(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      dogIds: dogIds ?? this.dogIds,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      routePoints: routePoints ?? this.routePoints,
      startLocation: startLocation ?? this.startLocation,
    );
  }
}
// lib/models/training_session.dart

import 'dart:convert';
import 'package:madspeed_app/models/log_data_point.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // NOWY IMPORT

class TrainingSession {
  final String id;
  final String name;
  final double maxSpeed;
  final double distance; // W metrach
  final double averageSpeed;
  final DateTime timestamp;
  final int duration; // Czas trwania w sekundach
  final List<LogDataPoint> logData;
  final int? dogId;
  final LatLng? startLocation; // NOWE POLE: Lokalizacja startowa treningu

  TrainingSession({
    required this.id,
    required this.name,
    required this.maxSpeed,
    required this.distance,
    required this.averageSpeed,
    required this.timestamp,
    required this.duration,
    required this.logData,
    this.dogId,
    this.startLocation, // Dodano do konstruktora
  });

  // Konwersja obiektu na Mapę (do zapisu w SharedPreferences)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'maxSpeed': maxSpeed,
        'distance': distance,
        'averageSpeed': averageSpeed,
        'timestamp': timestamp.toIso8601String(),
        'duration': duration,
        'logData': logData.map((e) => e.toJson()).toList(),
        'dogId': dogId,
        'startLocation': startLocation != null
            ? {'latitude': startLocation!.latitude, 'longitude': startLocation!.longitude}
            : null, // Zapisz lokalizację
      };

  // Konwersja Mapy na obiekt (do odczytu z SharedPreferences)
  factory TrainingSession.fromJson(Map<String, dynamic> json) => TrainingSession(
        id: json['id'] as String,
        name: json['name'] as String,
        maxSpeed: json['maxSpeed'] as double,
        distance: json['distance'] as double,
        averageSpeed: json['averageSpeed'] as double,
        timestamp: DateTime.parse(json['timestamp'] as String),
        duration: json['duration'] as int,
        logData: (json['logData'] as List)
            .map((e) => LogDataPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        dogId: json['dogId'] as int?,
        startLocation: json['startLocation'] != null
            ? LatLng(json['startLocation']['latitude'] as double, json['startLocation']['longitude'] as double)
            : null, // Odczyt lokalizacji
      );

  // Metody do kodowania i dekodowania listy sesji treningowych
  static String encode(List<TrainingSession> sessions) => json.encode(
        sessions.map<Map<String, dynamic>>((session) => session.toJson()).toList(),
      );

  static List<TrainingSession> decode(String sessionsJson) =>
      (json.decode(sessionsJson) as List<dynamic>)
          .map<TrainingSession>((item) => TrainingSession.fromJson(item as Map<String, dynamic>))
          .toList();
}

// lib/models/training.dart

import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Training {
  int? id;
  DateTime startTime;
  DateTime endTime;
  double distance; // in meters
  double avgSpeed; // in km/h
  double maxSpeed; // in km/h
  List<LatLng> path;
  int? dogId;

  Training({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.path,
    this.dogId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'distance': distance,
      'avgSpeed': avgSpeed,
      'maxSpeed': maxSpeed,
      'path': jsonEncode(path.map((e) => {'latitude': e.latitude, 'longitude': e.longitude}).toList()),
      'dogId': dogId,
    };
  }

  factory Training.fromMap(Map<String, dynamic> map) {
    return Training(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      distance: map['distance'] as double,
      avgSpeed: map['avgSpeed'] as double,
      maxSpeed: map['maxSpeed'] as double,
      path: (jsonDecode(map['path'] as String) as List)
          .map((e) => LatLng(e['latitude'] as double, e['longitude'] as double))
          .toList(),
      dogId: map['dogId'] as int?,
    );
  }

  Training copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    double? distance,
    double? avgSpeed,
    double? maxSpeed,
    List<LatLng>? path,
    int? dogId,
  }) {
    return Training(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distance: distance ?? this.distance,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      path: path ?? this.path,
      dogId: dogId ?? this.dogId,
    );
  }
}

class GPSData {
  double? latitude;
  double? longitude;
  double? altitude;
  int? satellites;
  double? hdop;
  double? currentSpeed;
  double? maxSpeed;
  double? avgSpeed;
  double? distance;
  int? gpsQualityLevel;
  double? battery;
  bool? isLoggingActive;

  GPSData({
    this.latitude,
    this.longitude,
    this.altitude,
    this.satellites,
    this.hdop,
    this.currentSpeed,
    this.maxSpeed,
    this.avgSpeed,
    this.distance,
    this.gpsQualityLevel,
    this.battery,
    this.isLoggingActive,
  });

  factory GPSData.fromJson(Map<String, dynamic> json) {
    return GPSData(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      satellites: json['satellites'] as int?,
      hdop: (json['hdop'] as num?)?.toDouble(),
      currentSpeed: (json['currentSpeed'] as num?)?.toDouble(),
      maxSpeed: (json['maxSpeed'] as num?)?.toDouble(),
      avgSpeed: (json['avgSpeed'] as num?)?.toDouble(),
      // ZMIANA TUTAJ: Bezpieczne parsowanie, jeśli ESP32 wysyłało jako string (chociaż teraz ESP32 wysyła jako liczbę)
      // W idealnym świecie json['distance'] będzie już num, ale ta linia jest odporna.
      distance: (json['distance'] is String)
          ? double.tryParse(json['distance'])
          : (json['distance'] as num?)?.toDouble(),
      gpsQualityLevel: json['gpsQualityLevel'] as int?,
      battery: (json['battery'] as num?)?.toDouble(),
      isLoggingActive: json['isLoggingActive'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'satellites': satellites,
      'hdop': hdop,
      'currentSpeed': currentSpeed,
      'maxSpeed': maxSpeed,
      'avgSpeed': avgSpeed,
      'distance': distance,
      'gpsQualityLevel': gpsQualityLevel,
      'battery': battery,
      'isLoggingActive': isLoggingActive,
    };
  }
}

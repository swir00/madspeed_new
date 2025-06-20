class GPSData {
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final int? satellites;
  final double? hdop;
  final double? currentSpeed;
  final double? maxSpeed;
  final double? avgSpeed;
  final double? distance;
  final int? gpsQualityLevel;
  final double? battery;
  final bool? isLoggingActive;

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
      distance: (json['distance'] as num?)?.toDouble(),
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

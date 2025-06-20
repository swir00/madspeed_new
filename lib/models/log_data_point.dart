class LogDataPoint {
  final int timestamp; // Czas w sekundach od startu ESP
  final double speed; // Prędkość w km/h
  final double distance; // Dystans w metrach
  final double? latitude; // NOWE: Szerokość geograficzna
  final double? longitude; // NOWE: Długość geograficzna

  LogDataPoint({
    required this.timestamp,
    required this.speed,
    required this.distance,
    this.latitude, // Zaznaczono jako opcjonalne, ale będzie wysyłane z ESP32
    this.longitude, // Zaznaczono jako opcjonalne, ale będzie wysyłane z ESP32
  });

  factory LogDataPoint.fromJson(Map<String, dynamic> json) {
    return LogDataPoint(
      timestamp: json['timestamp'] as int,
      speed: (json['speed'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(), // Parsowanie szerokości
      longitude: (json['longitude'] as num?)?.toDouble(), // Parsowanie długości
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'speed': speed,
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

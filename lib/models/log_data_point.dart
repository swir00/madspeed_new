class LogDataPoint {
  final int timestamp; // Czas w sekundach od startu ESP
  final double speed; // Prędkość w km/h
  final double distance; // Dystans w metrach

  LogDataPoint({
    required this.timestamp,
    required this.speed,
    required this.distance,
  });

  factory LogDataPoint.fromJson(Map<String, dynamic> json) {
    return LogDataPoint(
      timestamp: json['timestamp'] as int,
      speed: (json['speed'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'speed': speed,
      'distance': distance,
    };
  }
}

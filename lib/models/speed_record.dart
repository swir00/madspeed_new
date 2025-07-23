// lib/models/speed_record.dart

class SpeedRecord {
  int? id;
  double speed; // Prędkość w km/h
  String timestamp; // Data i czas rekordu, format ISO 8601

  SpeedRecord({
    this.id,
    required this.speed,
    required this.timestamp,
  });

  // Konwersja SpeedRecord na Mapę (do zapisu w bazie danych)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'speed': speed,
      'timestamp': timestamp,
    };
  }

  // Konwersja Mapy na SpeedRecord (do odczytu z bazy danych)
  factory SpeedRecord.fromMap(Map<String, dynamic> map) {
    return SpeedRecord(
      id: map['id'] as int?,
      speed: map['speed'] as double,
      timestamp: map['timestamp'] as String,
    );
  }
}

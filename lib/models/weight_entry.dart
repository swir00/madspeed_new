// lib/models/weight_entry.dart

class WeightEntry {
  int? id;
  int dogId;
  double weight;
  String timestamp;

  WeightEntry({
    this.id,
    required this.dogId,
    required this.weight,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dogId': dogId,
      'weight': weight,
      'timestamp': timestamp,
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'] as int?,
      dogId: map['dogId'] as int,
      weight: map['weight'] as double,
      timestamp: map['timestamp'] as String,
    );
  }
}

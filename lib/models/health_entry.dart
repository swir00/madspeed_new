// lib/models/health_entry.dart

class HealthEntry {
  int? id;
  int dogId; // ID psa, do którego należy wpis
  String title; // Krótki tytuł wpisu (np. "Wizyta u weterynarza", "Szczepienie", "Problemy z łapą")
  String? description; // Szczegółowy opis
  String entryDate; // Data wpisu (YYYY-MM-DD)
  String? category; // Kategoria wpisu (np. "Szczepienie", "Leczenie", "Dieta", "Ogólne")

  HealthEntry({
    this.id,
    required this.dogId,
    required this.title,
    this.description,
    required this.entryDate,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dogId': dogId,
      'title': title,
      'description': description,
      'entryDate': entryDate,
      'category': category,
    };
  }

  factory HealthEntry.fromMap(Map<String, dynamic> map) {
    return HealthEntry(
      id: map['id'] as int?,
      dogId: map['dogId'] as int,
      title: map['title'] as String,
      description: map['description'] as String?,
      entryDate: map['entryDate'] as String,
      category: map['category'] as String?,
    );
  }
}

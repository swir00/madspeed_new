// lib/models/dog_profile.dart

class DogProfile {
  int? id;
  String name;
  String? breed;
  String? dateOfBirth; // Format YYYY-MM-DD
  String? gender; // np. 'Male', 'Female'
  double? currentWeight; // Waga w kg
  String? activityLevel; // np. 'Low', 'Moderate', 'High'
  String? photoPath; // Ścieżka do zdjęcia psa na urządzeniu
  String? lastVaccinationDate; // Ostatnie szczepienie ogólne
  String? rabiesVaccinationDate; // Szczepienie na wściekliznę
  String? lastDewormingDate; // Ostatnie odrobaczenie

  // ==== DODANE POLA DOTYCZĄCE CELÓW FITNESS ====
  double? targetWeight; // Docelowa waga w kg
  double? dailyDistanceGoal; // Dzienny cel dystansu w metrach
  int? dailyDurationGoal; // Dzienny cel czasu aktywności w minutach
  // ===========================================

  DogProfile({
    this.id,
    required this.name,
    this.breed,
    this.dateOfBirth,
    this.gender,
    this.currentWeight,
    this.activityLevel,
    this.photoPath,
    this.lastVaccinationDate,
    this.rabiesVaccinationDate,
    this.lastDewormingDate,
    // ==== DODANE DO KONSTRUKTORA ====
    this.targetWeight,
    this.dailyDistanceGoal,
    this.dailyDurationGoal,
    // =================================
  });

  // Konwersja DogProfile na Mapę (do zapisu w bazie danych)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'currentWeight': currentWeight,
      'activityLevel': activityLevel,
      'photoPath': photoPath,
      'lastVaccinationDate': lastVaccinationDate,
      'rabiesVaccinationDate': rabiesVaccinationDate,
      'lastDewormingDate': lastDewormingDate,
      // ==== DODANE DO toMap ====
      'targetWeight': targetWeight,
      'dailyDistanceGoal': dailyDistanceGoal,
      'dailyDurationGoal': dailyDurationGoal,
      // ==========================
    };
  }

  // Konwersja Mapy na DogProfile (do odczytu z bazy danych)
  factory DogProfile.fromMap(Map<String, dynamic> map) {
    return DogProfile(
      id: map['id'] as int?,
      name: map['name'] as String,
      breed: map['breed'] as String?,
      dateOfBirth: map['dateOfBirth'] as String?,
      gender: map['gender'] as String?,
      currentWeight: map['currentWeight'] as double?,
      activityLevel: map['activityLevel'] as String?,
      photoPath: map['photoPath'] as String?,
      lastVaccinationDate: map['lastVaccinationDate'] as String?,
      rabiesVaccinationDate: map['rabiesVaccinationDate'] as String?,
      lastDewormingDate: map['lastDewormingDate'] as String?,
      // ==== DODANE DO fromMap ====
      targetWeight: map['targetWeight'] as double?,
      dailyDistanceGoal: map['dailyDistanceGoal'] as double?,
      dailyDurationGoal: map['dailyDurationGoal'] as int?,
      // ============================
    );
  }

  // Metoda do kopiowania obiektu z nowymi wartościami
  // Używamy nowej wartości, jeśli jest podana, w przeciwnym razie zachowujemy starą.
  // Dzięki temu można jawnie ustawić wartość na null, jeśli parametr jest null.
  DogProfile copyWith({
    int? id,
    String? name,
    String? breed,
    String? dateOfBirth,
    String? gender,
    double? currentWeight,
    String? activityLevel,
    String? photoPath,
    String? lastVaccinationDate,
    String? rabiesVaccinationDate,
    String? lastDewormingDate,
    // ==== DODANE DO copyWith ====
    double? targetWeight,
    double? dailyDistanceGoal,
    int? dailyDurationGoal,
    // ============================
  }) {
    return DogProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      dateOfBirth: dateOfBirth, // Teraz to pole może być ustawione na null przez copyWith
      gender: gender ?? this.gender,
      currentWeight: currentWeight ?? this.currentWeight,
      activityLevel: activityLevel ?? this.activityLevel,
      photoPath: photoPath ?? this.photoPath,
      lastVaccinationDate: lastVaccinationDate, // To pole może być ustawione na null
      rabiesVaccinationDate: rabiesVaccinationDate, // To pole może być ustawione na null
      lastDewormingDate: lastDewormingDate, // To pole może być ustawione na null
      // ==== DODANE DO copyWith ====
      targetWeight: targetWeight, // To pole może być ustawione na null
      dailyDistanceGoal: dailyDistanceGoal, // To pole może być ustawione na null
      dailyDurationGoal: dailyDurationGoal, // To pole może być ustawione na null
      // ============================
    );
  }
}

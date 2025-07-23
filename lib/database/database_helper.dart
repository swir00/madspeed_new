// lib/database/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:madspeed_app/models/training.dart';
import 'package:madspeed_app/models/speed_record.dart';
import 'package:madspeed_app/models/dog_profile.dart';
import 'package:madspeed_app/models/weight_entry.dart';
import 'package:madspeed_app/models/health_entry.dart';

class DatabaseHelper {
  static Database? _database;
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Zwiększ wersję bazy danych, aby wywołać onUpgrade i dodać nowe kolumny/tabele
  static const int _databaseVersion = 5; // Zmieniono z 4 na 5

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'madspeed_database.db');
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE training(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        distance REAL NOT NULL,
        avgSpeed REAL NOT NULL,
        maxSpeed REAL NOT NULL,
        path TEXT NOT NULL,
        dogId INTEGER,
        FOREIGN KEY (dogId) REFERENCES dog_profiles (id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE speed_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        speed REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE dog_profiles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        breed TEXT,
        dateOfBirth TEXT,
        gender TEXT,
        currentWeight REAL,
        activityLevel TEXT,
        photoPath TEXT,
        targetWeight REAL,
        dailyDistanceGoal REAL,
        dailyDurationGoal INTEGER,
        lastVaccinationDate TEXT,
        rabiesVaccinationDate TEXT, -- NOWA KOLUMNA
        lastDewormingDate TEXT -- NOWA KOLUMNA
      )
    ''');
    await db.execute('''
      CREATE TABLE weight_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dogId INTEGER NOT NULL,
        weight REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (dogId) REFERENCES dog_profiles (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE health_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dogId INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        entryDate TEXT NOT NULL,
        category TEXT,
        FOREIGN KEY (dogId) REFERENCES dog_profiles (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Logic for upgrading from version 1 to 2
      await db.execute('ALTER TABLE training ADD COLUMN dogId INTEGER;');
      await db.execute('''
        CREATE TABLE dog_profiles(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          breed TEXT,
          dateOfBirth TEXT,
          gender TEXT,
          currentWeight REAL,
          activityLevel TEXT,
          photoPath TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE weight_entries(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dogId INTEGER NOT NULL,
          weight REAL NOT NULL,
          timestamp TEXT NOT NULL,
          FOREIGN KEY (dogId) REFERENCES dog_profiles (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      // Logic for upgrading from version 2 to 3
      await db.execute('ALTER TABLE dog_profiles ADD COLUMN targetWeight REAL;');
      await db.execute('ALTER TABLE dog_profiles ADD COLUMN dailyDistanceGoal REAL;');
      await db.execute('ALTER TABLE dog_profiles ADD COLUMN dailyDurationGoal INTEGER;');
    }
    if (oldVersion < 4) {
      // Logic for upgrading from version 3 to 4
      await db.execute('ALTER TABLE dog_profiles ADD COLUMN lastVaccinationDate TEXT;');
      await db.execute('''
        CREATE TABLE health_entries(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dogId INTEGER NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          entryDate TEXT NOT NULL,
          category TEXT,
          FOREIGN KEY (dogId) REFERENCES dog_profiles (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      // Logic for upgrading from version 4 to 5
      await db.execute('ALTER TABLE dog_profiles ADD COLUMN rabiesVaccinationDate TEXT;');
      await db.execute('ALTER TABLE dog_profiles ADD COLUMN lastDewormingDate TEXT;');
    }
  }

  // --- Metody dla Training ---
  Future<int> insertTraining(Training training) async {
    Database db = await instance.database;
    return await db.insert('training', training.toMap());
  }

  Future<List<Training>> getTrainings() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('training', orderBy: 'startTime DESC');
    return List.generate(maps.length, (i) {
      return Training.fromMap(maps[i]);
    });
  }

  Future<void> deleteTraining(int id) async {
    Database db = await instance.database;
    await db.delete(
      'training',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Metody dla SpeedRecord ---
  Future<int> insertSpeedRecord(SpeedRecord record) async {
    Database db = await instance.database;
    return await db.insert('speed_records', record.toMap());
  }

  Future<List<SpeedRecord>> getSpeedRecords() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('speed_records', orderBy: 'speed DESC');
    return List.generate(maps.length, (i) {
      return SpeedRecord.fromMap(maps[i]);
    });
  }

  Future<void> deleteSpeedRecord(int id) async {
    Database db = await instance.database;
    await db.delete(
      'speed_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Metody dla DogProfile ---
  Future<int> insertDogProfile(DogProfile dog) async {
    Database db = await instance.database;
    return await db.insert('dog_profiles', dog.toMap());
  }

  Future<List<DogProfile>> getDogProfiles() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('dog_profiles');
    return List.generate(maps.length, (i) {
      return DogProfile.fromMap(maps[i]);
    });
  }

  Future<DogProfile?> getDogProfile(int id) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dog_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return DogProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateDogProfile(DogProfile dog) async {
    Database db = await instance.database;
    return await db.update(
      'dog_profiles',
      dog.toMap(),
      where: 'id = ?',
      whereArgs: [dog.id],
    );
  }

  Future<void> deleteDogProfile(int id) async {
    Database db = await instance.database;
    await db.delete(
      'dog_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Metody dla WeightEntry ---
  Future<int> insertWeightEntry(WeightEntry entry) async {
    Database db = await instance.database;
    return await db.insert('weight_entries', entry.toMap());
  }

  Future<List<WeightEntry>> getWeightEntriesForDog(int dogId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'weight_entries',
      where: 'dogId = ?',
      whereArgs: [dogId],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return WeightEntry.fromMap(maps[i]);
    });
  }

  Future<void> deleteWeightEntry(int id) async {
    Database db = await instance.database;
    await db.delete(
      'weight_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Metody dla HealthEntry ---
  Future<int> insertHealthEntry(HealthEntry entry) async {
    Database db = await instance.database;
    return await db.insert('health_entries', entry.toMap());
  }

  Future<List<HealthEntry>> getHealthEntriesForDog(int dogId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'health_entries',
      where: 'dogId = ?',
      whereArgs: [dogId],
      orderBy: 'entryDate DESC, id DESC',
    );
    return List.generate(maps.length, (i) {
      return HealthEntry.fromMap(maps[i]);
    });
  }

  Future<int> updateHealthEntry(HealthEntry entry) async {
    Database db = await instance.database;
    return await db.update(
      'health_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteHealthEntry(int id) async {
    Database db = await instance.database;
    await db.delete(
      'health_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

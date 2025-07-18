// lib/main.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Keep this if you use DateFormat elsewhere
import 'package:madspeed_app/screens/scan_screen.dart';
import 'package:madspeed_app/screens/dashboard_screen.dart';
import 'package:madspeed_app/screens/speed_master_screen.dart';
import 'package:madspeed_app/screens/training_screen.dart';
import 'package:madspeed_app/screens/history_screen.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:madspeed_app/screens/info_screen.dart';
import 'package:provider/provider.dart';
import 'package:madspeed_app/screens/dog_profile_list_screen.dart';
import 'package:madspeed_app/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BLEService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MadSpeed App',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          buttonColor: Colors.blueAccent,
          textTheme: ButtonTextTheme.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          margin: const EdgeInsets.all(10),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      initialRoute: '/dashboard', // Zmieniono początkową trasę na DashboardScreen
      routes: {
        '/': (context) => const ScanScreen(), // Scan screen nadal istnieje pod '/'
        '/dashboard': (context) => const DashboardScreen(), // Dashboard po połączeniu
        '/speed_master': (context) => const SpeedMasterScreen(), // Speed Master screen
        '/training': (context) => const TrainingScreen(), // Training screen
        '/history': (context) => const HistoryScreen(), // History screen for saved sessions
        '/info': (context) => const InfoScreen(),
        '/dog_profiles': (context) => const DogProfileListScreen(), // Trasa do listy profili psów
      },
    );
  }
}

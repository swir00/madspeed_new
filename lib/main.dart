import 'package:flutter/material.dart';
import 'package:madspeed_app/screens/scan_screen.dart';
import 'package:madspeed_app/screens/dashboard_screen.dart';
import 'package:madspeed_app/screens/speed_master_screen.dart';
import 'package:madspeed_app/screens/training_screen.dart';
import 'package:madspeed_app/screens/history_screen.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:madspeed_app/screens/info_screen.dart';
import 'package:provider/provider.dart';

void main() {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        // Provide the BLEService to the widget tree
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
        cardTheme: CardThemeData( // Zmieniono na CardThemeData
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
      initialRoute: '/', // Set the initial route
      routes: {
        '/': (context) => const ScanScreen(), // Scan screen is the starting point
        '/dashboard': (context) => const DashboardScreen(), // Dashboard after connection
        '/speed_master': (context) => const SpeedMasterScreen(), // Speed Master screen
        '/training': (context) => const TrainingScreen(), // Training screen
        '/history': (context) => const HistoryScreen(), // History screen for saved sessions
        '/info': (context) => const InfoScreen(),
      },
    );
  }
}

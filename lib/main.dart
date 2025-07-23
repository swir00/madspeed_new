import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Import this
import 'package:madspeed_app/services/theme_provider.dart';
import 'package:intl/intl.dart';
import 'package:madspeed_app/screens/scan_screen.dart';
import 'package:madspeed_app/screens/dashboard_screen.dart';
import 'package:madspeed_app/screens/speed_master_screen.dart';
import 'package:madspeed_app/screens/training_screen.dart';
import 'package:madspeed_app/screens/history_screen.dart';
import 'package:madspeed_app/services/ble_service.dart';
import 'package:madspeed_app/screens/info_screen.dart';
import 'package:provider/provider.dart';
import 'package:madspeed_app/screens/dog_profile_list_screen.dart';
import 'package:madspeed_app/screens/dog_walk_screen.dart';
import 'package:madspeed_app/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BLEService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'MadSpeed App',
          // Add these two properties for localization
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate, // If you use Cupertino widgets
          ],
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('pl', ''), // Polish
            // Add other locales your app supports
          ],
          // Użycie Material 3 i ColorScheme.fromSeed dla nowoczesnego wyglądu
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          // Definicja motywu ciemnego
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          // Ustawienie motywu na podstawie ThemeProvider
          themeMode: themeProvider.themeMode,
          initialRoute: '/dashboard',
          routes: {
            '/': (context) => const ScanScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/speed_master': (context) => const SpeedMasterScreen(),
            '/training': (context) => const TrainingScreen(),
            '/history': (context) => const HistoryScreen(),
            '/info': (context) => const InfoScreen(),
            '/dog_profiles': (context) => const DogProfileListScreen(),
            '/dog_walk': (context) => const DogWalkScreen(),
          },
        );
      },
    );
  }
}
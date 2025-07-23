// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:madspeed_app/services/theme_provider.dart';
import 'package:madspeed_app/widgets/status_indicators_widget.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final List<Map<String, dynamic>> dashboardItems = [
      {'title': 'Speed Master', 'icon': Icons.speed, 'route': '/speed_master'},
      {'title': 'Trening', 'icon': Icons.run_circle_outlined, 'route': '/training'},
      {'title': 'Spacer z Psem', 'icon': Icons.directions_walk, 'route': '/dog_walk'},
      {'title': 'Historia', 'icon': Icons.history_outlined, 'route': '/history'},
      {'title': 'Moje Psy', 'icon': Icons.pets_outlined, 'route': '/dog_profiles'},
      {'title': 'Informacje', 'icon': Icons.info_outline, 'route': '/info'},
      {'title': 'Połącz', 'icon': Icons.bluetooth_searching, 'route': '/'},
    ];
    const int columnCount = 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MadSpeed'),
        centerTitle: true,
        actions: const [
          StatusIndicatorsWidget(),
          SizedBox(width: 16),
        ],
      ),
      body: AnimationLimiter(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: GridView.builder(
            itemCount: dashboardItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              crossAxisSpacing: 20.0,
              mainAxisSpacing: 20.0,
            ),
            itemBuilder: (BuildContext context, int index) {
              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: const Duration(milliseconds: 375),
                columnCount: columnCount,
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildDashboardCard(
                        context,
                        dashboardItems[index]['title']!,
                        dashboardItems[index]['icon']!,
                        dashboardItems[index]['route']!,
                        themeProvider.themeMode),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, String title, IconData icon, String route, ThemeMode themeMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine if we are in dark mode, considering the system setting.
    // This is a more robust way to check than relying on Theme.of(context).brightness
    // which was causing issues.
    final bool isDarkMode;
    if (themeMode == ThemeMode.system) {
      // For system theme, check the platform's brightness.
      isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    } else {
      // Otherwise, it's a direct mapping.
      isDarkMode = themeMode == ThemeMode.dark;
    }
    // Explicitly set text color based on the determined mode.
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, route);
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 50,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

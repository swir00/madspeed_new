import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:madspeed_app/services/ble_service.dart'; // Upewnij się, że ścieżka jest poprawna

class StatusIndicatorsWidget extends StatelessWidget {
  const StatusIndicatorsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Użyj Consumer do nasłuchiwania zmian w BLEService
    return Consumer<BLEService>(
      builder: (context, bleService, child) {
        // --- Ikona Baterii ---
        IconData batteryIcon;
        Color batteryColor;
        String batteryText;

        if (bleService.connectedDevice == null) {
          batteryIcon = Icons.battery_unknown;
          batteryColor = Colors.grey;
          batteryText = "N/A";
        } else {
          final double batteryPercentage = bleService.batteryPercentage;
          batteryText = "${batteryPercentage.toInt()}%";

          if (batteryPercentage >= 80) {
            batteryIcon = Icons.battery_full;
            batteryColor = Colors.green;
          } else if (batteryPercentage >= 50) {
            batteryIcon = Icons.battery_6_bar;
            batteryColor = Colors.lightGreen;
          } else if (batteryPercentage >= 30) {
            batteryIcon = Icons.battery_3_bar;
            batteryColor = Colors.orange;
          } else if (batteryPercentage > 0) {
            batteryIcon = Icons.battery_alert;
            batteryColor = Colors.red;
          } else {
            batteryIcon = Icons.battery_0_bar;
            batteryColor = Colors.red;
          }
        }

        // --- Ikona Zasięgu GPS (jak GSM) ---
        IconData gpsSignalIcon;
        Color gpsSignalColor;
        String gpsQualityText;

        if (bleService.connectedDevice == null) {
          gpsSignalIcon = Icons.signal_cellular_off; // Brak połączenia BLE, brak sygnału
          gpsSignalColor = Colors.grey;
          gpsQualityText = "Brak";
        } else {
          final int gpsQualityLevel = bleService.currentGpsData.gpsQualityLevel ?? 0;
          gpsQualityText = "$gpsQualityLevel/5"; // Wyświetlanie jako poziom/max_poziom

          if (gpsQualityLevel == 5) {
            gpsSignalIcon = Icons.signal_cellular_4_bar; // Pełny zasięg (4 bary)
            gpsSignalColor = Colors.green;
          } else if (gpsQualityLevel == 4) {
            gpsSignalIcon = Icons.signal_cellular_alt; // 3 bary
            gpsSignalColor = Colors.lightGreen;
          } else if (gpsQualityLevel == 3) {
            gpsSignalIcon = Icons.signal_cellular_alt_2_bar; // 2 bary
            gpsSignalColor = Colors.orange;
          } else if (gpsQualityLevel == 2) {
            gpsSignalIcon = Icons.signal_cellular_alt_1_bar; // 1 bar
            gpsSignalColor = Colors.amber;
          } else if (gpsQualityLevel == 1) {
            gpsSignalIcon = Icons.signal_cellular_0_bar; // 0 barów, ale sygnał jest
            gpsSignalColor = Colors.red;
          } else {
            gpsSignalIcon = Icons.signal_cellular_off; // Brak sygnału GPS
            gpsSignalColor = Colors.grey;
            gpsQualityText = "Brak";
          }
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: "Poziom baterii: $batteryText",
              child: Icon(batteryIcon, color: batteryColor, size: 28),
            ),
            const SizedBox(width: 4),
            Text(
              batteryText,
              style: TextStyle(color: batteryColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16), // Odstęp między ikonami
            Tooltip(
              message: "Jakość sygnału GPS: $gpsQualityText",
              child: Icon(gpsSignalIcon, color: gpsSignalColor, size: 28),
            ),
            const SizedBox(width: 4),
            Text(
              gpsQualityText,
              style: TextStyle(color: gpsSignalColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }
}

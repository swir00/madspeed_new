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
          // POPRAWKA TUTAJ: Rzutowanie na int za pomocą .toInt()
          final int batteryPercentage = (bleService.currentGpsData.battery ?? 0).toInt();
          batteryText = "$batteryPercentage%";

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
          gpsQualityText = "$gpsQualityLevel/5";

          // Zmodyfikowana logika, aby używać bardziej powszechnych ikon
          if (gpsQualityLevel >= 4) { // Poziomy 4 i 5: dobry/pełny sygnał
            gpsSignalIcon = Icons.signal_cellular_4_bar;
            gpsSignalColor = Colors.green;
          } else if (gpsQualityLevel >= 1) { // Poziomy 1, 2, 3: jakiś sygnał (słabszy)
            gpsSignalIcon = Icons.signal_cellular_alt; // Ogólna ikona sygnału
            gpsSignalColor = Colors.orange; // Wskazuje na słabszy, ale obecny sygnał
          } else { // Poziom 0: brak sygnału
            gpsSignalIcon = Icons.signal_cellular_off;
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

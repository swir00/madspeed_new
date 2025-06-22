import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:madspeed_app/models/log_data_point.dart';

class CustomChart extends StatelessWidget {
  final List<LogDataPoint> logData;

  const CustomChart({super.key, required this.logData});

  // Funkcja przygotowująca dane dla wykresu (prędkość vs dystans)
  List<FlSpot> _getSpeedVsDistanceSpots(List<LogDataPoint> rawData) {
    if (rawData.isEmpty) {
      return [];
    }

    List<FlSpot> spots = [];
    double lastValidDistance = 0.0; // Śledzi ostatni prawidłowy (rosnący) dystans

    // Dodaj pierwszy punkt. Zaczynamy od 0 dystansu na osi X dla spójności wykresu.
    if (rawData.isNotEmpty) {
      // Upewniamy się, że początkowa prędkość też nie jest ujemna
      spots.add(FlSpot(0.0, rawData.first.speed < 0 ? 0.0 : rawData.first.speed));
      lastValidDistance = 0.0;
    }

    for (int i = 0; i < rawData.length; i++) {
      final dataPoint = rawData[i];
      double currentDistanceMeters = dataPoint.distance;
      double currentSpeed = dataPoint.speed;

      // KLUCZOWA POPRAWKA 1: Zapewnienie monotonicznego wzrostu dystansu
      if (currentDistanceMeters < lastValidDistance) {
        currentDistanceMeters = lastValidDistance;
      } else {
        lastValidDistance = currentDistanceMeters;
      }
      
      // KLUCZOWA POPRAWKA 2: Zapewnienie, że prędkość nigdy nie jest ujemna
      if (currentSpeed < 0) { // Jeśli prędkość jest ujemna (z błędu GPS), ustaw na 0
        currentSpeed = 0.0;
      }
      // Opcjonalna filtracja: Wygładzanie bardzo niskich prędkości do zera
      else if (currentSpeed < 0.5) { // Jeśli prędkość jest bardzo niska (szum), ustaw na 0
         currentSpeed = 0.0;
      }

      spots.add(FlSpot(currentDistanceMeters, currentSpeed));
    }

    // Usunięcie duplikatów punktów na tej samej pozycji X, biorąc ostatnią wartość Y
    spots.sort((a, b) => a.x.compareTo(b.x));
    List<FlSpot> uniqueSpots = [];
    if (spots.isNotEmpty) {
      uniqueSpots.add(spots.first);
      for (int i = 1; i < spots.length; i++) {
        if (spots[i].x != uniqueSpots.last.x) {
          uniqueSpots.add(spots[i]);
        } else {
          uniqueSpots.last = spots[i];
        }
      }
    }

    return uniqueSpots;
  }

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = _getSpeedVsDistanceSpots(logData);

    double minX = 0;
    double maxX = spots.isNotEmpty ? spots.map((spot) => spot.x).reduce((a, b) => a > b ? a : b) : 1.0;
    double minY = 0;
    double maxY = spots.isNotEmpty ? spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) : 1.0;
    
    // Dodanie marginesów do osi i zapewnienie minimalnego zakresu Y
    maxX = maxX * 1.05;
    maxY = maxY * 1.15;
    
    if (maxY < 10.0) maxY = 10.0; // Zapewnij minimalną wartość dla maxY

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(20.0),
      minScale: 0.1,
      maxScale: 10.0,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Dystans [m]', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxX / 5 < 1) ? 1 : (maxX / 5).roundToDouble(), 
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text('${value.toInt()}', style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text('Prędkość [km/h]', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (maxY / 5 < 1) ? 1 : (maxY / 5).roundToDouble(),
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text('${value.toInt()}', style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: true),
        ),
      ),
    );
  }
}

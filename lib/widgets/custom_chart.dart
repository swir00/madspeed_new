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
    double lastValidDistance = 0.0;

    for (var dataPoint in rawData) {
      double currentDistanceMeters = dataPoint.distance;
      
      // Zabezpieczenie przed wstecznym dystansem
      if (currentDistanceMeters >= lastValidDistance) {
        lastValidDistance = currentDistanceMeters;
      } else {
        currentDistanceMeters = lastValidDistance;
      }

      // Dodaj punkt: X=dystans (w metrach), Y=prędkość (w km/h)
      spots.add(FlSpot(currentDistanceMeters, dataPoint.speed));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = _getSpeedVsDistanceSpots(logData);

    double maxX = spots.isNotEmpty ? spots.map((spot) => spot.x).reduce((a, b) => a > b ? a : b) : 1.0;
    double maxY = spots.isNotEmpty ? spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) : 1.0;
    
    // Dodaj margines do osi, aby wykres nie dotykał krawędzi
    maxX = maxX * 1.1; // 10% marginesu
    maxY = maxY * 1.1; // 10% marginesu

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(80.0),
      minScale: 0.1,
      maxScale: 4.0,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  // Oś X: Dystans w metrach
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text('${value.toInt()}m', style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  // Oś Y: Prędkość w km/h
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text('${value.toInt()}km/h', style: const TextStyle(fontSize: 12)),
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
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
        ),
      ),
    );
  }
}
